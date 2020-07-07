import datetime
import hashlib
import itertools
import os
import platform
import plistlib
import re
import shutil
import sqlite3
import threading
import time

import nltk
import pandas as pd
import tzlocal

from keywords import KEYWORD_SINGLES, KEYWORD_PAIRS, KEYWORD_TRIPLES

# WORD_CORPUS_EN = set(nltk.corpus.words.words())

CODE_RE_EXPRESSION = re.compile(r"([0-9-]+)")
DATE_FOLDER_RE = re.compile(r"\d{4}-\d{2}-\d{2}")

# def is_post_high_sierra():
#     version = platform.mac_ver()[0].split(".")
#     if int(version[0]) < 10:
#         return False
#     elif int(version[1]) < 13:
#         return False
#     else:
#         return True


# def convert_date(date, use_new_date):
#     start = datetime.datetime(2001, 1, 1)
#     if use_new_date:
#         return start + datetime.timedelta(seconds=date / 1000000000)
#     else:
#         return start + datetime.timedelta(seconds=date)


def convert_date(date):
    start = datetime.datetime(2001, 1, 1)
    local_tz = tzlocal.get_localzone()
    local_time = datetime.datetime.now(local_tz)
    tz_offset = local_time.utcoffset().total_seconds()

    calculated_time = start + datetime.timedelta(seconds=date + tz_offset)
    return calculated_time


def extract_ngrams(data, num):
    n_grams = nltk.ngrams(nltk.word_tokenize(data), num)
    return set([" ".join(grams) for grams in n_grams])


def get_messages(db, limit=None, after_datetime=None):
    if limit is None:
        query = "SELECT * FROM message"
    else:
        query = f"SELECT * FROM message LIMIT {limit}"

    messages = pd.read_sql_query(query, db)
    messages = messages.rename(columns={"ROWID": "message_id"})

    messages = messages.loc[
        (messages["is_from_me"] == 0) & (messages["is_empty"] == 0), :
    ]
    messages = messages[["message_id", "handle_id", "text", "date"]]
    use_new_date = is_post_high_sierra()
    messages["date"] = messages["date"].apply(lambda x: convert_date(x, use_new_date))
    latest_date = messages["date"].sort_values(ascending=False).values[0]
    if after_datetime:
        messages = messages.loc[messages["date"] > after_datetime, :]

    return messages, latest_date


def keyword_score(text):
    if not text:
        return 0
    text = text.lower()
    one_grams = set(text.split(" "))
    two_grams = extract_ngrams(text, 2)
    three_grams = extract_ngrams(text, 3)

    score_ones = len(KEYWORD_SINGLES.intersection(one_grams)) * 1
    score_twos = len(KEYWORD_PAIRS.intersection(two_grams)) * 2
    score_threes = len(KEYWORD_TRIPLES.intersection(three_grams)) * 3
    return score_ones + score_twos + score_threes


def extract_code(text):
    code = CODE_RE_EXPRESSION.search(text)
    if code:
        return str(code.group(1))
    return None


def get_last_run_datetime():
    if os.path.exists("data/last_run_datetime"):
        with open("data/last_run_datetime", "r") as f:
            last_run_datetime = f.readline()
            try:
                as_date = datetime.datetime.strptime(
                    last_run_datetime, "%Y-%m-%d %H:%M:%S"
                )
            except:
                return None
            return as_date
    return None


def get_subfolder_as_date(subfolder_name):

    if not DATE_FOLDER_RE.match(subfolder_name):
        return False
    subfolder_date = datetime.datetime.strptime(subfolder_name, "%Y-%m-%d")
    return subfolder_date


def get_all_ichat_paths(homedir, after_date=None):
    folder_path = os.path.join(homedir, "Library/Messages/Archive/")

    valid_folders = {}
    for subfolder_name in os.listdir(folder_path):
        subfolder_date = get_subfolder_as_date(subfolder_name)
        if not subfolder_date:
            continue
        elif after_date is not None and subfolder_date < after_date:
            continue
        subfolder_path = os.path.join(folder_path, subfolder_name)
        if os.path.isdir(subfolder_path):
            valid_chats = []
            for chat_name in os.listdir(subfolder_path):
                if os.path.splitext(chat_name)[-1].lower() == ".ichat":
                    valid_chats.append(os.path.join(subfolder_path, chat_name))

            valid_folders[subfolder_date] = valid_chats
    return valid_folders


