#!/bin/bash

# Define the source folder (where to search) and destination folder (where to extract)
SOURCE_FOLDER="${1:-online/g5k}"
DESTINATION_FOLDER="${2:-online/g5k}"

# Create the destination folder if it doesn't exist
mkdir -p "$DESTINATION_FOLDER"

# Find all .tar.gz files in the source folder and its subfolders
find "$SOURCE_FOLDER" -type f -name "*.tar.gz" | while read -r tar_file; do
    echo "Extracting $tar_file into $DESTINATION_FOLDER"
    tar -xzf "$tar_file" -C "$DESTINATION_FOLDER"
done

echo "All tar.gz files have been extracted to $DESTINATION_FOLDER."
