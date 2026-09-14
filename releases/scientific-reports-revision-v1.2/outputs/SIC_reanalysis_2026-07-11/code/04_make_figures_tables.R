rm(list = ls())
source("outputs/SIC_reanalysis_2026-07-11/code/00_config.R")
suppressPackageStartupMessages({
  library(data.table); library(dplyr); library(tidyr); library(stringr); library(tibble); library(purrr)
  library(ggplot2); library(ggrepel); library(patchwork); library(fgsea); library(openxlsx)
})

req <- c(
  file.path(RNA_OUT, "02_all_RNA_TMM_center_stratified_cox_zph.csv"),
  file.path(RNA_OUT, "03_RNA_TMM_Hallmark_primary_PHpass.csv"),
  file.path(PROTEIN_OUT, "02_all_Protein_models_cox_zph.csv"),
  file.path(PROTEIN_OUT, "03_Protein_Hallmark_all_models.csv")
)
if (any(!file.exists(req))) stop("Run final RNA and Protein GSEA scripts first")

PAL <- c(risk = "#C54A3A", protective = "#356EA5", neutral = "#B8B8B8",
         RNA = "#3A78A8", Protein = "#C6772F", accent = "#6F5B95", dark = "#252525")
theme_pub <- function(base_size = 8) theme_classic(base_size = base_size, base_family = "sans") +
  theme(
    axis.line = element_line(linewidth = .35, colour = "black"),
    axis.ticks = element_line(linewidth = .35), panel.grid = element_blank(),
    strip.background = element_blank(), strip.text = element_text(face = "bold"),
    plot.title = element_text(face = "bold", size = base_size + 1),
    legend.title = element_text(size = base_size - .2), legend.text = element_text(size = base_size - .5)
  )
theme_set(theme_pub())

save_pub <- function(plot, stem, width_mm = 180, height_mm = 120) {
  w <- width_mm / 25.4; h <- height_mm / 25.4
  ggsave(paste0(stem, ".pdf"), plot, width = width_mm / 25.4, height = height_mm / 25.4,
         device = grDevices::cairo_pdf, family = "sans")
  ggsave(paste0(stem, ".png"), plot, width = width_mm / 25.4, height = height_mm / 25.4,
         dpi = 600, bg = "white")
  grDevices::svg(paste0(stem, ".svg"), width = w, height = h, family = "sans")
  print(plot); grDevices::dev.off()
  grDevices::tiff(paste0(stem, ".tiff"), width = w, height = h, units = "in",
                  res = 600, compression = "lzw", type = "cairo", family = "sans")
  print(plot); grDevices::dev.off()
}

rna_cox <- fread(req[1], data.table = FALSE)
rna_gsea <- fread(req[2], data.table = FALSE)
protein_cox <- fread(req[3], data.table = FALSE)
protein_gsea <- fread(req[4], data.table = FALSE)
hallmark <- gmtPathways(INPUT$hallmark)
names(hallmark) <- str_remove(names(hallmark), "^HALLMARK_")

# Main pathway panels: NES encodes mortality association, while symbols encode
# robustness rather than duplicating raw P values.
core_rna <- c(
  "HEME_METABOLISM", "HYPOXIA", "REACTIVE_OXYGEN_SPECIES_PATHWAY", "GLYCOLYSIS",
  "OXIDATIVE_PHOSPHORYLATION", "TNFA_SIGNALING_VIA_NFKB", "IL6_JAK_STAT3_SIGNALING",
  "INFLAMMATORY_RESPONSE", "INTERFERON_ALPHA_RESPONSE", "INTERFERON_GAMMA_RESPONSE",
  "COMPLEMENT", "COAGULATION", "EPITHELIAL_MESENCHYMAL_TRANSITION", "APICAL_JUNCTION",
  "MYC_TARGETS_V1", "UNFOLDED_PROTEIN_RESPONSE", "E2F_TARGETS", "DNA_REPAIR"
)
rob_file <- file.path(AUDIT_DIR, "RNA_Hallmark_normalization_PH_robustness.csv")
rna_rob <- fread(rob_file, data.table = FALSE) |> filter(pathway %in% core_rna) |>
  mutate(
    pathway_label = str_to_sentence(str_replace_all(pathway, "_", " ")),
    mark = case_when(
      evidence_tier == "Tier 1: PH- and normalization-robust" ~ "*",
      evidence_tier == "Tier 2: TMM robust, simple-logCPM attenuated" ~ "†",
      evidence_tier == "Tier 2: simple-logCPM robust, TMM attenuated" ~ "‡",
      evidence_tier == "Tier 3: normalization-sensitive" ~ "§",
      TRUE ~ ""
    ),
    label = sprintf("%.2f%s", NES_TMM_Primary, mark),
    pathway_label = factor(pathway_label, levels = rev(str_to_sentence(str_replace_all(core_rna, "_", " "))))
  )
