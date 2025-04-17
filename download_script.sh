#!/bin/bash

# Check if a CSV file was provided as an argument
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <csv_file>"
    exit 1
fi

csv_file="$1"

# Verify that the file exists
if [ ! -f "$csv_file" ]; then
    echo "File $csv_file not found!"
    exit 1
fi

# Read the header line to identify the URL column
header=$(head -n 1 "$csv_file")
IFS=',' read -ra columns <<< "$header"

# Initialize URL column index
url_col=-1

# Determine which column contains the URL (looking for "url" or "link")
for i in "${!columns[@]}"; do
    col_name=$(echo "${columns[$i]}" | tr -d '"')
    if [[ "$col_name" == "url" || "$col_name" == "link" ]]; then
        url_col=$i
        break
    fi
done

if [ $url_col -eq -1 ]; then
    echo "No column named 'url' or 'link' was found in the CSV header."
    exit 1
fi

echo "Found URL column at index $url_col."

# Process each row after the header
tail -n +2 "$csv_file" | while IFS=',' read -r -a fields; do
    # Skip empty lines
    if [ ${#fields[@]} -eq 0 ]; then
        continue
    fi

    # Extract the URL from the identified column and remove surrounding quotes
    url="${fields[$url_col]}"
    url=$(echo "$url" | sed 's/^"//;s/"$//')

    # Check if the URL is valid (starts with http or https)
    if [[ "$url" =~ ^https?:// ]]; then
        echo "Processing URL: $url"

        # Remove the protocol (http:// or https://)
        no_proto="${url#http://}"
        no_proto="${no_proto#https://}"

        # Remove the domain part to extract the URL path:
        # If there is a '/', everything after the first slash is the path.
        if [[ "$no_proto" == */* ]]; then
            path_part="${no_proto#*/}"
        else
            path_part=""
        fi

        # Get the file name from the URL path
        file_name=$(basename "$path_part")

        # Get the directory portion of the URL path
        dir_path=$(dirname "$path_part")
        # If no directory structure is found, dirname returns ".", so we set it to empty.
        if [ "$dir_path" = "." ]; then
            dir_path=""
        fi

        # Create the directory structure if needed and define the destination path
        if [ -n "$dir_path" ]; then
            mkdir -p "$dir_path"
            smbclient -U Cassandra%FK0OKjV2 //10.206.160.163/at_share --directory cassandra -c "mkdir $dir_path"
            destination="$dir_path/$file_name"
        else
            destination="$file_name"
        fi

        echo "Downloading: $url"
        echo "Saving as: $destination"
        curl -o "$destination" "$url"
        smbclient -U Cassandra%FK0OKjV2 //10.206.160.163/at_share --directory "cassandra/$dir_path" -c "put $destination"
        rm "$destination"
    else
        echo "Skipping invalid URL: $url"
    fi
done