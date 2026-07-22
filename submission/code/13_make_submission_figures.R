rm(list = ls())
source("outputs/SIC_reanalysis_2026-07-11/code/00_config.R")
suppressPackageStartupMessages({
  library(data.table); library(dplyr); library(tidyr); library(stringr)
  library(ggplot2); library(patchwork); library(svglite); library(ragg)
})

CLOSEOUT <- file.path(PROJECT_DIR, "submission")
FIG <- file.path(CLOSEOUT, "figures")
SD <- file.path(CLOSEOUT, "public_source_data")
dir.create(FIG, recursive = TRUE, showWarnings = FALSE)
dir.create(SD, recursive = TRUE, showWarnings = FALSE)
truth <- fread(file.path(CLOSEOUT, "numeric_truth_table.tsv"), na.strings = "")
stopifnot(!anyDuplicated(truth$key))

PAL <- c(risk = "#B94C43", protective = "#3D73A6", neutral = "#B7B7B7", RNA = "#3A78A8",
         Protein = "#C77B30", purple = "#74649A", teal = "#3C938B", zero = "#8C8C8C",
         all = "#4A8C6F", partial = "#D5963F")

theme_pub <- function(base_size = 7, base_family = "sans") {
  theme_classic(base_size = base_size, base_family = base_family) +
    theme(
      axis.line = element_line(linewidth = .35, colour = "black"),
      axis.ticks = element_line(linewidth = .35, colour = "black"),
      axis.title = element_text(size = base_size), axis.text = element_text(size = base_size - .5),
      legend.title = element_text(size = base_size - .3), legend.text = element_text(size = base_size - .7),
      strip.background = element_blank(), strip.text = element_text(size = base_size - .2, face = "bold"),
      plot.title = element_text(size = base_size + .5, face = "bold"),
      plot.tag = element_text(size = 8, face = "bold"), panel.grid = element_blank(),
      axis.title.x = element_text(margin = margin(t = 4)),
      axis.title.y = element_text(margin = margin(r = 4)),
      plot.margin = margin(6, 9, 10, 9)
    )
}
theme_set(theme_pub())

save_bundle <- function(plot, stem, width_mm, height_mm, dpi = 600) {
  w <- width_mm / 25.4; h <- height_mm / 25.4
  svglite::svglite(paste0(stem, ".svg"), width = w, height = h, bg = "white")
  print(plot); dev.off()
  grDevices::cairo_pdf(paste0(stem, ".pdf"), width = w, height = h, family = "sans", bg = "white")
  print(plot); dev.off()
  ragg::agg_tiff(paste0(stem, ".tiff"), width = w, height = h, units = "in", res = dpi, compression = "lzw")
  print(plot); dev.off()
  ragg::agg_png(paste0(stem, ".png"), width = w, height = h, units = "in", res = dpi, background = "white")
  print(plot); dev.off()
}

truth_num <- function(k) {
  x <- truth[key == k, value_num]
  if (length(x) != 1L || !is.finite(x)) stop("Missing/non-finite truth key: ", k)
  x
}
stars <- function(x) fifelse(x < .001, "***", fifelse(x < .01, "**", fifelse(x < .05, "*", "")))
pathway_display <- function(x) {
  labels <- c(
    TNFA_SIGNALING_VIA_NFKB = "TNF-α signaling via NF-κB",
    IL6_JAK_STAT3_SIGNALING = "IL-6/JAK/STAT3 signaling",
    MYC_TARGETS_V1 = "MYC targets V1",
    MYC_TARGETS_V2 = "MYC targets V2",
    E2F_TARGETS = "E2F targets",
    DNA_REPAIR = "DNA repair",
    MTORC1_SIGNALING = "mTORC1 signaling",
    INTERFERON_ALPHA_RESPONSE = "IFN-α response",
    INTERFERON_GAMMA_RESPONSE = "IFN-γ response",
    REACTIVE_OXYGEN_SPECIES_PATHWAY = "Reactive oxygen species pathway",
    OXIDATIVE_PHOSPHORYLATION = "Oxidative phosphorylation",
    EPITHELIAL_MESENCHYMAL_TRANSITION = "Epithelial–mesenchymal transition"
  )
  out <- unname(labels[x])
  missing <- is.na(out)
  out[missing] <- str_to_sentence(str_replace_all(x[missing], "_", " "))
  out
}
pretty_path <- pathway_display
scenario_display <- function(x) {
  recode(x,
    "primary__SOFA_D3" = "Primary entry | baseline SOFA + prior D3 RNA availability",
    "primary__SOFA_noD3" = "Primary entry | baseline SOFA",
    "primary__PF_PLT_D3" = "Primary entry | P/F + PLT + prior D3 RNA availability",
    "primary__PF_PLT_noD3" = "Primary entry | P/F + PLT",
    "lower__SOFA_D3" = "Lower entry boundary | baseline SOFA + prior D3 RNA availability",
    "upper__SOFA_D3" = "Upper entry boundary | baseline SOFA + prior D3 RNA availability",
    "entry4_SOFA_D3" = "Primary entry | baseline SOFA + prior D3 RNA availability",
    "entry4_SOFA_noD3" = "Primary entry | baseline SOFA",
    "entry4_PF_PLT_D3" = "Primary entry | P/F + PLT + prior D3 RNA availability",
    "entry4_PF_PLT_noD3" = "Primary entry | P/F + PLT",
    "entry3.75_SOFA_D3" = "Lower entry boundary | baseline SOFA + prior D3 RNA availability",
    "entry4.25_SOFA_D3" = "Upper entry boundary | baseline SOFA + prior D3 RNA availability",
    .default = x
  )
}
scenario_display_axis <- function(x) {
  scenario_display(x) |>
    str_replace(" \\| ", "\n") |>
    str_replace(" \\+ prior D3 RNA availability$", "\n+ prior D3 RNA availability")
}

