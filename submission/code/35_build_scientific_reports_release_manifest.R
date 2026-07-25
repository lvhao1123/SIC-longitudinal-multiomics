# Rebuild the complete public submission manifest for the Scientific Reports release.
args <- commandArgs(trailingOnly = TRUE)
repo_root <- normalizePath(if (length(args)) args[[1]] else ".", winslash = "/")
source(file.path(repo_root, "scripts", "build_public_manifest.R"), local = new.env(parent = globalenv()))