p_rna_heat <- ggplot(rna_rob, aes(Time, pathway_label, fill = NES_TMM_Primary)) +
  geom_tile(colour = "white", linewidth = .45) + geom_text(aes(label = label), size = 2.35) +
  scale_fill_gradient2(low = PAL["protective"], mid = "white", high = PAL["risk"], midpoint = 0,
                       limits = c(-max(abs(rna_rob$NES_TMM_Primary), na.rm = TRUE), max(abs(rna_rob$NES_TMM_Primary), na.rm = TRUE))) +
  labs(x = NULL, y = NULL, fill = "Cox-GSEA\nNES",
       title = "Whole-blood mortality-associated programs across time",
       subtitle = "* PH- and normalization-robust; † TMM robust only; ‡ simple-logCPM robust only; § normalization-sensitive") +
  theme_pub(7.5) + theme(plot.subtitle = element_text(size = 6.2), legend.position = "right")
save_pub(p_rna_heat, file.path(FIGURE_OUT, "Figure2_RNA_core_NES_robustness"), 180, 130)
fwrite(rna_rob, file.path(FIGURE_OUT, "SourceData_Figure2_RNA_core_NES.csv"))

core_protein <- c(
  "HYPOXIA", "GLYCOLYSIS", "FATTY_ACID_METABOLISM", "OXIDATIVE_PHOSPHORYLATION",
  "MYC_TARGETS_V1", "MTORC1_SIGNALING", "PROTEIN_SECRETION", "COMPLEMENT",
  "EPITHELIAL_MESENCHYMAL_TRANSITION", "MYOGENESIS", "G2M_CHECKPOINT", "DNA_REPAIR"
)
pg <- protein_gsea |> mutate(
  Time = str_extract(analysis, "^D[135]"),
  Model = case_when(str_detect(analysis, "PHpass") ~ "PH",
                    str_detect(analysis, "median_center") ~ "Median",
                    TRUE ~ "Primary")
) |> select(Time, pathway, Model, NES, padj) |>
  pivot_wider(names_from = Model, values_from = c(NES, padj)) |>
  filter(pathway %in% core_protein) |>
  mutate(
    robust_all = padj_Primary < .05 & padj_PH < .05 & padj_Median < .05 &
      sign(NES_Primary) == sign(NES_PH) & sign(NES_Primary) == sign(NES_Median),
    mark = case_when(robust_all ~ "*", padj_Primary < .05 ~ "†", TRUE ~ ""),
    label = sprintf("%.2f%s", NES_Primary, mark),
    pathway_label = str_to_sentence(str_replace_all(pathway, "_", " ")),
    pathway_label = factor(pathway_label, levels = rev(str_to_sentence(str_replace_all(core_protein, "_", " "))))
  )