parse_truth_wide <- function(domain_name, id_expr) {
  d <- copy(truth[domain == domain_name])
  d[, id := eval(parse(text = id_expr))]
  dcast(d, id ~ source_field, value.var = "value_num")
}

# ---- Figure 1: cohort and availability hierarchy ---------------------------
fig1_samples <- truth[domain == "figure1_samples"]
fig1_samples[, c("prefix", "Omics", "Time", "metric") := tstrsplit(key, "\\.", fixed = FALSE)]
fig1_wide <- dcast(fig1_samples, Omics + Time ~ metric, value.var = "value_num")
fig1_wide[, Time := factor(Time, levels = c("D1", "D3", "D5"))]
fig1_long <- melt(fig1_wide, id.vars = c("Omics", "Time"), measure.vars = c("matched_n", "risk_valid_n"),
                  variable.name = "sample_level", value.name = "N")
fig1_long[, sample_level := factor(sample_level, levels = c("matched_n", "risk_valid_n"), labels = c("Raw measured", "Delayed-entry risk-valid"))]
p1a_nodes <- data.table(
  x = 1:4, y = 1,
  label = c(
    paste0("Day-1 SIC cohort\nN = ", truth_num("availability.primary.source_N")),
    "Longitudinal molecular\nsampling",
    "Delayed-entry risk sets\nD1 / D3 / D5",
    "Subsequent mortality\nthrough day 60"
  )
)
p1a <- ggplot(p1a_nodes, aes(x, y)) +
  geom_label(aes(label = label), fill = "white", linewidth = .35, size = 2.35, lineheight = .95,
             label.padding = grid::unit(.18, "lines")) +
  geom_segment(data = data.table(x = c(1.35, 2.35, 3.35), xend = c(1.65, 2.65, 3.65), y = 1, yend = 1),
               aes(x = x, xend = xend, y = y, yend = yend), arrow = arrow(length = grid::unit(1.8, "mm")), linewidth = .4) +
  coord_cartesian(xlim = c(.48, 4.52), ylim = c(.65, 1.35), clip = "off") + theme_void()

p1b <- ggplot(fig1_long, aes(Time, N, fill = sample_level)) +
  geom_col(position = position_dodge(.72), width = .62) +
  geom_text(aes(y = N * ifelse(sample_level == "Raw measured", 1.035, 1.105),
                label = as.integer(N)), position = position_dodge(.72),
            vjust = -.35, size = 1.85, colour = "black") +
  facet_wrap(~Omics, scales = "free_y") +
  scale_fill_manual(values = c("Raw measured" = "#9AB8CF", "Delayed-entry risk-valid" = unname(PAL["RNA"]))) +
  scale_y_continuous(expand = expansion(mult = c(0, .16))) +
  labs(x = NULL, y = NULL, fill = NULL, title = "Measured versus risk-valid molecular samples") +
  theme_pub(6.7) + theme(legend.position = "top")

d5 <- data.table(
  stage = factor(c("D5 landmark survivors", "Positivity-supported estimand", "Observed D5 RNA", "Unobserved D5 RNA"),
                 levels = rev(c("D5 landmark survivors", "Positivity-supported estimand", "Observed D5 RNA", "Unobserved D5 RNA"))),
  N = c(truth_num("availability.primary.risk_N"), truth_num("availability.primary.support_N"),
        truth_num("availability.primary.observed_N"), truth_num("availability.primary.unobserved_N")),
  type = c("Landmark", "Estimand", "Observed", "Unobserved")
)
p1c <- ggplot(d5, aes(N, stage, fill = type)) +
  geom_col(width = .62) + geom_text(aes(label = as.integer(N)), hjust = -.2, size = 2.5) +
  scale_fill_manual(values = c(Landmark = "#D3D3D3", Estimand = unname(PAL["purple"]), Observed = unname(PAL["RNA"]), Unobserved = "#E0A25B")) +
  scale_x_continuous(expand = expansion(mult = c(0, .14))) +
  labs(x = "Patients", y = NULL, fill = NULL, title = "Day-5 availability hierarchy") +
  theme_pub(6.7) + theme(legend.position = "none")

