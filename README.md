# gdrive-cli-downloader

A simple R script to bulk-download the entire contents of a Google Drive folder — including nested subfolders — using the `googledrive` package. Built to handle large folders (thousands of items) from a headless/remote server, without needing a browser on the machine actually doing the downloading.

## Features

- Recursively downloads all folders and files from a given Drive folder ID
- Deduplicates by name (keeps first match) rather than silently dropping both copies
- Skips macOS `.DS_Store` junk files automatically
- Verbose progress output — see exactly what's downloading, file by file
- `--dry` flag to check the item count before committing to a full download
- Clear setup instructions printed automatically if authentication isn't configured yet
- Works on headless/remote servers via a copied local auth token

## Requirements

- R (tested on recent versions, should work on most modern installs)
- Internet access from the machine running the script
- A Google account with access to the target Drive folder

The script will auto-install its own R package dependencies (`argparse`, `gargle`, `googledrive`) on first run if they're missing.

## Setup

### 1. Authenticate locally

Since most remote/headless servers can't open a browser for the OAuth login flow, authenticate once on your local machine instead:

```r
library(googledrive)
drive_auth(scopes = 'https://www.googleapis.com/auth/drive')
```

This opens a browser window — log in and grant full Drive access. This creates a cached token locally (on a Mac, typically under `~/Library/Caches/gargle`).

### 2. Copy the cached token to the server

```bash
scp -r ~/Library/Caches/gargle <user>@<server>:~/.cache/
```

The server now has everything it needs to authenticate as you, without ever opening a browser itself.

### 3. Confirm the token works (optional but recommended)

```r
library(gargle)
options(gargle_oauth_cache = "~/.cache/gargle")
gargle_oauth_sitrep()
```

This should list your cached token. If nothing shows up, double check the `scp` step copied the whole folder correctly.

## Usage

```bash
Rscript download_gdrive.R --id <FOLDER_ID> --out <OUTPUT_DIR> --auth <EMAIL>
```

### Arguments

| Flag | Required | Description |
|---|---|---|
| `--id` | Yes | The Google Drive folder ID to download from (the long string in the folder's URL) |
| `--out` | Yes | Local directory to download into (created automatically if it doesn't exist) |
| `--auth` | Yes | The email address tied to your cached `gargle` token |
| `--dry` | No | If set, just prints the total item count and exits — no downloading |

### Finding a folder ID

Given a Drive folder URL like:
```
https://drive.google.com/drive/folders/g6s7lsejmtl14q3lff0vbobiawzp85af?usp=drive_link
```
the folder ID is the string between `/folders/` and the `?`:
```
g6s7lsejmtl14q3lff0vbobiawzp85af
```

### Examples

Check how many items are in a folder before downloading anything:
```bash
Rscript download_gdrive.R --id g6s7lsejmtl14q3lff0vbobiawzp85af --out my_data --auth you@example.com --dry
```

Run the full download:
```bash
Rscript download_gdrive.R --id g6s7lsejmtl14q3lff0vbobiawzp85af --out my_data --auth you@example.com
```

Run it in the background so it survives a dropped SSH connection, logging progress to a file:
```bash
nohup Rscript download_gdrive.R --id g6s7lsejmtl14q3lff0vbobiawzp85af --out my_data --auth you@example.com > download_log.txt 2>&1 &
```

Check progress at any time:
```bash
tail -f download_log.txt
```

## How it works

1. Authenticates using the cached token found at `~/.cache/gargle`
2. Lists every item (folders and files) directly inside the given folder ID
3. Loops through each item:
   - Skips `.DS_Store` files
   - If it's a folder: recreates it locally, lists its contents, and downloads every file inside
   - If it's a file: downloads it directly into the output directory
4. Prints progress for every item and file as it goes, and a final summary once complete

## Troubleshooting

**"No cached gargle token found at ~/.cache/gargle"**
The script couldn't find an auth token on this machine. Follow the Setup steps above — authenticate locally, then `scp` the cached token folder to the server, then re-run with `--auth` set to the correct email.

**403 / Insufficient authentication scopes**
Your cached token was created without full Drive access. Re-run the local authentication step explicitly requesting the full scope:
```r
drive_auth(scopes = 'https://www.googleapis.com/auth/drive', cache = FALSE)
```
Then re-copy the refreshed token to the server.

**Script seems slow on very large folders**
This script downloads files one at a time through the Drive API, which is inherently slower than a purpose-built bulk sync tool like `rclone`. For folders in the tens of thousands of files, expect the download to take a while — running it with `nohup` in the background is recommended.

**Duplicate-named folders**
If Drive contains two folders with the same name, only the first one (by listing order) is downloaded. This is intentional — better to reliably grab one complete copy than silently skip both, which is `rclone`'s default behavior on name collisions.

## License

MIT (or update as appropriate for your project)