p_protein_heat <- ggplot(pg, aes(Time, pathway_label, fill = NES_Primary)) +
  geom_tile(colour = "white", linewidth = .45) + geom_text(aes(label = label), size = 2.35) +
  scale_fill_gradient2(low = PAL["protective"], mid = "white", high = PAL["risk"], midpoint = 0,
                       limits = c(-max(abs(pg$NES_Primary), na.rm = TRUE), max(abs(pg$NES_Primary), na.rm = TRUE))) +
  labs(x = NULL, y = NULL, fill = "Cox-GSEA\nNES",
       title = "Plasma-protein mortality-associated programs across time",
       subtitle = "* significant with concordant direction in primary, PH-pass and global-intensity models; † primary only") +
  theme_pub(7.5) + theme(plot.subtitle = element_text(size = 6.2), legend.position = "right")
save_pub(p_protein_heat, file.path(FIGURE_OUT, "Figure3_Protein_core_NES_robustness"), 180, 105)
fwrite(pg, file.path(FIGURE_OUT, "SourceData_Figure3_Protein_core_NES.csv"))

# Cross-omic figure contract: pathway concordance is selective, with IFN as the
# reproducible bridge; the reverse models are a specificity check, not causal proof.
same_file <- file.path(CROSS_OUT, "04_same_time_RNA_Protein_partial_spearman.csv")
forward_file <- file.path(CROSS_OUT, "05_forward_cross_lag_HC3.csv")
reverse_file <- file.path(CROSS_OUT, "06_reverse_cross_lag_HC3.csv")
if (all(file.exists(c(same_file, forward_file, reverse_file)))) {
  short_names <- c(
    TNFA_SIGNALING_VIA_NFKB = "TNF/NF-κB", IL6_JAK_STAT3_SIGNALING = "IL6/JAK/STAT3",
    INFLAMMATORY_RESPONSE = "Inflammation", INTERFERON_ALPHA_RESPONSE = "IFN-α",
    INTERFERON_GAMMA_RESPONSE = "IFN-γ", COAGULATION = "Coagulation", COMPLEMENT = "Complement",
    HEME_METABOLISM = "Heme/erythroid", EPITHELIAL_MESENCHYMAL_TRANSITION = "ECM remodeling",
    TGF_BETA_SIGNALING = "TGF-β", APICAL_JUNCTION = "Apical junction", HYPOXIA = "Hypoxia",
    OXIDATIVE_PHOSPHORYLATION = "OXPHOS", REACTIVE_OXYGEN_SPECIES_PATHWAY = "ROS",
    GLYCOLYSIS = "Glycolysis"
  )
  same <- fread(same_file, data.table = FALSE) |>
    mutate(
      Pathway_label = unname(short_names[Pathway]),
      Pathway_label = factor(Pathway_label, levels = rev(unname(short_names[CORE <- c(
        "TNFA_SIGNALING_VIA_NFKB", "IL6_JAK_STAT3_SIGNALING", "INFLAMMATORY_RESPONSE",
        "INTERFERON_ALPHA_RESPONSE", "INTERFERON_GAMMA_RESPONSE", "COAGULATION", "COMPLEMENT",
        "HEME_METABOLISM", "EPITHELIAL_MESENCHYMAL_TRANSITION", "TGF_BETA_SIGNALING",
        "APICAL_JUNCTION", "HYPOXIA", "OXIDATIVE_PHOSPHORYLATION",
        "REACTIVE_OXYGEN_SPECIES_PATHWAY", "GLYCOLYSIS")]))),
      mark = case_when(FDR < .001 ~ "***", FDR < .01 ~ "**", FDR < .05 ~ "*", TRUE ~ ""),
      label = paste0(sprintf("%.2f", partial_rho), mark)
    )
  p_same <- ggplot(same, aes(Time, Pathway_label, fill = partial_rho)) +
    geom_tile(colour = "white", linewidth = .4) + geom_text(aes(label = label), size = 2.15) +
    scale_fill_gradient2(low = PAL["protective"], mid = "white", high = PAL["risk"], midpoint = 0, limits = c(-.55, .55)) +
    labs(x = NULL, y = NULL, fill = "Partial\nSpearman rho", title = "Same-time RNA-protein concordance") +
    theme_pub(7) + theme(legend.position = "right")

  forward <- fread(forward_file, data.table = FALSE) |>
    mutate(
      Pathway_label = unname(short_names[Pathway]),
      Direction = str_replace_all(Direction, " to ", " → ") |>
        str_replace("RNA D1 → Protein D3", "D1 → D3") |>
        str_replace("RNA D3 → Protein D5", "D3 → D5")
    )
  forward_sig <- forward |> filter(FDR < .05) |>
    mutate(label = paste(Pathway_label, Direction, sep = "  |  "))
  p_forward <- ggplot(forward_sig, aes(beta, reorder(label, beta), colour = Direction)) +
    geom_vline(xintercept = 0, linetype = 2, linewidth = .35, colour = "grey45") +
    geom_errorbarh(aes(xmin = lower95, xmax = upper95), height = .15, linewidth = .5) +
    geom_point(size = 2.4) +
    scale_colour_manual(values = c("D1 → D3" = unname(PAL["RNA"]),
                                   "D3 → D5" = unname(PAL["accent"]))) +
    labs(x = "Adjusted standardized coefficient (95% CI)", y = NULL, colour = NULL,
         title = "Forward cross-time associations") +
    theme_pub(7) + theme(legend.position = "none")

  reverse <- fread(reverse_file, data.table = FALSE)
  reverse_n <- sum(reverse$FDR < .05, na.rm = TRUE)
  p_reverse <- ggplot() +
    annotate("rect", xmin = 0, xmax = 1, ymin = 0, ymax = 1, fill = "#F1F1F1", colour = "#A0A0A0") +
    annotate("text", x = .5, y = .62, label = "Reverse Protein → RNA", fontface = "bold", size = 2.8) +
    annotate("text", x = .5, y = .38, label = paste0(reverse_n, " pathways at BH-FDR < 0.05"), size = 2.6) +
    coord_cartesian(xlim = c(0, 1), ylim = c(0, 1), clip = "off") + theme_void()

  cross_fig <- (p_same | (p_forward / p_reverse + plot_layout(heights = c(1.4, .65)))) +
    plot_layout(widths = c(1.15, 1)) +
    plot_annotation(tag_levels = "a", title = "Pathway-selective cross-compartment coupling")
  save_pub(cross_fig, file.path(FIGURE_OUT, "Figure4_CrossOmics_IFN_coupling"), 183, 125)
  fwrite(same, file.path(FIGURE_OUT, "SourceData_Figure4_same_time.csv"))
  fwrite(forward, file.path(FIGURE_OUT, "SourceData_Figure4_forward.csv"))
  fwrite(reverse, file.path(FIGURE_OUT, "SourceData_Figure4_reverse.csv"))
}

