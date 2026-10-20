rm(list = ls())
source("outputs/SIC_reanalysis_2026-07-11/code/00_config.R")
suppressPackageStartupMessages({library(data.table); library(stringr); library(AnnotationDbi); library(org.Hs.eg.db)})

ids <- fread(INPUT$rna_counts, select = "gene_id", data.table = FALSE)$gene_id
ids <- unique(str_remove(as.character(ids), "\\.[0-9]+$"))
mapped <- AnnotationDbi::select(org.Hs.eg.db, keys = ids, keytype = "ENSEMBL", columns = "SYMBOL")
setDT(mapped); setnames(mapped, c("ENSEMBL", "SYMBOL"), c("ensembl_gene_id", "gene_symbol"))
mapped <- unique(mapped[!is.na(gene_symbol) & gene_symbol != ""])
conflicts <- mapped[, .(n_symbols = uniqueN(gene_symbol), symbols = paste(sort(unique(gene_symbol)), collapse = ";")), by = ensembl_gene_id][n_symbols > 1]
# Exclude ambiguous one-to-many mappings; retain one-to-one official mappings only.
official <- mapped[!ensembl_gene_id %in% conflicts$ensembl_gene_id]
setorder(official, ensembl_gene_id)
fwrite(official, file.path(AUDIT_DIR, "ensembl_gene_map_orgHs_3.20_frozen.tsv"), sep = "\t")
fwrite(conflicts, file.path(AUDIT_DIR, "ensembl_gene_map_orgHs_3.20_conflicts.tsv"), sep = "\t")
fwrite(data.frame(
  metric = c("raw_unique_Ensembl", "official_mapped_one_to_one", "ambiguous_Ensembl_excluded"),
  value = c(length(ids), nrow(official), nrow(conflicts))
), file.path(AUDIT_DIR, "official_gene_map_summary.csv"))
writeLines(capture.output(sessionInfo()), file.path(AUDIT_DIR, "sessionInfo_official_annotation.txt"))
