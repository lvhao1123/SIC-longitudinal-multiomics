
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
FIG <- file.path(Sys.getenv("SIC_CENTRE_FIG_OUTPUT"), "figures")
SD <- file.path(Sys.getenv('SIC_R7_BASE'), "figure_source_data")
# The source-data snapshot is immutable. Retain display derivations separately.
audit_source_write <- function(x, file, ...) {
  target <- file.path(Sys.getenv("SIC_CENTRE_FIG_OUTPUT"), "qa", "display_derivations", basename(file))
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

theme_pub <- function(base_size = 7, base_family = "Arial") {
  theme_classic(base_size = base_size, base_family = base_family) +
    theme(
      axis.line = element_line(linewidth = .35, colour = "black"),
      axis.ticks = element_line(linewidth = .35, colour = "black"),
      axis.title = element_text(size = base_size), axis.text = element_text(size = base_size - .5),
      legend.title = element_text(size = base_size - .3), legend.text = element_text(size = base_size - .7),
      strip.background = element_blank(), strip.text = element_text(size = base_size - .2, face = "bold"),
      plot.title = element_text(size = base_size + .5, face = "bold", hjust = .5),
      plot.title.position = "plot", plot.tag.position = "topleft",
      plot.tag = element_text(size = 8, face = "bold"), panel.grid = element_blank(),
      axis.title.x = element_text(margin = margin(t = 2)),
      axis.title.y = element_text(margin = margin(r = 2)),
      axis.text.y = element_text(hjust = 1, lineheight = .78, margin = margin(r = 1.5)),
      plot.margin = margin(6, 9, 10, 9)
    )
}
source(file.path(STAGE, "R", "11_title_hierarchy.R"))
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
            g$grobs[[i]] <- grid::textGrob(tx$label, x = grid::unit(1, "npc") - grid::unit(10, "mm"),
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

save_bundle <- function(plot, stem, width_mm, height_mm, dpi = 600) {
  w <- width_mm / 25.4; h <- height_mm / 25.4
  svglite::svglite(paste0(stem, ".svg"), width = w, height = h, bg = "white")
  draw_centre_labels(plot); dev.off()
  grDevices::cairo_pdf(paste0(stem, ".pdf"), width = w, height = h, family = "sans", bg = "white")
  draw_centre_labels(plot); dev.off()
  ragg::agg_tiff(paste0(stem, ".tiff"), width = w, height = h, units = "in", res = dpi, compression = "lzw")
  draw_centre_labels(plot); dev.off()
  ragg::agg_png(paste0(stem, ".png"), width = w, height = h, units = "in", res = dpi, background = "white")
  draw_centre_labels(plot); dev.off()
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
  geom_tile(colour = "white", linewidth = .3) + geom_text(aes(label = label), size = 2.5) +
  scale_fill_gradient2(low = PAL["protective"], mid = "white", high = PAL["risk"], midpoint = 0) +
  labs(x = NULL, y = NULL, fill = "Partial rho", title = "Same-time RNA-protein
associations") + theme_pub(7.5) + theme(plot.margin = margin(4, 3, 5, 3))

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
    theme_pub(7.5) + theme(plot.margin = margin(4, 3, 5, 3)) + theme(legend.position = "none")
}
p4b <- make_forward_panel("RNA D1 to Protein D3", "RNA D1 to Protein D3")
p4c <- make_forward_panel("RNA D3 to Protein D5", "RNA D3 to Protein D5")

reverse[, interval := factor(Direction, levels = c("Protein D1 to RNA D3", "Protein D3 to RNA D5"), labels = c("D1 to D3", "D3 to D5"))]
reverse[, label := paste0(sprintf("%.2f", beta), stars(FDR))]
p4d <- ggplot(reverse, aes(interval, Pathway_label, fill = beta)) +
  geom_tile(colour = "white", linewidth = .3) + geom_text(aes(label = label), size = 2.5) +
  scale_fill_gradient2(low = PAL["protective"], mid = "white", high = PAL["risk"], midpoint = 0) +
  labs(x = NULL, y = NULL, fill = "Adjusted beta", title = "Reverse Protein-to-RNA\nmodels") + theme_pub(7.5) + theme(plot.margin = margin(4, 3, 5, 3))

# Approved replacement from the existing S15 paired specifications; no refitting.
# See qa/FIGURE4E_PAIRED_SPECIFICATION_CHECKS.tsv and comparability summary.
ox_plot <- fread(file.path(SD, "SourceData_Figure4E_OXPHOS_attenuation.tsv"))
stopifnot(nrow(ox_plot)==10L, all(ox_plot$FDR>.05))
ox_plot[, model := factor(model, levels = c("Without group adjustment", "With group adjustment"))]
p4e <- ggplot(ox_plot, aes(model, effect, group = association, colour = association)) +
  geom_hline(yintercept = 0, linewidth = .3, colour = "grey65") + geom_line(linewidth = .45) + geom_point(size = 2.5) +
  scale_colour_brewer(palette = "Dark2") +
  labs(x = NULL, y = "OXPHOS association", colour = NULL, title = "OXPHOS: matched models\nwith and without group adjustment") +
  theme_pub(7.5) + theme(plot.margin = margin(4, 3, 5, 3)) + theme(axis.text.x = element_text(angle = 0, hjust = .5), legend.position = "bottom") +
  scale_x_discrete(labels = c("Without\ngroup\nadjustment", "With\ngroup\nadjustment")) +
  guides(colour = guide_legend(ncol = 2, byrow = TRUE))

ifn <- forward[Pathway %in% c("INTERFERON_ALPHA_RESPONSE", "INTERFERON_GAMMA_RESPONSE")]
ifn[, label := paste(unname(short[Pathway]), str_replace_all(Direction, c("RNA " = "", "Protein " = "", " to " = " to ")), sep = "\n")]
p4f <- ggplot(ifn, aes(beta, reorder(label, beta), colour = Pathway)) +
  geom_vline(xintercept = 0, linetype = 2, linewidth = .3, colour = "grey55") +
  geom_errorbar(aes(xmin = lower95, xmax = upper95), orientation = "y", width = .14, linewidth = .45) + geom_point(size = 1.9) +
  scale_colour_manual(values = c(INTERFERON_ALPHA_RESPONSE = unname(PAL["RNA"]), INTERFERON_GAMMA_RESPONSE = unname(PAL["purple"]))) +
  labs(x = "Adjusted beta (95% CI)", y = NULL, colour = NULL, title = "Interferon effect estimates") + theme_pub(7.5) + theme(plot.margin = margin(4, 3, 5, 3)) + theme(legend.position = "none")

panel_tag_theme <- theme(
  plot.tag = element_text(size = 8, face = "bold", colour = "black"),
  plot.tag.position = "topleft"
)
p4a <- p4a + labs(tag = "a", fill = "Partial ρ") + panel_tag_theme
p4b <- p4b + labs(tag = "b") + panel_tag_theme
p4c <- p4c + labs(tag = "c") + panel_tag_theme
p4d <- p4d + labs(tag = "d", fill = "Adjusted β") + panel_tag_theme
p4e <- p4e + labs(tag = "e") + panel_tag_theme
p4f <- p4f + labs(tag = "f") + panel_tag_theme

# Compact legends release horizontal room without removing any labels or data.
for(nm in c('p4a','p4b','p4c','p4d','p4e','p4f')) {
  assign(nm,get(nm)+theme(plot.margin=margin(4,0,5,0),
    legend.margin=margin(0,0,0,0),legend.box.spacing=unit(1,'mm'),
    legend.key.width=unit(2,'mm')))
}
for(nm in c('p4b','p4c','p4f')) {
  assign(nm,get(nm)+labs(x='Adjusted β (95% CI)')+
    scale_x_continuous(labels=function(x) format(x,trim=TRUE,scientific=FALSE)))
}

fig4 <- wrap_plots(A = p4a, D = p4d, B = p4b, C = p4c, E = p4e, F = p4f,
                  design = "AD\nBC\nEF", heights = c(1.25, 1.10, .95), widths = c(1, 1)) +
  plot_annotation(
    title = "Pathway-selective contemporaneous and forward cross-omic associations",
    theme = theme(plot.title = element_text(size = 10, face = "bold", hjust = 0))
  )

if (Sys.getenv('SIC_PROFILE')=='candidate') source(file.path(Sys.getenv('SIC_PLOT_ROOT'),'R/typography.R'))
save_bundle(fig4, file.path(FIG, "Figure4_CrossOmics_integrated_A_to_F"), 185, 245)
data.table::fwrite(same_w, file.path(Sys.getenv("SIC_CENTRE_FIG_OUTPUT"),"qa/display_derivations/SourceData_Figure4A_same_time.tsv"),sep="\t")
data.table::fwrite(forward[Direction == "RNA D1 to Protein D3"], file.path(Sys.getenv("SIC_CENTRE_FIG_OUTPUT"),"qa/display_derivations/SourceData_Figure4B_forward_D1_D3.tsv"),sep="\t")
data.table::fwrite(forward[Direction == "RNA D3 to Protein D5"], file.path(Sys.getenv("SIC_CENTRE_FIG_OUTPUT"),"qa/display_derivations/SourceData_Figure4C_forward_D3_D5.tsv"),sep="\t")
data.table::fwrite(reverse, file.path(Sys.getenv("SIC_CENTRE_FIG_OUTPUT"),"qa/display_derivations/SourceData_Figure4D_reverse.tsv"),sep="\t")
data.table::fwrite(ox_plot, file.path(Sys.getenv("SIC_CENTRE_FIG_OUTPUT"),"qa/display_derivations/SourceData_Figure4E_OXPHOS_attenuation.tsv"),sep="\t")
data.table::fwrite(ifn, file.path(Sys.getenv("SIC_CENTRE_FIG_OUTPUT"),"qa/display_derivations/SourceData_Figure4F_IFN_effects.tsv"),sep="\t")
capture.output(sessionInfo(),file=file.path(Sys.getenv("SIC_CENTRE_FIG_OUTPUT"),"qa/sessionInfo_Figure4_targeted_repair.txt"))
