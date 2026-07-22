#!/usr/bin/env Rscript
options(stringsAsFactors = FALSE)
args <- commandArgs(trailingOnly = FALSE)
script_arg <- grep("^--file=", args, value = TRUE)
script_file <- if (length(script_arg)) {
  normalizePath(sub("^--file=", "", script_arg[1]), winslash = "/")
} else {
  normalizePath(sys.frames()[[1]]$ofile, winslash = "/")
}
CLOSEOUT <- normalizePath(file.path(dirname(script_file), ".."), winslash = "/")
PUB <- file.path(CLOSEOUT, "public_source_data")
FIG <- file.path(CLOSEOUT, "figures")
dir.create(FIG, recursive = TRUE, showWarnings = FALSE)

suppressPackageStartupMessages({
  library(data.table)
  library(ggplot2)
  library(patchwork)
  library(svglite)
  library(ragg)
})

save_bundle <- function(plot, stem, width_mm, height_mm, dpi = 600) {
  width_in <- width_mm / 25.4
  height_in <- height_mm / 25.4
  svglite::svglite(paste0(stem, ".svg"), width = width_in, height = height_in, bg = "white")
  print(plot)
  dev.off()
  grDevices::cairo_pdf(paste0(stem, ".pdf"), width = width_in, height = height_in, family = "sans", bg = "white")
  print(plot)
  dev.off()
  ragg::agg_png(paste0(stem, ".png"), width = width_in, height = height_in, units = "in", res = dpi, background = "white")
  print(plot)
  dev.off()
  ragg::agg_tiff(
    paste0(stem, ".tiff"), width = width_in, height = height_in,
    units = "in", res = dpi, compression = "lzw", background = "white"
  )
  print(plot)
  dev.off()
}

public_label <- "^Centre [0-9]{2}$"
public_token <- "^center=Centre [0-9]{2}$"

centre <- fread(file.path(PUB, "SupplementaryTable_Centre_positivity.tsv"))
balance <- fread(file.path(PUB, "SupplementaryTable_Balance_SMD.tsv"))
stopifnot(all(grepl(public_label, centre$center)))
centre_terms <- balance$variable[startsWith(balance$variable, "center=")]
stopifnot(all(grepl(public_token, centre_terms)))

# Supplementary Figure A1 and its public source data.
a1 <- centre[entry_name == "primary", .(
  center,
  class,
  observed,
  unobserved,
  total = N
)]
a1[, class := factor(class, levels = c("all", "partial", "zero"), labels = c(
  "All-observation", "Partial-observation", "Zero-observation"
))]
setorder(a1, class, -total, center)
a1[, center_display := factor(center, levels = unique(center))]
a1_long <- melt(
  a1,
  id.vars = c("center", "center_display", "class"),
  measure.vars = c("observed", "unobserved"),
  variable.name = "availability",
  value.name = "N"
)
a1_long[, availability := factor(availability, levels = c("observed", "unobserved"), labels = c("Observed", "Unobserved"))]
fwrite(
  a1_long[, .(center, class = as.character(class), availability = tolower(as.character(availability)), N)],
  file.path(PUB, "SourceData_Supplementary_Figure_A1.tsv"),
  sep = "\t"
)

p_a1 <- ggplot(a1_long, aes(center_display, N, fill = availability)) +
  geom_col(width = 0.78) +
  facet_grid(. ~ class, scales = "free_x", space = "free_x") +
  labs(
    x = NULL,
    y = "Day-5 landmark survivors",
    fill = NULL,
    title = "Centre-level Day-5 RNA-seq positivity support"
  ) +
  theme_classic(base_size = 8, base_family = "sans") +
  theme(
    axis.text.x = element_text(angle = 60, hjust = 1, vjust = 1, size = 6.5),
    strip.background = element_blank(),
    strip.text = element_text(face = "bold", size = 8),
    legend.position = "top",
    plot.title = element_text(face = "bold", hjust = 0.5, size = 11),
    panel.spacing.x = grid::unit(5, "mm")
  )
