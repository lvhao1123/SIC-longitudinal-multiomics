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
FIG <- file.path(Sys.getenv("SIC_CENTRE_FIG_OUTPUT"), "figures")
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
  draw_centre_labels(plot); dev.off()
  grDevices::cairo_pdf(paste0(stem, ".pdf"), width = w, height = h, family = "sans", bg = "white")
  draw_centre_labels(plot); dev.off()
  ragg::agg_tiff(paste0(stem, ".tiff"), width = w, height = h, units = "in", res = dpi, compression = "lzw")
  draw_centre_labels(plot); dev.off()
  ragg::agg_png(paste0(stem, ".png"), width = w, height = h, units = "in", res = dpi, background = "white")
  draw_centre_labels(plot); dev.off()
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


# Terminology-only grob patch: keep the original gtable cell widths/heights,
# axes, coordinates, point estimates, intervals, colours and font properties.
patch_centre_labels <- function(g) {
  if (inherits(g,"text") && is.character(g$label)) {
    substitutions <- c("sample-prefix groups"="centres", "Sample-prefix groups"="Centres",
       "sample-prefix group"="centre", "group adjustment"="centre adjustment",
       "Without group"="Without centre", "With group"="With centre",
       "group-sensitivity"="centre-sensitivity", "\ngroup\n"="\ncentre\n")
    for (old in names(substitutions)) g$label <- gsub(old,substitutions[[old]],g$label,fixed=TRUE)
  }
  if (!is.null(g$grobs)) for(i in seq_along(g$grobs))g$grobs[[i]]<-patch_centre_labels(g$grobs[[i]])
  if (!is.null(g$children)) for(i in seq_along(g$children))g$children[[i]]<-patch_centre_labels(g$children[[i]])
  g
}
draw_centre_labels <- function(p) {
  g<-if(inherits(p,"patchwork"))patchwork::patchworkGrob(p) else ggplot2::ggplotGrob(p)
  if(exists("compact_y_titles"))g<-compact_y_titles(g)
  grid::grid.draw(patch_centre_labels(apply_title_hierarchy(g)))
}
source(file.path(Sys.getenv("SIC_PLOT_ROOT"), "R", "typography.R"))
# S13: reviewer-requested post hoc centre sensitivity.
s13 <- fread(file.path(SD, "SourceData_Supplementary_Figure_S13_IFN_centre_sensitivity.tsv"))
s13[, pathway_display := pathway_label(Pathway)]
s13[, centre_adjustment := factor(centre_adjustment, levels = c("Without centre", "With centre"))]
s13[, interval := factor(interval, levels = c("D1", "D3", "D5", "D1 to D3", "D3 to D5"))]

same13 <- s13[analysis == "Same-time partial Spearman"]
p13a <- ggplot(same13, aes(centre_adjustment, estimate, group = pathway_display, colour = pathway_display)) +
  geom_hline(yintercept = 0, linewidth = .35, colour = "#777777") +
  geom_line(linewidth = .45) + geom_point(size = 1.5) +
  facet_wrap(~ interval, nrow = 1) +
  scale_x_discrete(labels = c("Without centre" = "Without\ncentre", "With centre" = "With\ncentre")) +
  scale_colour_manual(values = c("IFN-alpha response" = unname(PAL["RNA"]),
                                 "IFN-gamma response" = unname(PAL["purple"]),
                                 "Oxidative phosphorylation" = unname(PAL["teal"])),labels=function(x) stringr::str_wrap(x,18)) +
  labs(x = NULL, y = "Partial Spearman rho", colour = NULL, title = "Same-time associations") +
  theme_pub(6.0) + theme(legend.position = "top", axis.text.x = element_text(angle = 0),panel.spacing.x=unit(4,'mm'))

forward13 <- s13[analysis == "Forward linear model"]
forward13[, row_label := paste(pathway_display, sub("centre", "group", centre_adjustment), sep = " | ")]
forward13[, row_label := factor(row_label, levels = rev(unique(row_label)))]
p13b <- ggplot(forward13, aes(estimate, row_label, xmin = lower95, xmax = upper95,
                             colour = centre_adjustment)) +
  geom_vline(xintercept = 0, linetype = 2, linewidth = .35, colour = "#777777") +
  geom_errorbarh(height = 0, linewidth = .4) + geom_point(size = 1.5) +
  facet_wrap(~ interval, nrow = 1) +
  scale_colour_manual(values = c("Without centre" = unname(PAL["without"]),
                                 "With centre" = unname(PAL["with"])),
                      labels = c("Without centre" = "Without group", "With centre" = "With group")) +
  scale_y_discrete(labels=function(x) gsub(' | ','\n',x,fixed=TRUE)) +
  labs(x = "Adjusted beta (95% CI)", y = NULL, colour = NULL, title = "Forward associations") +
  theme_pub(5.8) + theme(legend.position = "top",panel.spacing.x=unit(4,'mm'))

fig13 <- free(p13a, type = "label", side = "l") / p13b + plot_layout(heights = c(.8, 1.25)) +
  plot_annotation(title = "Effect of group adjustment on selected cross-omic pathway associations",
                  subtitle = "Post hoc group-sensitivity analysis",
                  tag_levels = "a")
save_bundle(fig13, file.path(FIG, "Supplementary_Figure_S13_IFN_centre_sensitivity"), 183, 190)

