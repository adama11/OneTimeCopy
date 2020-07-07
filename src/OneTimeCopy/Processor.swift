//
//  Processor2.swift
//  OneTimeCopy
//
//  Created by Adam Dama on 6/29/20.
//  Copyright © 2020 Adam Dama. All rights reserved.
//
import Cocoa
import CommonCrypto
import Foundation
import UserNotifications

import SQLite
import SKQueue

class Processor: ObservableObject, SKQueueDelegate {
    let appDelegate = NSApplication.shared.delegate as! AppDelegate
    let dateFormatter: DateFormatter = DateFormatter()
    
    var CODE_RE_EXPRESSION: NSRegularExpression
    var DATE_FOLDER_RE: NSRegularExpression
    var recentData: (score: Int, code: String, date: Date)? = nil
    var skQueue: SKQueue!
    var acceptFileNotifications: Bool = false
    var canStartWatcher: Bool = true
    
    @Published var dataAvailable: Bool = false
    
    init() {
        CODE_RE_EXPRESSION = try! NSRegularExpression(pattern: "((G-)*[0-9]+-*[0-9]+)")
        DATE_FOLDER_RE = try! NSRegularExpression(pattern: "[1-9]{4}-[1-9]{2}-[1-9]{2}")
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        skQueue = SKQueue(delegate: self)!
        
        if let shouldScan = appDelegate.getPref(forKey: "auto_scan") {
            if shouldScan {
                startWatch()
            }
        }
    }

    func receivedNotification(_ notification: SKQueueNotification, path: String, queue: SKQueue) {
        if acceptFileNotifications {
            acceptFileNotifications = false
            if let data = self.runSearch() {
                self.recentData = data
                self.dataAvailable = true
                if let shouldNotify = appDelegate.getPref(forKey: "push_notifications") {
                    if shouldNotify {
                        appDelegate.notificationManager.showCodeNotification(data)
                    }
                }
                
            }
            DispatchQueue.global(qos: .default).asyncAfter(deadline: DispatchTime.now() + 1, execute: {
                self.acceptFileNotifications = true
            })
        }
    }
    
    func startWatch() {
        if canStartWatcher {
            acceptFileNotifications = true
            if var messagesFolder = FileManager.default.urls(for: .allLibrariesDirectory, in: .userDomainMask).first {
                messagesFolder = messagesFolder.appendingPathComponent("Messages")
                //queue.addPath(messagesFolder.appendingPathComponent("chat.db").pathComponents.joined(separator: "/"), notifyingAbout: .Write)
                //queue.addPath(messagesFolder.appendingPathComponent("chat.db-shm").pathComponents.joined(separator: "/"), notifyingAbout: .Write)
                skQueue.addPath(messagesFolder.appendingPathComponent("chat.db-wal").pathComponents.joined(separator: "/"), notifyingAbout: .Write)
            }
            canStartWatcher = false
        }
    }
    
    func stopWatch() {
        skQueue.removeAllPaths()
        canStartWatcher = true
    }
    
    public func runSearch() -> (score: Int, code: String, date: Date)? {
//        appDelegate.diskAccessController.getAccess()
        
        var transcriptData : [(score: Int, code: String, date: Date)] = []
        if let db = loadDatabase() {
            var lastRunTime = getLastRunTime()
            while transcriptData.count == 0 {
                transcriptData = loadMessages(from: db, after: lastRunTime)
                transcriptData = transcriptData.sorted {
                    if $0.date != $1.date { // First, compare by date, taking latest
                        return $0.date > $1.date
                    } else { // If all other fields are tied, break ties by score
                        return $0.score > $1.score
                    }
                }
                print(transcriptData)

                lastRunTime = lastRunTime?.addingTimeInterval(TimeInterval(-24*60*60)) // Move back one day
            }
        }
        if transcriptData.count > 0 {
            let result = transcriptData[0]
            if !comparePrevious(result) {
                if let shouldCopy = appDelegate.getPref(forKey: "auto_copy") {
                    if shouldCopy {
                        copyToClipboard(result.code)
                    }
                }
                return result
            }
        }
        return nil
    }
    