# Figure contract: the volcanoes document the complete feature-level mortality landscape;
# they are transparency panels, not the main mechanistic evidence.
make_volcano <- function(x, feature, title, n_label = 5) {
  x <- x |> mutate(
    log2HR = logHR / log(2), y = -log10(pmax(padj, .Machine$double.xmin)),
    class = case_when(padj < .05 & logHR > 0 ~ "Higher risk",
                      padj < .05 & logHR < 0 ~ "Lower risk", TRUE ~ "Not FDR-significant")
  )
  labels <- bind_rows(
    x |> filter(class == "Higher risk") |> slice_min(padj, n = n_label, with_ties = FALSE),
    x |> filter(class == "Lower risk") |> slice_min(padj, n = n_label, with_ties = FALSE)
  )
  ggplot(x, aes(log2HR, y, colour = class)) +
    geom_point(size = .65, alpha = .65) +
    geom_hline(yintercept = -log10(.05), linetype = 2, linewidth = .3) +
    geom_vline(xintercept = 0, linewidth = .25, colour = "grey40") +
    geom_text_repel(data = labels, aes(label = .data[[feature]]), colour = PAL["dark"],
                    size = 2.2, max.overlaps = Inf, seed = 20260711, min.segment.length = 0) +
    scale_colour_manual(values = c("Higher risk" = unname(PAL["risk"]), "Lower risk" = unname(PAL["protective"]),
                                   "Not FDR-significant" = unname(PAL["neutral"]))) +
    labs(title = title, x = expression(log[2](HR~per~1*SD)), y = expression(-log[10](BH-FDR)), colour = NULL) +
    theme_pub() + theme(legend.position = "none")
}

