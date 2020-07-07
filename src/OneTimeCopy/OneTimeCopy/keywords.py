import csv

KEYWORD_SINGLES = set()
KEYWORD_PAIRS = set()
KEYWORD_TRIPLES = set()

with open("data/keywords.csv", "r", newline="") as f:
    reader = csv.reader(f, delimiter=",")
    for row in reader:
        KEYWORD_SINGLES.add(row[0])
        KEYWORD_PAIRS.add(row[1])
        KEYWORD_TRIPLES.add(row[2])

    KEYWORD_SINGLES.remove("")
