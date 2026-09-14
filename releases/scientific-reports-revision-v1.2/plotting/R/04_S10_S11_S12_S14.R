#!/usr/bin/env Rscript

# R-only submission plotting workflow for reviewer-revision figures S10-S14.
# Visual tokens mirror submission/code/13_make_submission_figures.R.
set.seed(20260904)
analysis_library <- Sys.getenv("SIC_R_LIBRARY", unset = "")
if (nzchar(analysis_library)) .libPaths(c(analysis_library, .libPaths()))

suppressPackageStartupMessages({
  library(data.table)
  library(ggplot2)
  library(patchwork)
  library(svglite)
  library(ragg)
})

args <- commandArgs(trailingOnly = TRUE)
arg_value <- function(flag, env, default) {
  hit <- which(args == flag)
  if (length(hit) && hit[1] < length(args)) return(args[hit[1] + 1L])
  Sys.getenv(env, unset = default)
}
PROJECT_DIR <- normalizePath(arg_value("--project", "SIC_PROJECT_DIR", getwd()), mustWork = TRUE)
STAGE <- normalizePath(arg_value("--output", "SIC_FIGURE_OUTPUT", getwd()), mustWork = TRUE)
SD <- file.path(Sys.getenv("SIC_R7_BASE"), "figure_source_data")
FIG <- file.path(STAGE, "figures")
dir.create(FIG, recursive = TRUE, showWarnings = FALSE)

PAL <- c(risk = "#B94C43", protective = "#3D73A6", neutral = "#B7B7B7",
         RNA = "#3A78A8", Protein = "#C77B30", purple = "#74649A",
         teal = "#3C938B", without = "#B7B7B7", with = "#3A78A8")

theme_pub <- function(base_size = 7, base_family = "Arial") {
  theme_classic(base_size = base_size, base_family = base_family) +
    theme(
      axis.line = element_line(linewidth = .35, colour = "black"),
      axis.ticks = element_line(linewidth = .35, colour = "black"),
      axis.title = element_text(size = base_size),
      axis.text = element_text(size = base_size - .5),
      legend.title = element_text(size = base_size - .3),
      legend.text = element_text(size = base_size - .7),
      strip.background = element_blank(),
      strip.text = element_text(size = base_size - .2, face = "bold"),
      plot.title = element_text(size = base_size + .5, face = "bold", hjust = .5),
      plot.title.position = "plot", plot.tag.position = "topleft",
      plot.tag = element_text(size = 8, face = "bold"),
      panel.grid = element_blank(),
      axis.title.x = element_text(margin = margin(t = 2)),
      axis.title.y = element_text(margin = margin(r = 2)),
      axis.text.y = element_text(hjust = 1, margin = margin(r = 1.5)),
      plot.margin = margin(6, 9, 10, 9)
    )
}
source(file.path(Sys.getenv("SIC_PLOT_ROOT"), "R", "11_title_hierarchy.R"))
theme_set(theme_pub())

legacy_save_bundle <- function(plot, stem, width_mm, height_mm, dpi = 600) {
  w <- width_mm / 25.4
  h <- height_mm / 25.4
  svglite::svglite(paste0(stem, ".svg"), width = w, height = h, bg = "white")
  draw_title_hierarchy(plot); dev.off()
  grDevices::cairo_pdf(paste0(stem, ".pdf"), width = w, height = h, family = "sans", bg = "white")
  draw_title_hierarchy(plot); dev.off()
  ragg::agg_tiff(paste0(stem, ".tiff"), width = w, height = h, units = "in", res = dpi, compression = "lzw")
  draw_title_hierarchy(plot); dev.off()
  ragg::agg_png(paste0(stem, ".png"), width = w, height = h, units = "in", res = dpi, background = "white")
  draw_title_hierarchy(plot); dev.off()
}