d5_excl <- data.table(
  category = c("Structural deaths at/before entry", "Patients from zero-observation centres"),
  N = c(truth_num("availability.primary.structural_N"),
        truth_num("availability.primary.risk_N") - truth_num("availability.primary.support_N"))
)
centre_class <- data.table(
  class = c("Zero-observation", "All-observation", "Partial-observation"),
  centres = c(truth_num("availability.primary.centres_zero"), truth_num("availability.primary.centres_all"), truth_num("availability.primary.centres_partial"))
)
p1d_left <- ggplot(d5_excl, aes(N, reorder(category, N), fill = category)) +
  geom_col(width = .6) + geom_text(aes(label = as.integer(N)), hjust = -.2, size = 2.3) +
  scale_fill_manual(values = c("Structural deaths at/before entry" = "#A6A6A6", "Patients from zero-observation centres" = unname(PAL["zero"]))) +
  scale_x_continuous(expand = expansion(mult = c(0, .25))) + theme_pub(6.2) +
  labs(x = "Patients", y = NULL, title = "Excluded from D5 IPW estimand") + theme(legend.position = "none")
p1d_right <- ggplot(centre_class, aes(class, centres, fill = class)) +
  geom_col(width = .62) + geom_text(aes(label = as.integer(centres)), vjust = -.25, size = 2.3) +
  scale_fill_manual(values = c("Zero-observation" = unname(PAL["zero"]), "All-observation" = unname(PAL["all"]), "Partial-observation" = unname(PAL["partial"]))) +
  scale_y_continuous(expand = expansion(mult = c(0, .18))) + theme_pub(6.2) +
  labs(x = NULL, y = "Centres", title = "Empirical centre positivity") +
  theme(axis.text.x = element_text(angle = 30, hjust = 1), legend.position = "none")
p1d <- p1d_left | p1d_right

fig1_middle <- (p1b | p1c) + plot_layout(widths = c(1.1, 1))
fig1 <- p1a / fig1_middle / p1d + plot_layout(heights = c(.72, 1.25, 1.05)) +
  plot_annotation(
    tag_levels = "a",
    title = "Figure 1 | Study design, longitudinal risk sets and Day-5 availability estimand",
    theme = theme(plot.title = element_text(size = 10, face = "bold", hjust = 0))
  )
save_bundle(fig1, file.path(FIG, "Figure1_study_design_risksets_availability"), 183, 185)
fwrite(fig1_long, file.path(SD, "SourceData_Figure1_samples.tsv"), sep = "\t")
fwrite(d5, file.path(SD, "SourceData_Figure1_D5_availability.tsv"), sep = "\t")
fwrite(d5_excl, file.path(SD, "SourceData_Figure1_exclusions.tsv"), sep = "\t")
fwrite(centre_class, file.path(SD, "SourceData_Figure1_centre_classes.tsv"), sep = "\t")

# ---- Figures 2 and 3: frozen pathway results from truth ---------------------
core_rna <- c("HEME_METABOLISM", "HYPOXIA", "REACTIVE_OXYGEN_SPECIES_PATHWAY", "GLYCOLYSIS", "OXIDATIVE_PHOSPHORYLATION",
              "TNFA_SIGNALING_VIA_NFKB", "IL6_JAK_STAT3_SIGNALING", "INFLAMMATORY_RESPONSE", "INTERFERON_ALPHA_RESPONSE",
              "INTERFERON_GAMMA_RESPONSE", "COMPLEMENT", "COAGULATION", "EPITHELIAL_MESENCHYMAL_TRANSITION", "APICAL_JUNCTION",
              "MYC_TARGETS_V1", "UNFOLDED_PROTEIN_RESPONSE", "E2F_TARGETS", "DNA_REPAIR")
rna_t <- copy(truth[domain == "rna_pathway"])
rna_t[, c("prefix", "Time", "pathway", "metric") := tstrsplit(key, "\\.")]
rna_w <- dcast(rna_t, Time + pathway ~ metric, value.var = "value_num")[pathway %in% core_rna]
rna_w[, `:=`(label = paste0(sprintf("%.2f", NES_TMM_Primary), stars(padj_TMM_Primary)),
             pathway_label = factor(pretty_path(pathway), levels = rev(pretty_path(core_rna))))]
p2 <- ggplot(rna_w, aes(Time, pathway_label, fill = NES_TMM_Primary)) +
  geom_tile(colour = "white", linewidth = .4) + geom_text(aes(label = label), size = 2.25) +
  scale_fill_gradient2(low = PAL["protective"], mid = "white", high = PAL["risk"], midpoint = 0) +
  labs(x = NULL, y = NULL, fill = "Mortality-association\nNES",
       title = "Figure 2 | Time-specific whole-blood transcriptomic prognostic programmes") +
  theme_pub(7) + theme(plot.title = element_text(size = 10, face = "bold", hjust = 0))
