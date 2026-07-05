#!/usr/bin/env Rscript

options(repos = c(CRAN = "https://cloud.r-project.org"))

if(!'argparse' %in% installed.packages()[,'Package']) install.packages('argparse')
if(!'gargle' %in% installed.packages()[,'Package']) install.packages('gargle')
if(!'googledrive' %in% installed.packages()[,'Package']) install.packages('googledrive')
library(argparse)
library(gargle)
library(googledrive)

#Args-----------------------------------------------------------------------------------------------
parser <- ArgumentParser(description = "Download all unique gene folders + summary files from a Drive folder")
parser$add_argument('--id', required = TRUE, help = 'Google Drive folder ID to download from')
parser$add_argument('--out', required = TRUE, help = 'Output directory to download into')
parser$add_argument('--auth', required = TRUE, help = 'Email address associated with the cached gargle token')
parser$add_argument('--dry', action = 'store_true', help = 'Dry run - just print nrow(all_contents) and exit, no downloading')
args <- parser$parse_args()

#Auth-------------------------------------------------------------------------------------------------
cache_dir <- "~/.cache/gargle"

if(!dir.exists(path.expand(cache_dir)) || length(list.files(path.expand(cache_dir))) == 0) {
  cat("
No cached gargle token found at ~/.cache/gargle

To set this up:
  1. On your local machine, authenticate once:
       library(googledrive)
       drive_auth(scopes = 'https://www.googleapis.com/auth/drive')
  2. Copy the cached token folder to this server:
       scp -r ~/Library/Caches/gargle <user>@<server>:~/.cache/
  3. Re-run this script with --auth set to the email used above.

")
  quit(save = 'no', status = 1)
}

options(gargle_oauth_cache = cache_dir)
drive_auth(cache = cache_dir, email = args$auth)

#Fetch contents-----------------------------------------------------------------------------------------
folder_id <- as_id(args$id)
contents <- drive_ls(folder_id)

if(args$dry) {
  cat(sprintf("nrow(all_contents) = %d\n", nrow(contents)))
  quit(save = 'no', status = 0)
}

#Download everything in one go--------------------------------------------------------------------------
mime_types <- sapply(contents$drive_resource, function(x) x$mimeType)
dir.create(args$out, showWarnings = FALSE, recursive = TRUE)

cat(sprintf("Found %d items to download.\n", nrow(contents)))

for(i in seq_len(nrow(contents))) {
  name <- contents$name[i]
  id <- contents$id[i]
  is_folder <- mime_types[i] == "application/vnd.google-apps.folder"
  
  cat(sprintf("[%d/%d] Processing: %s\n", i, nrow(contents), name))
  
  if(name == ".DS_Store") {
    cat("  -> skipping (.DS_Store)\n")
    next
  }
  
  if(is_folder) {
    gene_dir <- file.path(args$out, name)
    dir.create(gene_dir, showWarnings = FALSE, recursive = TRUE)
    gene_files <- drive_ls(as_id(id))
    
    for(j in seq_len(nrow(gene_files))) {
      cat(sprintf("  -> downloading %s (%d/%d)\n", gene_files$name[j], j, nrow(gene_files)))
      drive_download(as_id(gene_files$id[j]), path = file.path(gene_dir, gene_files$name[j]), overwrite = TRUE)
    }
    cat(sprintf("  done: %s - %d files downloaded\n", name, nrow(gene_files)))
    
  } else {
    cat(sprintf("  -> downloading %s\n", name))
    drive_download(as_id(id), path = file.path(args$out, name), overwrite = TRUE)
    cat(sprintf("  done: %s\n", name))
  }
}

cat(sprintf("Done. %d items processed.\n", nrow(contents)))