pathway_label <- function(x) {
  labels <- c(
    TNFA_SIGNALING_VIA_NFKB = "TNF-alpha signaling via NF-kappaB",
    IL6_JAK_STAT3_SIGNALING = "IL-6/JAK/STAT3 signaling",
    INTERFERON_ALPHA_RESPONSE = "IFN-alpha response",
    INTERFERON_GAMMA_RESPONSE = "IFN-gamma response",
    EPITHELIAL_MESENCHYMAL_TRANSITION = "Epithelial-mesenchymal transition",
    TGF_BETA_SIGNALING = "TGF-beta signaling",
    OXIDATIVE_PHOSPHORYLATION = "Oxidative phosphorylation",
    REACTIVE_OXYGEN_SPECIES_PATHWAY = "Reactive oxygen species pathway",
    MYC_TARGETS_V1 = "MYC targets V1",
    MYC_TARGETS_V2 = "MYC targets V2",
    E2F_TARGETS = "E2F targets",
    DNA_REPAIR = "DNA repair",
    MTORC1_SIGNALING = "mTORC1 signaling",
    G2M_CHECKPOINT = "G2M checkpoint",
    UNFOLDED_PROTEIN_RESPONSE = "Unfolded protein response",
    FATTY_ACID_METABOLISM = "Fatty acid metabolism",
    PROTEIN_SECRETION = "Protein secretion"
  )
  out <- unname(labels[x])
  missing <- is.na(out)
  out[missing] <- tools::toTitleCase(tolower(gsub("_", " ", x[missing])))
  out
}

source(file.path(Sys.getenv("SIC_PLOT_ROOT"), "R", "typography.R"))
# S10: Day-5 protein EMT/ECM leading-edge forest plot.
s10 <- fread(file.path(SD, "SourceData_Supplementary_Figure_S10_D5_EMT_leading_edge.csv"))
s10[, evidence := fifelse(padj_y < .05 & HR > 1, "Higher mortality hazard",
                          fifelse(padj_y < .05 & HR < 1, "Lower mortality hazard", "Not FDR-significant"))]
s10[, gene_symbol := factor(gene_symbol, levels = rev(gene_symbol[order(HR)]))]
p10 <- ggplot(s10, aes(HR, gene_symbol, xmin = lower95, xmax = upper95, colour = evidence)) +
  geom_vline(xintercept = 1, linetype = 2, linewidth = .35, colour = "#777777") +
  geom_errorbarh(height = 0, linewidth = .35) +
  geom_point(size = 1.4) +
  scale_x_log10() +
  scale_colour_manual(values = c("Higher mortality hazard" = unname(PAL["risk"]),
                                 "Lower mortality hazard" = unname(PAL["protective"]),
                                 "Not FDR-significant" = "#8C8C8C")) +
  labs(x = "Hazard ratio per 1-SD increase (95% CI)", y = NULL, colour = NULL,
       title = "Day-5 EMT/ECM leading-edge protein associations") +
  theme_pub(6.2) + theme(legend.position = "top")
save_bundle(p10, file.path(FIG, "Supplementary_Figure_S10_D5_EMT_leading_edge"), 150, 220)

# S11: complete significant Hallmark landscape.
s11 <- fread(file.path(SD, "SourceData_Supplementary_Figure_S11_all_significant_Hallmark.csv"))
s11[, pathway_display := pathway_label(pathway)]
s11[, star := fifelse(padj < .001, "***", fifelse(padj < .01, "**", fifelse(padj < .05, "*", "")))]
s11[, Time := factor(Time, levels = c("D1", "D3", "D5"))]
s11[, pathway_display := factor(pathway_display, levels = rev(unique(pathway_display[order(NES)])))]
p11 <- ggplot(s11, aes(Time, pathway_display, fill = NES)) +
  geom_tile(colour = "white", linewidth = .25) +
  geom_text(aes(label = star), size = 2.0) +
  facet_wrap(~ Omic, scales = "free_y", ncol = 2) +
  scale_fill_gradient2(low = PAL["protective"], mid = "white", high = PAL["risk"], midpoint = 0) +
  labs(x = NULL, y = NULL, fill = "NES",
       title = "Hallmark pathways reaching FDR < 0.05 at one or more landmarks") +
  theme_pub(6.0) + theme(legend.position = "top")
save_bundle(p11, file.path(FIG, "Supplementary_Figure_S11_all_significant_Hallmark"), 183, 205)

# S12: adjusted IFN cross-omic effects and the D1 MYC direction contrast.
s12_ifn <- fread(file.path(SD, "SourceData_Supplementary_Figure_S12_IFN_adjusted.csv"))
s12_ifn[, estimate_display := ifelse(grepl("Spearman", estimate_type),
                                     "Adjusted partial Spearman rho", "Adjusted beta (95% CI)")]