    public func copyToClipboard(_ string: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.declareTypes([.string], owner: nil)
        pasteboard.setString(string, forType: .string)
    }
    
    private func loadMessages(from db: Connection, after afterDate: Date? = nil) -> [(score: Int, code: String, date: Date)] {
        var messages : [(score: Int, code: String, date: Date)] = []
        do {
            var query_messages = """
                SELECT \
                    text, \
                    datetime(message.date/1000000000 + strftime('%s', '2001-01-01'), 'unixepoch', 'localtime') as date_converted \
                FROM message \

            """
            
            if let afterDate = afterDate {
                let dateString = dateFormatter.string(from: afterDate)
                query_messages += "WHERE date_converted >= '\(dateString)'"
            }
            
            
            for row in try db.prepare(query_messages) {
                if let text = row[0] as? String, let date_str = row[1] as? String {
                    let score = getKeywordScore(from: text)
                    if score == 0 {
                        continue
                    }
                    let code = extractCode(from: text)
                    if code.count == 0 {
                        continue
                    }
                    let date = dateFormatter.date(from: date_str)!
                    messages.append((score: score, code: code, date: date))
                }
            }
        } catch {
            print("ERROR: Unable to load messages")
        }
        return messages
    }
    
    private func loadDatabase() -> Connection? {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let path = homeDir.appendingPathComponent("Library/Messages/chat.db").absoluteString
        do {
            let db = try Connection(path)
            return db
        } catch {
            print("ERROR: Unable to open DB from \(path)")
        }
        return nil
    }

    private func extractNGrams(from text: String, withN num: Int) -> Set<String> {
        /*
        Returns N-grams from 'text' with N=num
        */
        
        let tokens = text.lowercased().split(separator: " ")
        if tokens.count - num < 0 {
            return Set()
        }
        var nGrams: [String] = []
        for i in 0...(tokens.count - num) {
            let gram = tokens[i..<i + num].joined(separator: " ")
            nGrams.append(gram)
        }
        return Set(nGrams)
    }

    private func getKeywordScore(from text: String) -> Int {
        /*
        Returns a keyword score of the text. The text is awared 1 point for each Keywords.ones match,
        2 points for each Keywords.twos match and 3 points for each Keywords.threes match. The
        final score is the sum of these subscores.
        */
        
        if text.count == 0 {
            return 0
        }
        
        let textLower = text.lowercased()
        let oneGrams = extractNGrams(from: textLower, withN: 1)
        let twoGrams = extractNGrams(from: textLower, withN: 2)
        let threeGrams = extractNGrams(from: textLower, withN: 3)
        
        let scoreOnes = Keywords.ones.intersection(oneGrams).count * 1
        let scoreTwos = Keywords.twos.intersection(twoGrams).count * 2
        let scoreThrees = Keywords.ones.intersection(threeGrams).count * 1
        
        return scoreOnes + scoreTwos + scoreThrees
    }

    private func extractCode(from text: String) -> String {
        /*
        Extracts a code from 'text' that matches the regular expression defined by 'self.CODE_RE_EXPRESSION'.
        */
        
        let code = CODE_RE_EXPRESSION.matches(in: text, options: [], range: NSRange(location: 0, length: text.count))
        let results = code.map {
            String(text[Range($0.range, in: text)!])
        }
        if results.count == 0 {
            return ""
        }
        return results[0]
    }
    
    private func SHA256(_ string: String) -> String {
        /*
        Returns the SHA256 hash of 'string'.
        */
        
        let length = Int(CC_SHA256_DIGEST_LENGTH)
        let messageData = string.data(using:.utf8)!
        var digestData = Data(count: length)

        _ = digestData.withUnsafeMutableBytes { digestBytes -> UInt8 in
            messageData.withUnsafeBytes { messageBytes -> UInt8 in
                if let messageBytesBaseAddress = messageBytes.baseAddress, let digestBytesBlindMemory = digestBytes.bindMemory(to: UInt8.self).baseAddress {
                    let messageLength = CC_LONG(messageData.count)
                    CC_SHA256(messageBytesBaseAddress, messageLength, digestBytesBlindMemory)
                }
                return 0
            }
        }
        let asString = digestData.map { String(format: "%02hhx", $0) }.joined()
        return asString
    }
    