unlink(file.path(FIG, paste0("Figure2_RNA_core_NES_robustness.", c("pdf", "svg", "tiff", "png"))))
save_bundle(p2, file.path(FIG, "Figure2_RNA_core_NES"), 183, 132)
fwrite(rna_w, file.path(SD, "SourceData_Figure2_RNA.tsv"), sep = "\t")

core_protein <- c("HYPOXIA", "GLYCOLYSIS", "FATTY_ACID_METABOLISM", "OXIDATIVE_PHOSPHORYLATION", "MYC_TARGETS_V1",
                  "MTORC1_SIGNALING", "PROTEIN_SECRETION", "COMPLEMENT", "EPITHELIAL_MESENCHYMAL_TRANSITION",
                  "MYOGENESIS", "G2M_CHECKPOINT", "DNA_REPAIR")
prot_t <- copy(truth[domain == "protein_pathway"])
prot_t[, c("prefix", "analysis", "pathway", "metric") := tstrsplit(key, "\\.")]
prot_w <- dcast(prot_t, analysis + pathway ~ metric, value.var = "value_num")
prot_w[, Time := str_extract(analysis, "^D[135]")]
prot_main <- prot_w[grepl("center_primary$", analysis) & pathway %in% core_protein]
prot_main[, `:=`(label = paste0(sprintf("%.2f", NES), stars(padj)),
                 pathway_label = factor(pretty_path(pathway), levels = rev(pretty_path(core_protein))))]
p3 <- ggplot(prot_main, aes(Time, pathway_label, fill = NES)) +
  geom_tile(colour = "white", linewidth = .4) + geom_text(aes(label = label), size = 2.25) +
  scale_fill_gradient2(low = PAL["protective"], mid = "white", high = PAL["risk"], midpoint = 0) +
  labs(x = NULL, y = NULL, fill = "Mortality-association\nNES",
       title = "Figure 3 | Time-specific plasma-protein prognostic programmes") +
  theme_pub(7) + theme(plot.title = element_text(size = 10, face = "bold", hjust = 0))
unlink(file.path(FIG, paste0("Figure3_Protein_core_NES_robustness.", c("pdf", "svg", "tiff", "png"))))
save_bundle(p3, file.path(FIG, "Figure3_Protein_core_NES"), 183, 112)
fwrite(prot_main, file.path(SD, "SourceData_Figure3_Protein.tsv"), sep = "\t")

# ---- Figure 4: six-panel cross-omics synthesis -----------------------------
short_ids <- c("TNFA_SIGNALING_VIA_NFKB", "IL6_JAK_STAT3_SIGNALING", "INFLAMMATORY_RESPONSE",
               "INTERFERON_ALPHA_RESPONSE", "INTERFERON_GAMMA_RESPONSE", "COAGULATION", "COMPLEMENT",
               "HEME_METABOLISM", "EPITHELIAL_MESENCHYMAL_TRANSITION", "TGF_BETA_SIGNALING",
               "APICAL_JUNCTION", "HYPOXIA", "OXIDATIVE_PHOSPHORYLATION",
               "REACTIVE_OXYGEN_SPECIES_PATHWAY", "GLYCOLYSIS")
short <- setNames(pathway_display(short_ids), short_ids)

same_t <- copy(truth[domain == "cross_same_time"])
same_t[, pair := sub("^Time/pathway=", "", filter)]
same_t[, c("Time", "Pathway") := tstrsplit(pair, "/", fixed = TRUE)]
same_w <- dcast(same_t, Time + Pathway ~ source_field, value.var = "value_num")
same_w[, Pathway_label := factor(unname(short[Pathway]), levels = rev(unname(short)))]
same_w[, label := paste0(sprintf("%.2f", partial_rho), stars(FDR))]
p4a <- ggplot(same_w, aes(Time, Pathway_label, fill = partial_rho)) +
  geom_tile(colour = "white", linewidth = .3) + geom_text(aes(label = label), size = 1.7) +
  scale_fill_gradient2(low = PAL["protective"], mid = "white", high = PAL["risk"], midpoint = 0) +
  labs(x = NULL, y = NULL, fill = "Partial rho", title = "Same-time RNA-protein associations") + theme_pub(5.9)

cross_long <- function(domain_name) {
  z <- copy(truth[domain == domain_name])
  z[, pair := sub("^Direction/pathway=", "", filter)]
  z[, Direction := sub("/[^/]+$", "", pair)]
  z[, Pathway := sub("^.*/", "", pair)]
  dcast(z, Direction + Pathway ~ source_field, value.var = "value_num")
}
forward <- cross_long("cross_forward")
reverse <- cross_long("cross_reverse")
forward[, Pathway_label := factor(unname(short[Pathway]), levels = rev(unname(short)))]
reverse[, Pathway_label := factor(unname(short[Pathway]), levels = rev(unname(short)))]

