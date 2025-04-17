#!/bin/bash


# Configurable variables (can be overridden via environment variables)
SMB_SERVER="${SMB_SERVER:-smb.example.com}"
SMB_SHARE="${SMB_SHARE:-share}"
SMB_USERNAME="${SMB_USERNAME:-username}"
SMB_PASSWORD="${SMB_PASSWORD:-password}"
# Optionally, set a remote base directory on the SMB share (leave empty if not needed)
SMB_REMOTE_BASE_DIR="${SMB_REMOTE_BASE_DIR:-}"

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

        # Remove the domain part to extract the URL path (everything after the first slash)
        if [[ "$no_proto" == */* ]]; then
            path_part="${no_proto#*/}"
        else
            path_part=""
        fi

        # Get the file name from the URL path
        file_name=$(basename "$path_part")

        # Get the directory portion of the URL path
        dir_path=$(dirname "$path_part")
        # If no directory structure is found (dirname returns "."), set it to empty.
        if [ "$dir_path" = "." ]; then
            dir_path=""
        fi

        # Create the local directory structure if needed and define destination path
        if [ -n "$dir_path" ]; then
            mkdir -p "$dir_path"
            destination="$dir_path/$file_name"
        else
            destination="$file_name"
        fi

        echo "Downloading: $url"
        echo "Saving as: $destination"
        curl -o "$destination" "$url"

        # Build remote directory path: Prepend SMB_REMOTE_BASE_DIR if set
        remote_dir="$dir_path"
        if [ -n "$SMB_REMOTE_BASE_DIR" ]; then
            remote_dir="$SMB_REMOTE_BASE_DIR/$dir_path"
        fi

        # Create the remote directory structure if necessary
        if [ -n "$remote_dir" ]; then
            smbclient -U "${SMB_USERNAME}%${SMB_PASSWORD}" //"${SMB_SERVER}"/"${SMB_SHARE}" --directory "$SMB_REMOTE_BASE_DIR" -c "mkdir \"$remote_dir\"" 2>/dev/null
        fi

        # Upload the file using smbclient
        smbclient -U "${SMB_USERNAME}%${SMB_PASSWORD}" //"${SMB_SERVER}"/"${SMB_SHARE}" --directory "${remote_dir}" -c "put \"$destination\""

        # Remove the local copy after successful upload
        rm "$destination"
    else
        echo "Skipping invalid URL: $url"
    fi
done