    private func comparePrevious(_ current: (score: Int, code: String, date: Date)) -> Bool {
        /*
        Retrieves the previous code hash '~/[username]/Application Support/OneTimeCopy/.prev_code_hash' and compares to hash of `code`.
         
        Returns:
            true if they are the same
            false if they are different or if there is no previous code hash
        */
        
        let currentHash = SHA256(current.code + dateFormatter.string(from: current.date))
        if let supportDir = getApplicationSupportDir() {
            let fileDir = supportDir.appendingPathComponent(".prev_code_hash")
            do {
                let recentHash = try String(contentsOf: fileDir, encoding: String.Encoding.utf8)
                writeStringToFile(contents: currentHash, named: ".prev_code_hash")
                return recentHash == currentHash
            } catch {
                print("File .prev_code_hash does not exist.")
            }
        }
        
        writeStringToFile(contents: currentHash, named: ".prev_code_hash")
        return false
    }
    
    
    private func getLastRunTime() -> Date? {
        /*
        Retrieves the last run time that has been cached in '~/[username]/Application Support/OneTimeCopy/.last_run_time'.
        */
        
        let now =  dateFormatter.string(from: Date())
        if let supportDir = getApplicationSupportDir() {
            let fileDir = supportDir.appendingPathComponent(".last_run_time")
            do {
                let string = try String(contentsOf: fileDir, encoding: String.Encoding.utf8)
                let date = dateFormatter.date(from: string)
                writeStringToFile(contents: now, named: ".last_run_time")
                return date
            } catch {
                print("File .last_run_datetime does not exist.")
            }
        }
        
        writeStringToFile(contents: now, named: ".last_run_time")
        return nil
    }
    
    private func getDatabaseHash() -> String {
        /*
        Generates an SHA256 hash of the database file contents in '/Users/[USERNAME]/Library/Messages'. Caches this value in
        '~/[username]/Application Support/OneTimeCopy/.db_hash'.
        */
        var toHash: String = ""
        if var messagesFolder = FileManager.default.urls(for: .allLibrariesDirectory, in: .userDomainMask).first {
            messagesFolder = messagesFolder.appendingPathComponent("Messages")
            if let fileString = try? Data(contentsOf: messagesFolder.appendingPathComponent("chat.db")) {
                toHash += fileString.base64EncodedString()
            }
            if let fileString = try? Data(contentsOf: messagesFolder.appendingPathComponent("chat.db-shm")) {
                toHash += fileString.base64EncodedString()
            }
            if let fileString = try? Data(contentsOf: messagesFolder.appendingPathComponent("chat.db-wal")) {
                toHash += fileString.base64EncodedString()
            }
        }
        
        let result = SHA256(toHash)
        writeStringToFile(contents: result, named: ".db_hash")
        return result
    }
    
    private func writeStringToFile(contents: String, named fileName: String) {
        /*
        Writes 'contents' to file in '~/[username]/Application Support/OneTimeCopy/[fileName]'.
        */
        
        if let selfAppDir = getApplicationSupportDir() {
            do {
                try FileManager.default.createDirectory(at: selfAppDir, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("Error creating Application Support/OneTimeCopy directory")
            }
            
            let fileDir = selfAppDir.appendingPathComponent(fileName)
            do {
                try contents.write(to: fileDir, atomically: true, encoding: .utf8)
            } catch {
                print("Error writing \(contents) to file at \(fileDir)")
            }
        }
    }
    
    private func getApplicationSupportDir() -> URL? {
        /*
        Returns Application Support dir for this app as URL: '~/[username]/Application Support/OneTimeCopy/'.
        */
        
        if let applicationSupportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let selfDir = applicationSupportDir.appendingPathComponent("OneTimeCopy")
            return selfDir
        }
        return nil
    }
    