make_forward_panel <- function(direction, title) {
  x <- forward[Direction == direction]
  ggplot(x, aes(beta, Pathway_label, colour = FDR < .05)) +
    geom_vline(xintercept = 0, linetype = 2, linewidth = .3, colour = "grey55") +
    geom_errorbar(aes(xmin = lower95, xmax = upper95), orientation = "y", width = .12, linewidth = .35) + geom_point(size = 1.55) +
    scale_colour_manual(values = c(`TRUE` = unname(PAL["risk"]), `FALSE` = "#777777")) +
    labs(x = "Adjusted beta (95% CI)", y = NULL, colour = "FDR < 0.05", title = title) +
    theme_pub(5.8) + theme(legend.position = "none")
}
p4b <- make_forward_panel("RNA D1 to Protein D3", "RNA D1 to Protein D3")
p4c <- make_forward_panel("RNA D3 to Protein D5", "RNA D3 to Protein D5")

reverse[, interval := factor(Direction, levels = c("Protein D1 to RNA D3", "Protein D3 to RNA D5"), labels = c("D1 to D3", "D3 to D5"))]
reverse[, label := paste0(sprintf("%.2f", beta), stars(FDR))]
p4d <- ggplot(reverse, aes(interval, Pathway_label, fill = beta)) +
  geom_tile(colour = "white", linewidth = .3) + geom_text(aes(label = label), size = 1.65) +
  scale_fill_gradient2(low = PAL["protective"], mid = "white", high = PAL["risk"], midpoint = 0) +
  labs(x = NULL, y = NULL, fill = "Adjusted beta", title = "Reverse Protein-to-RNA models") + theme_pub(5.8)

ox <- copy(truth[domain == "cross_oxphos_attenuation"])
ox_same <- ox[grepl("cross.oxphos.same", key)]
ox_same[, association := paste0("Same-time ", sub("^Time=", "", filter))]
ox_same[, model := fifelse(grepl("Original", source_field), "Before centre adjustment", "After centre adjustment")]
ox_same[, metric := fifelse(grepl("rho", source_field), "effect", "FDR")]
ox_cross <- ox[grepl("cross.oxphos.crosslag", key)]
ox_cross[, association := str_replace_all(sub("^Direction=", "", filter), "RNA |Protein ", "")]
ox_cross[, model := fifelse(grepl("Original", source_field), "Before centre adjustment", "After centre adjustment")]
ox_cross[, metric := fifelse(grepl("beta", source_field), "effect", "FDR")]
ox_plot <- rbind(ox_same, ox_cross, fill = TRUE)[metric == "effect", .(association, model, effect = value_num)]
ox_plot[, model := factor(model, levels = c("Before centre adjustment", "After centre adjustment"))]
p4e <- ggplot(ox_plot, aes(model, effect, group = association, colour = association)) +
  geom_hline(yintercept = 0, linewidth = .3, colour = "grey65") + geom_line(linewidth = .45) + geom_point(size = 1.7) +
  scale_colour_brewer(palette = "Dark2") +
  labs(x = NULL, y = "OXPHOS association", colour = NULL, title = "OXPHOS attenuation after centre adjustment") +
  theme_pub(5.8) + theme(axis.text.x = element_text(angle = 25, hjust = 1), legend.position = "bottom")

ifn <- forward[Pathway %in% c("INTERFERON_ALPHA_RESPONSE", "INTERFERON_GAMMA_RESPONSE")]
ifn[, label := paste(unname(short[Pathway]), str_replace_all(Direction, c("RNA " = "", "Protein " = "", " to " = " to ")), sep = " | ")]
p4f <- ggplot(ifn, aes(beta, reorder(label, beta), colour = Pathway)) +
  geom_vline(xintercept = 0, linetype = 2, linewidth = .3, colour = "grey55") +
  geom_errorbar(aes(xmin = lower95, xmax = upper95), orientation = "y", width = .14, linewidth = .45) + geom_point(size = 1.9) +
  scale_colour_manual(values = c(INTERFERON_ALPHA_RESPONSE = unname(PAL["RNA"]), INTERFERON_GAMMA_RESPONSE = unname(PAL["purple"]))) +
  labs(x = "Adjusted beta (95% CI)", y = NULL, colour = NULL, title = "Interferon effect estimates") + theme_pub(5.8) + theme(legend.position = "none")

panel_tag_theme <- theme(
  plot.tag = element_text(size = 8, face = "bold", colour = "black"),
  plot.tag.position = c(.01, .99)
)
p4a <- p4a + labs(tag = "a") + panel_tag_theme
p4b <- p4b + labs(tag = "b") + panel_tag_theme
p4c <- p4c + labs(tag = "c") + panel_tag_theme
p4d <- p4d + labs(tag = "d") + panel_tag_theme
p4e <- p4e + labs(tag = "e") + panel_tag_theme
p4f <- p4f + labs(tag = "f") + panel_tag_theme

fig4 <- (p4a | p4d) / (p4b | p4c) / (p4e | p4f) +
  plot_layout(heights = c(1.18, 1.18, .82), widths = c(1, 1)) +
  plot_annotation(
    title = "Pathway-selective contemporaneous and forward cross-omic associations",
    theme = theme(plot.title = element_text(size = 10, face = "bold", hjust = 0))
  )
