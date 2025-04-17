# NOAA S3 Download Tool
This repository contains tools to download and process NOAA LiDAR data from an S3 bucket. It includes a Jupyter Notebook for querying and preparing metadata and a generalized bash script for downloading the files.

## Files

- **query_table.ipynb**  
    A Jupyter Notebook that:
    - Fetches and parses tile indices from NOAA’s S3 bucket.
    - Extracts shapefile information to build a GeoDataFrame.
    - Cleans and saves the data as a CSV file (`data_table.csv`) with fields: `url`, `name`, `geometry`.

- **download_script.sh**  
    A generalized bash script that:
    - Reads a CSV file (e.g., `nola_data.csv`) generated from the notebook.
    - Extracts the URL field from each row.
    - Downloads the corresponding file from the S3 bucket.
    - Creates local directories as needed.
    - (Optionally) uploads the file to an SMB share using configurable environment variables.
    - Removes the local copy after processing.
    
- **environment.yaml**  
    A conda environment configuration file specifying the required dependencies and Python version (Python 3.12). Use it to set up the project environment.

- **README.md**  
    This file.

## Setup

### 1. Create and Activate the Conda Environment

```bash
conda env create -f environment.yaml
conda activate noaa_s3_env
```

### 2. Run the Notebook

Open `query_table.ipynb` in Jupyter Notebook or Visual Studio Code to:

- Fetch and parse all of the NOAA S3 bucket tile indices.
- Build a GeoDataFrame from the extracted shapefile information.
- Clean and save the metadata as a CSV file (`data_table.csv`).
- Optionally create a smaller CSV (e.g., `nola_data.csv`) based on spatial queries.

### 3. Generalized Download Script

The generalized download script can be configured via environment variables. By default, it downloads files based on the `url` column in the CSV and uploads them to an SMB share.

#### Configuring Environment Variables

##### Configurable Variables:

- `SMB_SERVER` – The SMB server hostname (default: `smb.example.com`).
- `SMB_SHARE` – The SMB share name (default: `share`).
- `SMB_USERNAME` – Username for SMB authentication (default: `username`).
- `SMB_PASSWORD` – Password for SMB authentication (default: `password`).
- `SMB_REMOTE_BASE_DIR` – (Optional) Remote base directory on the SMB share.

You can override the default settings in the download script by defining environment variables before running the script. For example, to configure the SMB server, share, and credentials, you can run:

```bash
export SMB_SERVER="your_smb_server"
export SMB_SHARE="your_share"
export SMB_USERNAME="your_username"
export SMB_PASSWORD="your_password"
export SMB_REMOTE_BASE_DIR="optional/remote/base/dir" 
```

After exporting these variables, run the script as usual:

```bash
./download_script.sh <csv_file>
```

The script will:

1. Identify the `url` column (named `url` or `link`) from your CSV.
2. Download each file from the NOAA S3 bucket.
3. Create necessary local directory structures.
4. If configured, create remote directories and upload the file using `smbclient`.
5. Delete the local copy after processing.

## Customization

### Local Downloads:
The script creates local directories matching the URL path structure. Modify the script if you need a different folder layout.

### SMB Uploads:
To enable file uploads, ensure you set your `SMB_SERVER`, `SMB_SHARE`, `SMB_USERNAME`, and `SMB_PASSWORD` appropriately. If you do not require uploads, you can remove or comment out the `smbclient` calls in the script.

### Keep Files Locally:
If you wish to retain the downloaded files, simply remove the `rm "$destination"` command near the end of the script.