s12_ifn[, label_ascii := ifelse(
  grepl("same-time", label),
  paste(pathway_label(Pathway), "| same-time", Time),
  paste(pathway_label(Pathway), "|", sub("RNA ", "", Direction))
)]
s12_ifn[, label_ascii := factor(label_ascii, levels = rev(unique(label_ascii)))]
p12a <- ggplot(s12_ifn, aes(estimate, label_ascii, colour = estimate_display)) +
  geom_vline(xintercept = 0, linetype = 2, linewidth = .35, colour = "#777777") +
  geom_errorbarh(aes(xmin = lower95, xmax = upper95), height = 0, linewidth = .4, na.rm = TRUE) +
  geom_point(size = 1.7) +
  scale_colour_manual(values = c("Adjusted partial Spearman rho" = unname(PAL["purple"]),
                                 "Adjusted beta (95% CI)" = unname(PAL["RNA"]))) +
  scale_y_discrete(labels=function(x) gsub(' | ','\n',x,fixed=TRUE)) +
  labs(x = "Adjusted association\nestimate", y = NULL, colour = NULL,
       title = "Interferon cross-omic\nassociations") +
  guides(colour=guide_legend(ncol=1)) +
  theme_pub(6.1) + theme(legend.position = "top")

s12_myc <- fread(file.path(SD, "SourceData_Supplementary_Figure_S12_MYC_discordance.csv"))
s12_myc[, Omic := factor(Omic, levels = c("Whole-blood RNA-seq", "Plasma proteomics"))]
p12b <- ggplot(s12_myc, aes(Omic, NES, fill = Omic)) +
  geom_hline(yintercept = 0, linewidth = .35, colour = "#777777") +
  geom_col(width = .6) +
  geom_text(aes(label = sprintf("NES %.2f\nFDR %.3g", NES, padj)),
            vjust = ifelse(s12_myc$NES >= 0, -0.35, 1.25), size = 2.3) +
  scale_fill_manual(values = c("Whole-blood RNA-seq" = unname(PAL["RNA"]),
                               "Plasma proteomics" = unname(PAL["Protein"]))) +
  scale_x_discrete(labels = c("Whole-blood RNA-seq" = "Whole-blood\nRNA-seq", "Plasma proteomics" = "Plasma\nproteomics")) +
  labs(x = NULL, y = "Mortality-association NES", fill = NULL,
       title = "D1 MYC targets V1\ndirection contrast") +
  coord_cartesian(ylim = c(min(s12_myc$NES) - .5, max(s12_myc$NES) + .5), clip = "off") +
  theme_pub(6.1) + theme(legend.position = "none", axis.text.x = element_text(angle = 0))

fig12 <- p12a + p12b + plot_layout(widths = c(1.4, .8)) + plot_annotation(tag_levels = "a")
save_bundle(fig12, file.path(FIG, "Supplementary_Figure_S12_cross_omic_sensitivity"), 183, 130)

# S14: reviewer-requested finite gene-set permutation diagnostic.
s14 <- fread(file.path(SD, "SourceData_Supplementary_Figure_S14_D5_EMT_finite_permutation.tsv"))
s14_summary <- fread(file.path(SD, "SourceData_Supplementary_Figure_S14_D5_EMT_finite_permutation_summary.tsv"))
p14 <- ggplot(s14, aes(ES)) +
  geom_histogram(bins = 60, fill = unname(PAL["neutral"]), colour = "white", linewidth = .15) +
  geom_vline(xintercept = s14_summary$observed_ES, colour = unname(PAL["risk"]), linewidth = .65) +
  annotate("text", x = s14_summary$observed_ES, y = Inf,
           label = sprintf("Observed ES = %.3f\nEmpirical P = %.4g", s14_summary$observed_ES,
                           s14_summary$empirical_two_sided_P),
           hjust = 1.05, vjust = 1.35, size = 2.5, colour = unname(PAL["risk"])) +
  labs(x = "Enrichment score under random gene-set permutation", y = "Permutation count",
       title = "Day-5 plasma-protein EMT finite-permutation diagnostic",
       subtitle = "10,000 random gene sets of identical detected size;\nprimary inference remains fgseaMultilevel") +
  theme_pub(6.5)
save_bundle(p14, file.path(FIG, "Supplementary_Figure_S14_D5_EMT_finite_permutation"), 150, 105)

cat("Supplementary Figures S10-S14 exported with the locked publication style.\n")
writeLines(capture.output(sessionInfo()), file.path(STAGE, "qa", "sessionInfo_S10_S14_figures.txt"))