save_bundle(fig4, file.path(FIG, "Figure4_CrossOmics_integrated_A_to_F"), 183, 225)

# Readability review exports retain all six panels and identical data. Layout changes
# are permitted to prevent axis/text clipping at narrower journal widths.
p4e_single <- p4e + guides(colour = guide_legend(ncol = 1, byrow = TRUE)) +
  theme(legend.position = "bottom", legend.text = element_text(size = 4.8))
fig4_single <- (p4a / p4b / p4c / p4d / p4e_single / p4f) +
  plot_annotation(title = "Pathway-selective contemporaneous and forward\ncross-omic associations")
fig4_double <- ((p4a | p4d) / (p4b | p4c) / (p4e | p4f)) +
  plot_annotation(title = "Pathway-selective contemporaneous and forward cross-omic associations")
review_plots <- list(single_column = fig4_single, double_column = fig4_double, full_page = fig4)
review_sizes <- list(single_column = c(89, 440), double_column = c(183, 285), full_page = c(183, 225))
review_dir <- file.path(PROJECT_DIR, "private_audit", "figure4_readability_review")
dir.create(review_dir, recursive = TRUE, showWarnings = FALSE)
for (nm in names(review_sizes)) {
  dims <- review_sizes[[nm]]; review_plot <- review_plots[[nm]]
  grDevices::cairo_pdf(file.path(review_dir, paste0("Figure4_review_", nm, ".pdf")), width = dims[1] / 25.4, height = dims[2] / 25.4, family = "sans")
  print(review_plot); dev.off()
  ragg::agg_png(file.path(review_dir, paste0("Figure4_review_", nm, ".png")), width = dims[1] / 25.4, height = dims[2] / 25.4,
                units = "in", res = 300, background = "white")
  print(review_plot); dev.off()
}
fwrite(same_w, file.path(SD, "SourceData_Figure4A_same_time.tsv"), sep = "\t")
fwrite(forward[Direction == "RNA D1 to Protein D3"], file.path(SD, "SourceData_Figure4B_forward_D1_D3.tsv"), sep = "\t")
fwrite(forward[Direction == "RNA D3 to Protein D5"], file.path(SD, "SourceData_Figure4C_forward_D3_D5.tsv"), sep = "\t")
fwrite(reverse, file.path(SD, "SourceData_Figure4D_reverse.tsv"), sep = "\t")
fwrite(ox_plot, file.path(SD, "SourceData_Figure4E_OXPHOS_attenuation.tsv"), sep = "\t")
fwrite(ifn, file.path(SD, "SourceData_Figure4F_IFN_effects.tsv"), sep = "\t")

# ---- Availability supplementary figures -----------------------------------
# A1 centre-level positivity
centre_t <- copy(truth[domain == "centre_positivity" & grepl("availability.centre.primary", key)])
centre_t[, c("a", "b", "entry", "center", "metric") := tstrsplit(key, "\\.")]
centre_num <- dcast(centre_t[source_field %in% c("N", "observed", "unobserved")], center ~ source_field, value.var = "value_num")
centre_class_t <- centre_t[source_field == "class", .(center, class = value_text)]
centre_plot <- merge(centre_num, centre_class_t, by = "center")
centre_long <- melt(centre_plot, id.vars = c("center", "class"), measure.vars = c("observed", "unobserved"), variable.name = "availability", value.name = "N")
centre_long[, center := factor(center, levels = centre_plot[order(class, -N), center])]
pA1 <- ggplot(centre_long, aes(center, N, fill = availability)) +
  geom_col(width = .78) + facet_grid(~class, scales = "free_x", space = "free_x") +
  scale_fill_manual(values = c(observed = unname(PAL["RNA"]), unobserved = "#E2A458")) +
  labs(x = NULL, y = "D5 landmark survivors", fill = NULL, title = "Centre-level D5 RNA positivity support") +
  theme_pub(6.5) + theme(axis.text.x = element_text(angle = 60, hjust = 1), legend.position = "top")
save_bundle(pA1, file.path(FIG, "Supplementary_Figure_A1_centre_positivity"), 183, 105)
fwrite(centre_long, file.path(SD, "SourceData_Supplementary_Figure_A1.tsv"), sep = "\t")

# A2 aggregate probability and weight distributions
dist_t <- copy(truth[domain == "availability_distribution"])
dist_t[, c("a", "b", "scenario", "measure", "bin", "metric") := tstrsplit(key, "\\.")]
dist_w <- dcast(dist_t, scenario + measure + bin ~ metric, value.var = "value_num")
dist_w[, scenario_label := scenario_display(scenario)]
pA2 <- ggplot(dist_w, aes(mid, count, colour = scenario_label, group = scenario_label)) +
  geom_line(linewidth = .55) + facet_wrap(~measure, scales = "free_x", ncol = 1) +
  labs(x = NULL, y = "Aggregate patient count", colour = "Prespecified scenario", title = "Observation-probability and analysis-weight distributions") +
  theme_pub(6.5) + theme(legend.position = "bottom")
