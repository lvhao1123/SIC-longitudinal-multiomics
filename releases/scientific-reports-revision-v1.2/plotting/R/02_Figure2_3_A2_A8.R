
set.seed(20260904)
analysis_library <- Sys.getenv("SIC_R_LIBRARY", unset = "")
if (nzchar(analysis_library)) .libPaths(c(analysis_library, .libPaths()))
suppressPackageStartupMessages({
  library(data.table); library(dplyr); library(tidyr); library(stringr)
  library(ggplot2); library(patchwork); library(svglite); library(ragg)
})

args <- commandArgs(trailingOnly = TRUE)
arg_value <- function(flag, env, default) {
  hit <- which(args == flag)
  if (length(hit) && hit[1] < length(args)) return(args[hit[1] + 1L])
  Sys.getenv(env, unset = default)
}
PROJECT_DIR <- normalizePath(arg_value("--project", "SIC_PROJECT_DIR", getwd()), mustWork = TRUE)
CLOSEOUT <- file.path(PROJECT_DIR, "submission")
STAGE <- normalizePath(arg_value("--output", "SIC_FIGURE_OUTPUT", getwd()), mustWork = TRUE)
FIG <- file.path(STAGE, "figures")
SD <- file.path(Sys.getenv("SIC_R7_BASE"), "figure_source_data")
# The source-data snapshot is immutable. Retain display derivations separately.
audit_source_write <- function(x, file, ...) {
  target <- file.path(STAGE, "qa", "display_derivations", basename(file))
  dir.create(dirname(target), recursive = TRUE, showWarnings = FALSE)
  data.table::fwrite(x, target, ...)
}
fwrite <- audit_source_write
dir.create(FIG, recursive = TRUE, showWarnings = FALSE)
dir.create(SD, recursive = TRUE, showWarnings = FALSE)
truth <- fread(file.path(CLOSEOUT, "numeric_truth_table.tsv"), na.strings = "")
stopifnot(!anyDuplicated(truth$key))

PAL <- c(risk = "#B94C43", protective = "#3D73A6", neutral = "#B7B7B7", RNA = "#3A78A8",
         Protein = "#C77B30", purple = "#74649A", teal = "#3C938B", zero = "#8C8C8C",
         all = "#4A8C6F", partial = "#D5963F")

theme_pub <- function(base_size = 7.5, base_family = "Arial") {
  theme_classic(base_size = base_size, base_family = base_family) +
    theme(
      axis.line = element_line(linewidth = .35, colour = "black"),
      axis.ticks = element_line(linewidth = .35, colour = "black"),
      axis.title = element_text(size = base_size), axis.text = element_text(size = base_size - .5),
      legend.title = element_text(size = base_size - .3), legend.text = element_text(size = base_size - .7),
      legend.title.position = "top",
      strip.background = element_blank(), strip.text = element_text(size = base_size - .2, face = "bold"),
      plot.title = element_text(size = base_size + .5, face = "bold", hjust = .5),
      plot.title.position = "plot", plot.tag.position = "topleft",
      plot.tag = element_text(size = 8, face = "bold"), panel.grid = element_blank(),
      axis.title.x = element_text(margin = margin(t = 2)),
      axis.title.y = element_text(margin = margin(r = 2)),
      axis.text.y = element_text(hjust = 1, margin = margin(r = 1.5)),
      plot.margin = margin(6, 9, 10, 9)
    )
}
source(file.path(Sys.getenv("SIC_PLOT_ROOT"), "R", "11_title_hierarchy.R"))
theme_set(theme_pub())

# Patchwork aligns label columns, which otherwise centres a short y-axis title
# within the space reserved for long pathway labels. Anchor only that title
# to the right edge of its existing cell; do not move axes or change data.
compact_y_titles <- function(g) {
  if (inherits(g, "gtable")) {
    for (i in seq_along(g$grobs)) {
      if (grepl("^ylab-l", g$layout$name[i]) && inherits(g$grobs[[i]], "titleGrob")) {
        suffix <- sub("^ylab-l", "", g$layout$name[i])
        ai <- match(paste0("axis-l", suffix), g$layout$name)
        for (j in seq_along(g$grobs[[i]]$children)) {
          if (inherits(g$grobs[[i]]$children[[j]], "text") && !is.na(ai)) {
            tx <- g$grobs[[i]]$children[[j]]
            g$layout[i, c("l", "r")] <- g$layout[ai, c("l", "r")]
            g$layout$clip[i] <- "off"
            g$grobs[[i]] <- grid::textGrob(tx$label, x = grid::unit(1, "npc") - grid::unit(7, "mm"),
                                          y = .5, rot = 90, gp = tx$gp)
            break
          }
        }
      } else g$grobs[[i]] <- compact_y_titles(g$grobs[[i]])
    }
  }
  g
}
draw_publication <- function(p) {
  g <- if (inherits(p, "patchwork")) patchworkGrob(p) else ggplotGrob(p)
  grid::grid.draw(apply_title_hierarchy(compact_y_titles(g)))
}