rna_vol <- wrap_plots(lapply(c("D1", "D3", "D5"), function(tm)
  make_volcano(rna_cox |> filter(Time == tm), "gene_symbol", tm)), nrow = 1) +
  plot_annotation(title = "Whole-blood RNA feature-level mortality associations", tag_levels = "a")
save_pub(rna_vol, file.path(FIGURE_OUT, "Supplementary_RNA_Cox_volcanoes"), 180, 65)

protein_primary <- protein_cox |> filter(model == "center_primary")
protein_vol <- wrap_plots(lapply(c("D1", "D3", "D5"), function(tm)
  make_volcano(protein_primary |> filter(Time == tm), "gene_symbol", tm, n_label = 3)), nrow = 1) +
  plot_annotation(title = "Plasma-protein feature-level mortality associations", tag_levels = "a")
save_pub(protein_vol, file.path(FIGURE_OUT, "Supplementary_Protein_Cox_volcanoes"), 180, 65)

make_enrichment <- function(cox, pathway, title) {
  ranks <- cox$z; names(ranks) <- cox$gene_symbol; ranks <- sort(ranks[is.finite(ranks)], decreasing = TRUE)
  raw_plot <- plotEnrichment(hallmark[[pathway]], ranks)
  curve <- as.data.frame(raw_plot$data)
  hits <- data.frame(rank = which(names(ranks) %in% hallmark[[pathway]]))
  peak <- curve$ES[which.max(abs(curve$ES))]
  signal_colour <- if (peak >= 0) unname(PAL["risk"]) else unname(PAL["protective"])
  ggplot(curve, aes(rank, ES)) +
    geom_hline(yintercept = 0, linewidth = .3, colour = "grey35") +
    geom_hline(yintercept = peak, linetype = 2, linewidth = .35, colour = signal_colour) +
    geom_line(linewidth = .65, colour = signal_colour) +
    geom_rug(data = hits, aes(x = rank), inherit.aes = FALSE, sides = "b", linewidth = .25, alpha = .55) +
    labs(title = title, x = "Cox Wald-z rank", y = "Running enrichment score") + theme_pub(7)
}

rna_curve_spec <- tribble(
  ~Time, ~Pathway, ~Label,
  "D1", "HEME_METABOLISM", "D1 erythroid/heme-associated program",
  "D3", "TNFA_SIGNALING_VIA_NFKB", "D3 TNF/NF-kB signaling",
  "D5", "OXIDATIVE_PHOSPHORYLATION", "D5 oxidative phosphorylation",
  "D5", "UNFOLDED_PROTEIN_RESPONSE", "D5 unfolded protein response"
)
rna_curves <- pmap(rna_curve_spec, function(Time, Pathway, Label)
  make_enrichment(rna_cox |> filter(.data$Time == .env$Time, fit_ok), Pathway, Label))
rna_curve_fig <- wrap_plots(rna_curves, ncol = 2) + plot_annotation(tag_levels = "a")
save_pub(rna_curve_fig, file.path(FIGURE_OUT, "Representative_RNA_GSEA_curves"), 180, 125)

protein_curve_spec <- tribble(
  ~Time, ~Pathway, ~Label,
  "D1", "HYPOXIA", "D1 hypoxia",
  "D3", "EPITHELIAL_MESENCHYMAL_TRANSITION", "D3 ECM/remodeling signature",
  "D3", "OXIDATIVE_PHOSPHORYLATION", "D3 oxidative phosphorylation",
  "D5", "EPITHELIAL_MESENCHYMAL_TRANSITION", "D5 ECM/remodeling signature"
)
protein_curves <- pmap(protein_curve_spec, function(Time, Pathway, Label)
  make_enrichment(protein_primary |> filter(.data$Time == .env$Time, fit_ok), Pathway, Label))