save_bundle(pA2, file.path(FIG, "Supplementary_Figure_A2_probability_weight_distributions"), 183, 125)
fwrite(dist_w, file.path(SD, "SourceData_Supplementary_Figure_A2.tsv"), sep = "\t")

# A3 SMD love plot across all six scenarios
smd_t <- copy(truth[domain == "availability_balance"])
smd_t[, variable := sub("^.*/", "", filter)]
smd_t[, scenario := paste(str_match(key, "^availability\\.smd\\.([^.]+)\\.([^.]+)")[,2], str_match(key, "^availability\\.smd\\.([^.]+)\\.([^.]+)")[,3], sep = "__")]
smd_t[, scenario_label := scenario_display(scenario)]
smd_t[, stage := fifelse(source_field == "SMD_before", "Before weighting", "After weighting")]
pA3 <- ggplot(smd_t, aes(value_num, reorder(variable, abs(value_num)), colour = stage)) +
  geom_vline(xintercept = c(-.1, .1), linetype = 2, linewidth = .3, colour = "grey55") + geom_point(size = 1.25, alpha = .85) +
  facet_wrap(~scenario_label, ncol = 2) + scale_colour_manual(values = c("Before weighting" = "#8A8A8A", "After weighting" = unname(PAL["risk"]))) +
  labs(x = "Standardized mean difference", y = NULL, colour = NULL, title = "Covariate balance across all prespecified scenarios") +
  theme_pub(5.6) + theme(legend.position = "top")
save_bundle(pA3, file.path(FIG, "Supplementary_Figure_A3_pre_post_weight_SMD"), 183, 230)
fwrite(smd_t[, .(scenario, variable, stage, SMD = value_num)], file.path(SD, "SourceData_Supplementary_Figure_A3.tsv"), sep = "\t")

# A4 all-Hallmark unweighted versus IPW
cmp_t <- copy(truth[domain == "availability_pathway_comparison"])
cmp_t[, pair := sub("^scenario/pathway=", "", filter)]
cmp_t[, scenario := sub("/[^/]+$", "", pair)]
cmp_t[, pathway := sub("^.*/", "", pair)]
cmp_num <- dcast(cmp_t[is.finite(value_num)], scenario + pathway ~ source_field, value.var = "value_num")
cmp_text <- dcast(cmp_t[!is.na(value_text)], scenario + pathway ~ source_field, value.var = "value_text")
cmp_w <- merge(cmp_num, cmp_text[, .(scenario, pathway, FDR_class)], by = c("scenario", "pathway"), all = TRUE)
cmp_w[, scenario_label := scenario_display(scenario)]
pA4 <- ggplot(cmp_w, aes(NES_unweighted, NES_weighted, colour = FDR_class)) +
  geom_hline(yintercept = 0, colour = "grey85") + geom_vline(xintercept = 0, colour = "grey85") +
  geom_abline(slope = 1, intercept = 0, linetype = 2, linewidth = .35) + geom_point(size = 1.2, alpha = .8) +
  facet_wrap(~scenario_label, ncol = 3) + coord_equal() +
  scale_colour_manual(values = c(both = unname(PAL["risk"]), unweighted_only = "#E9A36A", IPW_only = unname(PAL["protective"]), neither = "#B8B8B8")) +
  labs(x = "Unweighted NES", y = "IPW NES", colour = "FDR class", title = "All-Hallmark concordance across prespecified IPW scenarios") +
  theme_pub(6) + theme(legend.position = "bottom")
save_bundle(pA4, file.path(FIG, "Supplementary_Figure_A4_all_Hallmark_unweighted_vs_IPW"), 183, 130)
fwrite(cmp_w, file.path(SD, "SourceData_Supplementary_Figure_A4.tsv"), sep = "\t")

# A5 core-pathway scenario heatmap
g_t <- copy(truth[domain == "availability_hallmark"])
g_t[, pair := sub("^analysis/pathway=", "", filter)]
g_t[, analysis := sub("/[^/]+$", "", pair)]
g_t[, pathway := sub("^.*/", "", pair)]
g_w <- dcast(g_t, analysis + pathway ~ source_field, value.var = "value_num")
scenario_analyses <- c("entry4_SOFA_D3__all_valid", "entry4_SOFA_noD3__all_valid", "entry4_PF_PLT_D3__all_valid",
                       "entry4_PF_PLT_noD3__all_valid", "entry3.75_SOFA_D3__all_valid", "entry4.25_SOFA_D3__all_valid")