def process_ichat_transcript(chat_paths):
    messages = []
    times = []
    scores = []
    codes = []

    for p in chat_paths:
        with open(p, "rb") as f:
            chat_plist = plistlib.load(f, fmt=plistlib.FMT_BINARY)

            all_objects = chat_plist["$objects"]
            last_was_chat = False
            n_obj = len(all_objects)
            for idx, obj in enumerate(all_objects):
                if obj == "StartTime":
                    break
                elif type(obj) == dict and idx != n_obj - 2:
                    if obj.get("$class", None) == plistlib.UID(15):
                        time = convert_date(obj["NS.time"])
                        times.append(time)
                        last_was_chat = False
                    if obj.get("$class", None) == plistlib.UID(18):

                        message = obj["NS.string"]
                        if last_was_chat:
                            times.append("N/A")
                            # print("\n##########################")
                            # print("NO DATE", message)
                        messages.append(message)
                        scores.append(keyword_score(message))
                        codes.append(extract_code(message))
                        last_was_chat = True

    extracted_data = pd.DataFrame(
        {"message": messages, "time": times, "score": scores, "code": codes}
    )
    return extracted_data


def get_directory_hash(homedir, after_date):
    folder_path = os.path.join(homedir, "Library/Messages/Archive/")
    current_hash = hashlib.md5()

    for folder in os.listdir(folder_path):
        subfolder_date = get_subfolder_as_date(folder)
        if not subfolder_date:
            continue
        elif after_date is not None and subfolder_date < after_date:
            continue
        for root, _, files in os.walk(os.path.join(folder_path, folder)):
            for name in files:
                filepath = os.path.join(root, name)
                filepath += str(os.path.getsize(filepath))
                current_hash.update(filepath.encode())
    return current_hash.hexdigest()


def check_for_messages(homedir, last_run_datetime=None):
    current_dir_hash = get_directory_hash(homedir, last_run_datetime)
    new_messages = True
    # Open stored hash if it exists
    if os.path.exists("data/dir_hash"):
        with open("data/dir_hash", "r") as f:
            dir_hash = f.readline()
            new_messages = dir_hash != current_dir_hash

    # Write current hash to file
    with open("data/dir_hash", "w") as f:
        f.write(current_dir_hash)
    return new_messages


def start_program():
    print("Running")
    homedir = os.environ["HOME"]

    last_run_datetime = get_last_run_datetime()
    new_messages = check_for_messages(homedir, last_run_datetime)

    if new_messages:
        print("\tNew messages")
        chat_folders = get_all_ichat_paths(homedir, last_run_datetime)
        latest_date = max(chat_folders.keys())
        latest_folder = chat_folders[latest_date]
        all_extracted_data = pd.DataFrame()
        for f in chat_folders.values():
            extracted_data = process_ichat_transcript(f)
            extracted_data = extracted_data.loc[extracted_data["score"] >= 1, :]
            all_extracted_data = pd.concat([all_extracted_data, extracted_data])

        all_extracted_data = all_extracted_data.sort_values(
            by=["score"], ascending=False
        )
        with open("data/last_run_datetime", "w") as f:
            f.write(str(latest_date))

        print(all_extracted_data)


if __name__ == "__main__":

    # # print(CODE_RE_EXPRESSION.search("ads f 098123 df add f23412"))
    # # print(CODE_RE_EXPRESSION.search("098-123"))
    # # print(CODE_RE_EXPRESSION.search("G-098123"))
    # original_db_path = "/Users/adamdama/Library/Messages/chat.db"
    # db_path = "data/chat_cache.db"
    # shutil.copyfile(original_db_path, db_path)
    # db = sqlite3.connect(db_path)

    # last_run_datetime = get_last_run_datetime()
    # messages, latest_date = get_messages(db, after_datetime=last_run_datetime)

    # handles = pd.read_sql_query("select * from handle", db)
    # # and join to the messages, on handle_id
    # handles.rename(columns={"id": "phone_number", "ROWID": "handle_id"}, inplace=True)

    # messages = pd.merge(
    #     messages[["message_id", "handle_id", "text", "date"]],
    #     handles[["handle_id", "phone_number"]],
    #     on="handle_id",
    # )
    # # print(merge)
    # # merge["short code"] = merge["phone_number"].apply(lambda x: True)
    # # shorts = merge.loc[merge["short code"] == True, :]
    # messages["score"] = messages["text"].apply(keyword_score)
    # messages = messages.loc[messages["score"] >= 1, :]
    # messages["code"] = messages["text"].apply(extract_code)
    # messages = messages.sort_values(by=["score"], ascending=False)

    # print(messages)
    # messages.to_csv("messages.csv")

    # with open("data/last_run_datetime", "w") as f:
    #     f.write(str(latest_date))

    start_time = time.time()
    while True:
        time.sleep(5.0 - ((time.time() - start_time) % 5.0))
        start_program()
    # t = threading.Timer(5.0, start_program)
    # t.start()

    # with open("data/last_run_datetime", "w") as f:
    #     f.write(str(latest_date))