save_bundle(
  p_a1,
  file.path(FIG, "Supplementary_Figure_A1_centre_positivity"),
  183,
  115
)

# Supplementary Figure A3 and its public source data.
scenario_levels <- c(
  "primary__SOFA_D3",
  "primary__SOFA_noD3",
  "primary__PF_PLT_D3",
  "primary__PF_PLT_noD3",
  "lower__SOFA_D3",
  "upper__SOFA_D3"
)
scenario_labels <- c(
  primary__SOFA_D3 = "Primary | baseline SOFA + prior D3 RNA availability",
  primary__SOFA_noD3 = "Primary | baseline SOFA",
  primary__PF_PLT_D3 = "Primary | P/F + platelet + prior D3 RNA availability",
  primary__PF_PLT_noD3 = "Primary | P/F + platelet",
  lower__SOFA_D3 = "Lower entry boundary | baseline SOFA + prior D3 RNA availability",
  upper__SOFA_D3 = "Upper entry boundary | baseline SOFA + prior D3 RNA availability"
)
balance[, scenario := paste(entry_name, spec, sep = "__")]
balance[, scenario := factor(scenario, levels = scenario_levels, labels = unname(scenario_labels[scenario_levels]))]
balance[, variable_display := sub("^center=", "", variable)]
balance[, variable_panel := factor(
  paste(as.character(scenario), variable_display, sep = "___"),
  levels = paste(as.character(scenario), variable_display, sep = "___")[order(as.character(scenario), -abs(SMD_before))]
)]

balance_long <- melt(
  balance,
  id.vars = c("scenario", "variable", "variable_display", "variable_panel"),
  measure.vars = c("SMD_before", "SMD_after"),
  variable.name = "stage",
  value.name = "SMD"
)
balance_long[, stage := factor(stage, levels = c("SMD_before", "SMD_after"), labels = c("Before weighting", "After weighting"))]
fwrite(
  balance_long[, .(scenario = as.character(scenario), variable, stage = as.character(stage), SMD)],
  file.path(PUB, "SourceData_Supplementary_Figure_A3.tsv"),
  sep = "\t"
)

segment <- balance[, .(
  scenario,
  variable_panel,
  variable_display,
  SMD_before,
  SMD_after
)]
p_a3 <- ggplot() +
  geom_segment(
    data = segment,
    aes(x = SMD_before, xend = SMD_after, y = variable_panel, yend = variable_panel),
    linewidth = 0.3,
    colour = "grey65"
  ) +
  geom_point(
    data = balance_long,
    aes(x = SMD, y = variable_panel, shape = stage),
    size = 1.05
  ) +
  geom_vline(xintercept = c(-0.1, 0.1), linetype = 2, linewidth = 0.3) +
  geom_vline(xintercept = 0, linewidth = 0.25) +
  facet_wrap(~scenario, ncol = 2, scales = "free_y") +
  scale_y_discrete(labels = function(x) sub("^.*___", "", x)) +
  labs(
    x = "Standardised mean difference",
    y = NULL,
    shape = NULL,
    title = "Covariate balance before and after inverse-observation weighting"
  ) +
  theme_classic(base_size = 6.3, base_family = "sans") +
  theme(
    strip.background = element_blank(),
    strip.text = element_text(face = "bold", size = 6.5),
    axis.text.y = element_text(size = 4.6),
    legend.position = "top",
    plot.title = element_text(face = "bold", hjust = 0.5, size = 9),
    panel.spacing = grid::unit(5, "mm")
  )
save_bundle(
  p_a3,
  file.path(FIG, "Supplementary_Figure_A3_pre_post_weight_SMD"),
  183,
  237
)

cat("Anonymised Supplementary Figures A1 and A3 rebuilt from public S8 source tables.\n")