g_core <- g_w[analysis %in% scenario_analyses & pathway %in% core_rna]
g_core[, analysis_label := scenario_display_axis(sub("__all_valid$", "", analysis))]
g_core[, pathway_label := factor(pretty_path(pathway), levels = rev(pretty_path(core_rna)))]
pA5 <- ggplot(g_core, aes(analysis_label, pathway_label, fill = NES)) +
  geom_tile(colour = "white", linewidth = .25) + geom_text(aes(label = sprintf("%.2f", NES)), size = 1.75) +
  scale_fill_gradient2(low = PAL["protective"], mid = "white", high = PAL["risk"], midpoint = 0) +
  labs(x = NULL, y = NULL, fill = "NES", title = "Core pathways across all prespecified IPW scenarios") +
  theme_pub(5.8) + theme(axis.text.x = element_text(angle = 0, hjust = .5, vjust = 1, lineheight = .95),
                         plot.margin = margin(6, 9, 15, 9))
save_bundle(pA5, file.path(FIG, "Supplementary_Figure_A5_core_pathway_scenario_heatmap"), 183, 155)
fwrite(g_core, file.path(SD, "SourceData_Supplementary_Figure_A5.tsv"), sep = "\t")

# A6 six-scenario robustness metrics
metric_t <- copy(truth[domain == "availability_hallmark_comparison"])
metric_t[, scenario := sub("^scenario=", "", filter)]
metric_plot <- metric_t[, .(scenario, metric = source_field, value = value_num)]
metric_plot[, scenario_label := scenario_display_axis(scenario)]
pA6 <- ggplot(metric_plot, aes(scenario_label, value, fill = metric)) +
  geom_col(position = position_dodge(.7), width = .64) +
  scale_y_continuous(limits = c(0, 1), expand = expansion(mult = c(0, .04))) +
  labs(x = NULL, y = "Agreement metric", fill = NULL, title = "Six-scenario pathway-level robustness") +
  theme_pub(6.1) + theme(axis.text.x = element_text(angle = 0, hjust = .5, vjust = 1, lineheight = .95),
                         legend.position = "top", plot.margin = margin(6, 9, 18, 9))
save_bundle(pA6, file.path(FIG, "Supplementary_Figure_A6_six_scenario_robustness_metrics"), 183, 115)
fwrite(metric_plot, file.path(SD, "SourceData_Supplementary_Figure_A6.tsv"), sep = "\t")

# A7 entry-boundary sensitivity
entry_analyses <- c("entry3.75_SOFA_D3__all_valid", "entry4_SOFA_D3__all_valid", "entry4.25_SOFA_D3__all_valid")
entry_core <- g_w[analysis %in% entry_analyses & pathway %in% core_rna]
entry_core[, analysis_label := scenario_display_axis(sub("__all_valid$", "", analysis))]
entry_core[, pathway_label := factor(pretty_path(pathway), levels = rev(pretty_path(core_rna)))]
pA7 <- ggplot(entry_core, aes(analysis_label, pathway_label, fill = NES)) +
  geom_tile(colour = "white", linewidth = .3) + geom_text(aes(label = sprintf("%.2f", NES)), size = 2) +
  scale_fill_gradient2(low = PAL["protective"], mid = "white", high = PAL["risk"], midpoint = 0) +
  labs(x = NULL, y = NULL, fill = "NES", title = "D5 entry-boundary sensitivity") + theme_pub(6.2) +
  theme(axis.text.x = element_text(angle = 0, hjust = .5, vjust = 1, lineheight = .95),
        plot.margin = margin(6, 9, 27, 9))
save_bundle(pA7, file.path(FIG, "Supplementary_Figure_A7_entry_boundary_sensitivity"), 150, 155)
fwrite(entry_core, file.path(SD, "SourceData_Supplementary_Figure_A7.tsv"), sep = "\t")

# A8 descriptive D5 protein availability
protein_samples <- fig1_wide[Omics == "Protein"]
protein_long <- melt(protein_samples, id.vars = c("Omics", "Time"), measure.vars = c("matched_n", "risk_valid_n"),
                     variable.name = "level", value.name = "N")
protein_long[, level := factor(level, levels = c("matched_n", "risk_valid_n"), labels = c("Raw measured", "Delayed-entry risk-valid"))]
pA8 <- ggplot(protein_long, aes(Time, N, fill = level)) +
  geom_col(position = position_dodge(.72), width = .62) + geom_text(aes(label = as.integer(N)), position = position_dodge(.82), vjust = -.25, size = 2) +
  scale_fill_manual(values = c("Raw measured" = "#E1B485", "Delayed-entry risk-valid" = unname(PAL["Protein"]))) +
  scale_y_continuous(expand = expansion(mult = c(0, .16))) +
  labs(x = NULL, y = "Patients", fill = NULL, title = "Descriptive plasma-protein sample availability") + theme_pub(6.7) + theme(legend.position = "top")
save_bundle(pA8, file.path(FIG, "Supplementary_Figure_A8_D5_protein_availability"), 120, 90)
fwrite(protein_long, file.path(SD, "SourceData_Supplementary_Figure_A8.tsv"), sep = "\t")

writeLines(capture.output(sessionInfo()), file.path(CLOSEOUT, "sessionInfo_closeout_figures.txt"))
cat("Four main figures and eight availability supplementary figures exported.\n")