    private func retrieveFileContents(of fileName : String) -> String? {
        /*
        Reads a file's contents from '~/[username]/Application Support/OneTimeCopy/[fileName]'.
        */
        
        do {
            if let supportDir = getApplicationSupportDir() {
                let fileDir = supportDir.appendingPathComponent(fileName)
                if FileManager.default.fileExists(atPath: fileDir.path) {
                    let contents = try String(contentsOf: fileDir, encoding: .utf8)
                    return contents
                }
            }
        } catch {
            print("Couldn't retrieve file \(fileName)")
        }
        return nil
    }
    
    private func checkForNewMessages() -> Bool {
        /*
        Checks for new messages by comparing the cached directory SHA256 hash to the current directory SHA256 hash.
        */
        
        if let storedHash = retrieveFileContents(of: ".db_hash") {
            let currentHash = getDatabaseHash()
            return currentHash != storedHash
        }
        let _ = getDatabaseHash()
        return true
    }
}



struct Keywords {
    /*
    Keywords to look for in a message transcript.
    */
    
    static let ones : Set = [
        "onetime",
        "one-time",
        "otp",
        "otc",
        "code",
        "passcode",
        "pin",
        "password",
        "identification",
        "verification",
        "security",
        "auth",
        "sign-in",
        "sign in",
        "login",
        "log-in",
        "logon",
        "log-on",
        "temporary",
        "account",
        "passcode:",
        "pin:",
        "password:",
        "code:",
        "is:",
    ]
    static let twos : Set = [
        "onetime code",
        "onetime passcode",
        "onetime pin",
        "onetime password",
        "one-time code",
        "one-time passcode",
        "one-time pin",
        "one-time password",
        "identification code",
        "identification passcode",
        "identification pin",
        "identification password",
        "verification code",
        "verification passcode",
        "verification pin",
        "verification password",
        "security code",
        "security passcode",
        "security pin",
        "security password",
        "auth code",
        "auth passcode",
        "auth pin",
        "auth password",
        "sign-in code",
        "sign-in passcode",
        "sign-in pin",
        "sign-in password",
        "login code",
        "login passcode",
        "login pin",
        "login password",
        "log-in code",
        "log-in passcode",
        "log-in pin",
        "log-in password",
        "logon code",
        "logon passcode",
        "logon pin",
        "logon password",
        "log-on code",
        "log-on passcode",
        "log-on pin",
        "log-on password",
        "temporary code",
        "temporary passcode",
        "temporary pin",
        "temporary password",
        "code is",
        "passcode is",
        "pin is",
        "password is",
        "onetime code:",
        "onetime passcode:",
        "onetime pin:",
        "onetime password:",
        "one-time code:",
        "one-time passcode:",
        "one-time pin:",
        "one-time password:",
        "verification code:",
        "verification passcode:",
        "verification pin:",
        "verification password:",
        "security code:",
        "security passcode:",
        "security pin:",
        "security password:",
        "auth code:",
        "auth passcode:",
        "auth pin:",
        "auth password:",
        "sign-in code:",
        "sign-in passcode:",
        "sign-in pin:",
        "sign-in password:",
        "login code:",
        "login passcode:",
        "login pin:",
        "login password:",
        "log-in code:",
        "log-in passcode:",
        "log-in pin:",
        "log-in password:",
        "logon code:",
        "logon passcode:",
        "logon pin:",
        "logon password:",
        "log-on code:",
        "log-on passcode:",
        "log-on pin:",
        "log-on password:",
        "temporary code:",
        "temporary passcode:",
        "temporary pin:",
        "temporary password:",
        "code is:",
        "passcode is:",
        "pin is:",
        "password is:",
        "one time",
        "log in",
    ]
    static let threes : Set = [
        "one time code",
        "one time passcode",
        "one time pin",
        "one time password",
        "sign in code",
        "sign in passcode",
        "sign in pin",
        "sign in password",
        "log in code",
        "log in passcode",
        "log in pin",
        "log in password",
        "one time code:",
        "one time passcode:",
        "one time pin:",
        "one time password:",
        "sign in code:",
        "sign in passcode:",
        "sign in pin:",
        "sign in password:",
        "log in code:",
        "log in passcode:",
        "log in pin:",
        "log in password:",
    ]
}