legacy_save_bundle <- function(plot, stem, width_mm, height_mm, dpi = 600) {
  w <- width_mm / 25.4; h <- height_mm / 25.4
  svglite::svglite(paste0(stem, ".svg"), width = w, height = h, bg = "white")
  draw_publication(plot); dev.off()
  grDevices::cairo_pdf(paste0(stem, ".pdf"), width = w, height = h, family = "sans", bg = "white")
  draw_publication(plot); dev.off()
  ragg::agg_tiff(paste0(stem, ".tiff"), width = w, height = h, units = "in", res = dpi, compression = "lzw")
  draw_publication(plot); dev.off()
  ragg::agg_png(paste0(stem, ".png"), width = w, height = h, units = "in", res = dpi, background = "white")
  draw_publication(plot); dev.off()
}

truth_num <- function(k) {
  x <- truth[key == k, value_num]
  if (length(x) != 1L || !is.finite(x)) stop("Missing/non-finite truth key: ", k)
  x
}
stars <- function(x) fifelse(x < .001, "***", fifelse(x < .01, "**", fifelse(x < .05, "*", "")))
pathway_display <- function(x) {
  labels <- c(
    TNFA_SIGNALING_VIA_NFKB = "TNF-\u03b1 signaling via NF-\u03baB",
    TGF_BETA_SIGNALING = "TGF-\u03b2 signaling",
    IL6_JAK_STAT3_SIGNALING = "IL-6/JAK/STAT3 signaling",
    MYC_TARGETS_V1 = "MYC targets V1",
    MYC_TARGETS_V2 = "MYC targets V2",
    E2F_TARGETS = "E2F targets",
    DNA_REPAIR = "DNA repair",
    MTORC1_SIGNALING = "mTORC1 signaling",
    INTERFERON_ALPHA_RESPONSE = "IFN-\u03b1 response",
    INTERFERON_GAMMA_RESPONSE = "IFN-\u03b3 response",
    REACTIVE_OXYGEN_SPECIES_PATHWAY = "Reactive oxygen species pathway",
    OXIDATIVE_PHOSPHORYLATION = "Oxidative phosphorylation",
    EPITHELIAL_MESENCHYMAL_TRANSITION = "Epithelial-mesenchymal transition"
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
    str_replace(" \\+ prior D3 RNA availability$", "\n+ prior D3 RNA\navailability")
}

parse_truth_wide <- function(domain_name, id_expr) {
  d <- copy(truth[domain == domain_name])
  d[, id := eval(parse(text = id_expr))]
  dcast(d, id ~ source_field, value.var = "value_num")
}

source(file.path(Sys.getenv("SIC_PLOT_ROOT"), "R", "typography.R"))
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
  geom_tile(colour = "white", linewidth = .4) + geom_text(aes(label = label), size = 2.5) +
  scale_fill_gradient2(low = PAL["protective"], mid = "white", high = PAL["risk"], midpoint = 0) +
  labs(x = NULL, y = NULL, fill = "Mortality-association\nNES",
        title = "Time-specific whole-blood transcriptomic mortality-associated programmes") +
  theme_pub(7.5) + theme(plot.title = element_text(size = 10, face = "bold", hjust = 0))

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
  geom_tile(colour = "white", linewidth = .4) + geom_text(aes(label = label), size = 2.5) +
  scale_fill_gradient2(low = PAL["protective"], mid = "white", high = PAL["risk"], midpoint = 0) +
  labs(x = NULL, y = NULL, fill = "Mortality-association\nNES",
        title = "Time-specific plasma-protein mortality-associated programmes") +
  theme_pub(7.5) + theme(plot.title = element_text(size = 10, face = "bold", hjust = 0))

save_bundle(p3, file.path(FIG, "Figure3_Protein_core_NES"), 183, 112)
fwrite(prot_main, file.path(SD, "SourceData_Figure3_Protein.tsv"), sep = "\t")

# A2 aggregate probability and weight distributions
dist_t <- copy(truth[domain == "availability_distribution"])
dist_t[, c("a", "b", "scenario", "measure", "bin", "metric") := tstrsplit(key, "\\.")]
dist_w <- dcast(dist_t, scenario + measure + bin ~ metric, value.var = "value_num")
dist_w[, scenario_label := scenario_display(scenario)]
pA2 <- ggplot(dist_w, aes(mid, count, colour = scenario_label, group = scenario_label)) +
  geom_line(linewidth = .55) + facet_wrap(~measure, scales = "free_x", ncol = 1) +
  labs(x = NULL, y = "Aggregate patient count", colour = "Prespecified scenario", title = "Observation-probability and analysis-weight distributions") +
  theme_pub(6.5) + theme(legend.position = "bottom") +
  guides(colour = guide_legend(ncol = 1, byrow = TRUE))
save_bundle(pA2, file.path(FIG, "Supplementary_Figure_A2_probability_weight_distributions"), 183, 145)
fwrite(dist_w, file.path(SD, "SourceData_Supplementary_Figure_A2.tsv"), sep = "\t")

# A3 SMD love plot across all six scenarios
smd_t <- copy(truth[domain == "availability_balance"])
smd_t[, variable := sub("^.*/", "", filter)]
smd_t[, scenario := paste(str_match(key, "^availability\\.smd\\.([^.]+)\\.([^.]+)")[,2], str_match(key, "^availability\\.smd\\.([^.]+)\\.([^.]+)")[,3], sep = "__")]
smd_t[, scenario_label := scenario_display(scenario)]
# Preserve the manuscript's six-scenario order independently of operating-system locale.
scenario_order <- scenario_display(c('lower__SOFA_D3','primary__PF_PLT_noD3',
 'primary__PF_PLT_D3','primary__SOFA_noD3','primary__SOFA_D3','upper__SOFA_D3'))
smd_t[, scenario_label := factor(scenario_label,levels=scenario_order)]
smd_t[, stage := fifelse(source_field == "SMD_before", "Before weighting", "After weighting")]
pA3 <- ggplot(smd_t, aes(value_num, reorder(variable, abs(value_num)), colour = stage)) +
  geom_vline(xintercept = c(-.1, .1), linetype = 2, linewidth = .3, colour = "grey55") + geom_point(size = 1.25, alpha = .85) +
  facet_wrap(~scenario_label, ncol = 2, labeller = label_wrap_aligned(width = 42)) + scale_colour_manual(values = c("Before weighting" = "#8A8A8A", "After weighting" = unname(PAL["risk"]))) +
  labs(x = "Standardized mean difference", y = NULL, colour = NULL, title = "Covariate balance across all prespecified scenarios") +
  theme_pub(5.6) + theme(legend.position = "top")
save_bundle(pA3, file.path(FIG, "Supplementary_Figure_A3_pre_post_weight_SMD"), 183, 230)
dir.create(file.path(FIG,"continuations"),showWarnings=FALSE)
# scenario_order is fixed explicitly above; do not sort by the host locale.
for (j in 1:3) {
  selected <- scenario_order[(2*j-1):(2*j)]
  part <- pA3 %+% smd_t[scenario_label %in% selected]
  part <- part + facet_wrap(~scenario_label,ncol=1,labeller=label_wrap_aligned(width=75)) +
    theme_pub(7.25) + theme(legend.position="top", panel.spacing.y=unit(3,"mm"), strip.text=element_text(margin=margin(1,0,1,0)), plot.margin=margin(3,3,3,3)) +
    labs(title=paste0("Covariate balance: continuation ",j," of 3"))
  save_bundle(part,file.path(FIG,"continuations",paste0("A3_part_",j)),183,230)
}
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
  facet_wrap(~scenario_label, ncol = 3, labeller = label_wrap_aligned(width = 20)) + coord_equal() +
  scale_colour_manual(values = c(both = unname(PAL["risk"]), unweighted_only = "#E9A36A", IPW_only = unname(PAL["protective"]), neither = "#B8B8B8")) +
  labs(x = "Unweighted NES", y = "IPW NES", colour = "FDR class", title = "All-Hallmark concordance across prespecified IPW scenarios") +
  theme_pub(6) + theme(legend.position = "bottom",panel.spacing.x=unit(4,'mm'))
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
  scale_x_discrete(labels=function(x) stringr::str_wrap(gsub('\n',' ',x,fixed=TRUE),12)) +
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
  scale_x_discrete(labels=function(x) stringr::str_wrap(gsub('\n',' ',x,fixed=TRUE),14)) +
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
protein_samples <- dcast(fread(file.path(SD,"SourceData_Figure1_samples.tsv"))[Omics=="Protein"], Omics+Time~sample_level, value.var="N")
setnames(protein_samples,c("Raw measured","Delayed-entry risk-valid"),c("matched_n","risk_valid_n"))
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

writeLines(capture.output(sessionInfo()), file.path(STAGE, "qa", "sessionInfo_main_A1_A8_figures.txt"))
cat("Four main figures and eight availability supplementary figures exported.\n")
