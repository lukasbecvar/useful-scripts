#!/bin/python3
import os
import time
import xml.etree.ElementTree as ET
from urllib.parse import unquote

# bash color codes
GREEN = "\033[92m"
YELLOW = "\033[93m"
RESET = "\033[0m"

# path to the Rhythmbox database XML
db_path = '/home/lukas/.local/share/rhythmbox/rhythmdb.xml'

# load the XML file
tree = ET.parse(db_path)
root = tree.getroot()

# extract file path from the <location> tag
def get_file_path(location):
    # remove "file://" and decode URL encoding
    return unquote(location.text.replace('file://', ''))

# get the creation time of the file
def get_creation_time(file_path):
    try:
        return os.path.getctime(file_path)
    except FileNotFoundError:
        return 0  # return 0 if the file doesn't exist

# get all song entries from the XML
songs = []
for entry in root.findall('entry'):
    if entry.attrib.get('type') == 'song':
        location = entry.find('location')
        file_path = get_file_path(location)
        creation_time = get_creation_time(file_path)
        songs.append((creation_time, entry))

# sort songs by file creation time (newest first)
songs.sort(key=lambda x: x[0], reverse=True)

# current time as a starting point for updating "first-seen" values
current_time = int(time.time())

# clear all entries from the XML and reinsert them in sorted order
for i, (_, song_entry) in enumerate(songs):
    first_seen = song_entry.find('first-seen')

    # update "first-seen" to simulate adding songs by creation date
    if first_seen is not None:
        first_seen.text = str(current_time - i)  # decrease time by 1 second for each song

    # append the entry back into the XML tree
    root.append(song_entry)

# save the updated XML file
tree.write(db_path, encoding='utf-8', xml_declaration=True)

# print colored output using bash color codes
print(f"{GREEN}The database has been sorted and 'first-seen' times have been updated.{RESET}")
print(f"{YELLOW}You can now sort by 'Added Time' in Rhythmbox.{RESET}")
