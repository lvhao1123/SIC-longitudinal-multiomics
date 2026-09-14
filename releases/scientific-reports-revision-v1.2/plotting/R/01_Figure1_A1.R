
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
SD <- file.path(Sys.getenv("SIC_R7_BASE"), "figure_source_data")
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
  draw_centre_labels(plot); dev.off()
  grDevices::cairo_pdf(paste0(stem, ".pdf"), width = w, height = h, family = "sans", bg = "white")
  draw_centre_labels(plot); dev.off()
  ragg::agg_tiff(paste0(stem, ".tiff"), width = w, height = h, units = "in", res = dpi, compression = "lzw")
  draw_centre_labels(plot); dev.off()
  ragg::agg_png(paste0(stem, ".png"), width = w, height = h, units = "in", res = dpi, background = "white")
  draw_centre_labels(plot); dev.off()
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
    "Longitudinal\nmolecular sampling",
    "Delayed-entry\nrisk sets\nD1 / D3 / D5",
    "Subsequent\nmortality\nthrough day 60"
  )
)
p1a <- ggplot(p1a_nodes, aes(x, y)) +
  geom_rect(aes(xmin = x - .43, xmax = x + .43, ymin = .84, ymax = 1.16),
            fill = "#F7F7F7", colour = "#666666", linewidth = .35) +
  geom_text(aes(label = label), size = 2.35, lineheight = .95, family = "Arial") +
  geom_segment(data = data.table(x = c(1.43, 2.43, 3.43), xend = c(1.57, 2.57, 3.57), y = 1, yend = 1),
               aes(x = x, xend = xend, y = y, yend = yend), arrow = arrow(length = grid::unit(1.8, "mm")), linewidth = .4) +
  coord_cartesian(xlim = c(.48, 4.52), ylim = c(.65, 1.35), clip = "off") + theme_void()

p1b <- ggplot(fig1_long, aes(Time, N, fill = sample_level)) +
  geom_col(position = position_dodge(.72), width = .62) +
  geom_text(data = fig1_wide, aes(x = Time, y = pmax(matched_n, risk_valid_n),
            label = paste(matched_n, risk_valid_n, sep = " / ")), inherit.aes = FALSE,
            vjust = -.65, size = 2.0, colour = "black") +
  facet_wrap(~Omics, scales = "free_y", labeller = as_labeller(c(Protein = "Plasma\nproteomics", RNA = "Whole-blood\nRNA-seq"))) +
  scale_fill_manual(values = c("Raw measured" = "#9AB8CF", "Delayed-entry risk-valid" = unname(PAL["RNA"]))) +
  scale_y_continuous(expand = expansion(mult = c(0, .16))) +
  labs(x = "", y = "Samples, n", fill = NULL, title = "Measured versus risk-valid\nmolecular samples") +
  guides(fill = guide_legend(ncol = 1)) +
  theme_pub(6.7) + theme(legend.position = "top", legend.key.height=unit(2,'mm'),legend.spacing.y=unit(0,'mm'))

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
  scale_y_discrete(labels=function(x) stringr::str_wrap(x,19)) +
  labs(x = "Patients", y = NULL, fill = NULL, title = "Day-5 availability\nhierarchy") +
  theme_pub(6.7) + theme(legend.position = "none")

d5_excl <- data.table(
  category = c("Structural deaths\nat/before entry", "Patients from\nzero-observation\nsample-prefix groups"),
  N = c(truth_num("availability.primary.structural_N"),
        truth_num("availability.primary.risk_N") - truth_num("availability.primary.support_N"))
)
centre_class <- data.table(
  class = c("Zero-observation", "All-observation", "Partial-observation"),
  centres = c(truth_num("availability.primary.centres_zero"), truth_num("availability.primary.centres_all"), truth_num("availability.primary.centres_partial"))
)
p1d_left <- ggplot(d5_excl, aes(N, reorder(category, N), fill = category)) +
  geom_col(width = .6) + geom_text(aes(label = as.integer(N)), hjust = -.2, size = 2.3) +
  scale_fill_manual(values = c("Structural deaths\nat/before entry" = "#A6A6A6", "Patients from\nzero-observation\nsample-prefix groups" = unname(PAL["zero"]))) +
  scale_x_continuous(expand = expansion(mult = c(0, .25))) + theme_pub(6.2) +
  labs(x = "Patients", y = NULL, title = "Excluded from D5\nIPW estimand") + theme(legend.position = "none")
p1d_right <- ggplot(centre_class, aes(class, centres, fill = class)) +
  geom_col(width = .62) + geom_text(aes(label = as.integer(centres)), vjust = -.25, size = 2.3) +
  scale_fill_manual(values = c("Zero-observation" = unname(PAL["zero"]), "All-observation" = unname(PAL["all"]), "Partial-observation" = unname(PAL["partial"]))) +
  scale_y_continuous(expand = expansion(mult = c(0, .18))) + theme_pub(6.2) +
  labs(x = NULL, y = "Centres", title = "Empirical positivity\nby centre") +
  theme(axis.text.x = element_text(angle = 0, hjust = .5), legend.position = "none") +
  scale_x_discrete(limits = c("All-observation", "Partial-observation", "Zero-observation"),
                   labels = c("All-\nobservation", "Partial-\nobservation", "Zero-\nobservation"))
p1d <- p1d_left | p1d_right

fig1_middle <- (p1b | p1c) + plot_layout(widths = c(1.1, 1))
p1a <- p1a + theme(plot.tag = element_text(size = 8, face = "bold", family = "Arial"))
fig1 <- wrap_plots(A = free(p1a), B = free(p1b), C = free(p1c), D = free(p1d_left), E = free(p1d_right),
                   design = "AA\nBC\nDE", widths = c(1.1, 1), heights = c(.6, 1.5, 1.05)) +
  plot_annotation(
    tag_levels = "a",
    title = "Study design, longitudinal risk sets and Day-5 availability estimand",
    theme = theme(plot.title = element_text(size = 9, face = "bold", hjust = .5))
  )
save_bundle(fig1, file.path(FIG, "Figure1_study_design_risksets_availability"), 183, 185)
fwrite(fig1_long, file.path(SD, "SourceData_Figure1_samples.tsv"), sep = "\t")
fwrite(d5, file.path(SD, "SourceData_Figure1_D5_availability.tsv"), sep = "\t")
fwrite(d5_excl, file.path(SD, "SourceData_Figure1_exclusions.tsv"), sep = "\t")
fwrite(centre_class, file.path(SD, "SourceData_Figure1_centre_classes.tsv"), sep = "\t")

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
  labs(x = NULL, y = "D5 landmark survivors", fill = NULL, title = "D5 RNA positivity support by sample-prefix group") +
  theme_pub(6.5) + theme(axis.text.x = element_text(angle = 60, hjust = 1), legend.position = "top")
save_bundle(pA1, file.path(FIG, "Supplementary_Figure_A1_centre_positivity"), 183, 105)
fwrite(centre_long, file.path(SD, "SourceData_Supplementary_Figure_A1.tsv"), sep = "\t")