protein_curve_fig <- wrap_plots(protein_curves, ncol = 2) + plot_annotation(tag_levels = "a")
save_pub(protein_curve_fig, file.path(FIGURE_OUT, "Representative_Protein_GSEA_curves"), 180, 125)

# Figure 1 contract: prove cohort traceability and risk-set correctness before biological inference.
flow <- data.frame(
  x = c(1, 2.2, 3.4, 4.6), y = 1,
  label = c("Day-1 SIC cohort\n504 patients\n84 deaths by day 60",
            "Longitudinal sampling\nwhole blood + plasma",
            "Risk-set entry\nD1=0, D3=2, D5=4",
            "Centre-stratified Cox\nPH audit + Hallmark GSEA")
)
p_flow <- ggplot(flow, aes(x, y)) +
  geom_label(aes(label = label), fill = "white", linewidth = .35, size = 2.6, lineheight = .95) +
  geom_segment(data = data.frame(x = c(1.35, 2.55, 3.75), xend = c(1.85, 3.05, 4.25), y = 1, yend = 1),
               aes(x = x, xend = xend, y = y, yend = yend), arrow = arrow(length = grid::unit(2, "mm")), linewidth = .45) +
  coord_cartesian(xlim = c(.55, 5.05), ylim = c(.65, 1.35), clip = "off") + theme_void()

risk <- EXPECTED |> mutate(label = paste0("N=", N, "\nEvents=", Events))
p_risk <- ggplot(risk, aes(Time, N, fill = Omics)) +
  geom_col(position = position_dodge(width = .72), width = .62) +
  geom_text(aes(label = label), position = position_dodge(width = .72), vjust = -.2, size = 2.5, lineheight = .9) +
  scale_fill_manual(values = PAL[c("RNA", "Protein")]) +
  scale_y_continuous(expand = expansion(mult = c(0, .18))) +
  labs(x = NULL, y = "Risk-valid samples", fill = NULL, title = "Longitudinal molecular risk sets") +
  theme_pub() + theme(legend.position = "top")

timeline <- data.frame(Time = c("D1", "D3", "D5", "Day 60"), x = c(0, 1.2, 2.4, 6), y = 0)
p_time <- ggplot(timeline, aes(x, y)) +
  annotate("segment", x = 0, xend = 6, y = 0, yend = 0, linewidth = .55,
           arrow = arrow(length = grid::unit(2, "mm"))) +
  geom_point(data = timeline |> filter(Time != "Day 60"), size = 3, colour = PAL["accent"]) +
  geom_text(aes(label = Time), vjust = -1.2, size = 2.7) +
  annotate("text", x = 3, y = -.18, label = "Molecular state predicts subsequent mortality (timeline not to scale)", size = 2.5) +
  coord_cartesian(xlim = c(-.35, 6.35), ylim = c(-.32, .2), clip = "off") + theme_void()

fig1 <- p_flow / (p_risk | p_time) + plot_layout(heights = c(.85, 1.4), widths = c(1, 1.2)) +
  plot_annotation(tag_levels = "a", title = "Study design and risk-set-aware longitudinal analysis")
save_pub(fig1, file.path(FIGURE_OUT, "Figure1_study_design_risksets"), 180, 120)

