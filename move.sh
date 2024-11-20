#!/bin/bash

# Define the main folder (change this to your actual folder path)
MAIN_FOLDER=$1
HEAD=$2
# Iterate over each subfolder named "expe_*" inside the main folder
for SUBFOLDER in "$MAIN_FOLDER"/$HEAD*; do
    if [ -d "$SUBFOLDER" ]; then
        # Copy the contents of the subfolder to the main folder
        cp -r "$SUBFOLDER"/* "$MAIN_FOLDER"
    fi
done

echo "All files have been copied to $MAIN_FOLDER."