# Graphical abstract contract: concise stage-dependent mortality-associated states; no causal arrows.
stage <- data.frame(
  xmin = c(.4, 3.55, 6.7), xmax = c(3.0, 6.15, 9.3), ymin = 1.5, ymax = 4.5,
  title = c("Day 1", "Day 3", "Day 5"),
  body = c(
    "Erythroid/heme\nHypoxia + TNF/NF-kB\nCoagulation + glycolysis\nOXPHOS lower",
    "Inflammatory-oxidative peak\nTNF + IL6 + ROS\nHypoxia + complement\nECM remodeling emerges",
    "Bioenergetic-reparative failure\nOXPHOS + MYC lower\nUPR + DNA repair lower\nPersistent ECM remodeling"
  ), fill = c("#F6E2D5", "#F3D7CE", "#DCE6F1")
)
p_ga <- ggplot() +
  geom_rect(data = stage, aes(xmin = xmin, xmax = xmax, ymin = ymin, ymax = ymax, fill = fill),
            colour = "white", linewidth = 1) +
  scale_fill_identity() +
  geom_text(data = stage, aes(x = (xmin + xmax) / 2, y = 4.02, label = title), fontface = "bold", size = 4) +
  geom_text(data = stage, aes(x = (xmin + xmax) / 2, y = 2.85, label = body), size = 3.1, lineheight = .95) +
  annotate("segment", x = 3.05, xend = 3.45, y = 3, yend = 3, arrow = arrow(length = grid::unit(2.5, "mm")), linewidth = .65) +
  annotate("segment", x = 6.2, xend = 6.6, y = 3, yend = 3, arrow = arrow(length = grid::unit(2.5, "mm")), linewidth = .65) +
  annotate("rect", xmin = 1.05, xmax = 8.65, ymin = .45, ymax = 1.15, fill = "#E7DEF0", colour = NA) +
  annotate("text", x = 4.85, y = .82,
           label = "IFN-alpha/gamma: pathway-selective RNA-protein coupling across time", size = 3.25, fontface = "bold") +
  annotate("text", x = 4.85, y = .12,
           label = "Mortality-associated circulating programs; observational associations do not establish causality", size = 2.4, colour = "grey35") +
  coord_cartesian(xlim = c(.2, 9.5), ylim = c(-.05, 4.75), clip = "off") + theme_void() +
  labs(title = "Stage-specific molecular remodeling in sepsis-induced coagulopathy") +
  theme(plot.title = element_text(hjust = .5, face = "bold", size = 12, margin = margin(b = 8)))
save_pub(p_ga, file.path(FIGURE_OUT, "Graphical_Abstract"), 235, 78)

# Complete supplementary workbook; all list columns are already flattened in the CSV inputs.
wb <- createWorkbook()
addWorksheet(wb, "RNA_Cox_all"); writeDataTable(wb, "RNA_Cox_all", rna_cox)
addWorksheet(wb, "RNA_Hallmark_all"); writeDataTable(wb, "RNA_Hallmark_all", rna_gsea)
addWorksheet(wb, "RNA_leading_edge"); writeDataTable(wb, "RNA_leading_edge", fread(file.path(RNA_OUT, "04_RNA_TMM_Hallmark_leading_edge_long.csv")))
addWorksheet(wb, "Protein_Cox_all"); writeDataTable(wb, "Protein_Cox_all", protein_cox)
addWorksheet(wb, "Protein_Hallmark_all"); writeDataTable(wb, "Protein_Hallmark_all", protein_gsea)
addWorksheet(wb, "Protein_leading_edge"); writeDataTable(wb, "Protein_leading_edge", fread(file.path(PROTEIN_OUT, "04_Protein_Hallmark_leading_edge_long.csv")))
if (file.exists(file.path(CROSS_OUT, "04_same_time_RNA_Protein_partial_spearman.csv"))) {
  addWorksheet(wb, "Cross_same_time"); writeDataTable(wb, "Cross_same_time", fread(file.path(CROSS_OUT, "04_same_time_RNA_Protein_partial_spearman.csv")))
  addWorksheet(wb, "Cross_forward"); writeDataTable(wb, "Cross_forward", fread(file.path(CROSS_OUT, "05_forward_cross_lag_HC3.csv")))
  addWorksheet(wb, "Cross_reverse"); writeDataTable(wb, "Cross_reverse", fread(file.path(CROSS_OUT, "06_reverse_cross_lag_HC3.csv")))
}
saveWorkbook(wb, file.path(FIGURE_OUT, "Supplementary_Tables_complete.xlsx"), overwrite = TRUE)

writeLines(capture.output(sessionInfo()), file.path(FIGURE_OUT, "sessionInfo_figures.txt"))
