#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(data.table)
  library(ggplot2)
  library(patchwork)
})

root <- normalizePath(".", winslash = "/", mustWork = TRUE)
output_source <- file.path(
  root,
  "submission/public_source_data/SourceData_Supplementary_Figure_A9.tsv"
)
private_default <- file.path(
  root,
  "private_outputs/audit_2026-07-15/SIC_reanalysis_2026-07-11",
  "05_Clinical_Tables/Clinical_univariable_Cox.csv"
)
input_file <- Sys.getenv("SIC_CLINICAL_COX_FILE", unset = private_default)
if (!file.exists(input_file) && file.exists(output_source)) {
  input_file <- output_source
}
if (!file.exists(input_file)) {
  stop(
    "Clinical Cox aggregate input was not found. Set SIC_CLINICAL_COX_FILE ",
    "or provide the tracked Figure A9 source-data file."
  )
}

dat <- fread(input_file, data.table = FALSE)
required <- c(
  "Variable", "Label", "Type", "Contrast", "Reference", "N", "Events",
  "HR", "Lower95", "Upper95", "P_value", "BH_FDR", "PH_p",
  "Nonlinearity_LRT_p", "Overall_factor_LRT_p"
)
stopifnot(all(required %in% names(dat)))
stopifnot(nrow(dat) == 41L)
stopifnot(all(dat$N == 504L), all(dat$Events == 84L))
stopifnot(all(is.finite(dat$HR)), all(dat$HR > 0))
stopifnot(all(is.finite(dat$Lower95)), all(dat$Lower95 > 0))
stopifnot(all(is.finite(dat$Upper95)), all(dat$Upper95 > 0))

domain_map <- list(
  "Demographics and anthropometrics" = c("age", "height", "weight", "BMI"),
  "Vital signs" = c("hrmax", "mapmax", "sapmax", "rrmax", "tmax"),
  "Laboratory and organ-function measures" = c(
    "lac", "k", "na", "cl", "bun", "alb", "cr", "bilirubin", "crp",
    "procal", "wbc", "plt", "inr", "aptt", "ddimer", "SOFA", "pf"
  ),
  "Sex and comorbidities" = c(
    "sex", "diabete", "hyperten", "myoinfarc", "cardiofailure",
    "cerebrovasc", "dementia", "copd", "paralysis", "renafailure"
  ),
  "Infection source" = "infectionSite_SD"
)
domain_lookup <- unlist(lapply(names(domain_map), function(x) {
  setNames(rep(x, length(domain_map[[x]])), domain_map[[x]])
}))
dat$Domain <- unname(domain_lookup[dat$Variable])
stopifnot(!anyNA(dat$Domain))

table1_label_map <- c(
  age = "Age", height = "Height", weight = "Weight", BMI = "BMI",
  hrmax = "HRmax", mapmax = "MAPmax", sapmax = "SBPmax",
  rrmax = "RRmax", tmax = "Tmax", lac = "Lactate", k = "K",
  na = "Na", cl = "Cl", bun = "BUN", alb = "Albumin",
  cr = "Creatinine", bilirubin = "Bilirubin", crp = "CRP",
  procal = "PCT", wbc = "WBC count", plt = "Platelet count",
  inr = "INR", aptt = "aPTT", ddimer = "D-dimer",
  SOFA = "SOFA score", pf = "PaO₂/FiO₂ ratio",
  sex = "Male sex", diabete = "Diabetes mellitus",
  hyperten = "Hypertension", myoinfarc = "Myocardial infarction",
  cardiofailure = "Heart failure", cerebrovasc = "Cerebrovascular disease",
  dementia = "Dementia", copd = "COPD", paralysis = "Paralysis",
  renafailure = "Renal failure", infectionSite_SD = "Infection source"
)
dat$Figure_label <- unname(table1_label_map[dat$Variable])
stopifnot(!anyNA(dat$Figure_label))

infection_contrast_map <- c(
  "Abdomen vs Lung/Chest" = "Abdomen vs Lung/chest",
  "Biliary/Liver vs Lung/Chest" = "Biliary/liver vs Lung/chest",
  "Others/Unknown vs Lung/Chest" = "Others/unknown vs Lung/chest",
  "SoftTissue vs Lung/Chest" = "Soft tissue vs Lung/chest",
  "Urinary vs Lung/Chest" = "Urinary vs Lung/chest"
)
dat$Figure_contrast <- dat$Contrast
is_infection <- dat$Variable == "infectionSite_SD"
dat$Figure_contrast[is_infection] <- unname(
  infection_contrast_map[dat$Contrast[is_infection]]
)
stopifnot(!anyNA(dat$Figure_contrast[is_infection]))

# Figure A9 follows the concise Table 1 names. Units and continuous-variable
# increments remain in the source-data Contrast field and Supplementary Table S2.
dat$Display_label <- ifelse(
  is_infection,
  dat$Figure_contrast,
  dat$Figure_label
)
dat$FDR_status <- ifelse(dat$BH_FDR < 0.05, "BH-FDR < 0.05", "Not FDR-significant")
dat$Direction_status <- ifelse(
  dat$BH_FDR < 0.05 & dat$HR > 1,
  "Higher hazard",
  ifelse(dat$BH_FDR < 0.05 & dat$HR < 1, "Lower hazard", "Not FDR-significant")
)
dat$PH_flag <- !is.na(dat$PH_p) & dat$PH_p < 0.05
dat$Nonlinearity_flag <- !is.na(dat$Nonlinearity_LRT_p) & dat$Nonlinearity_LRT_p < 0.05
dat$Diagnostic_symbol <- paste0(
  ifelse(dat$PH_flag, "\u2020", ""),
  ifelse(dat$Nonlinearity_flag, "\u2021", "")
)
dat$Estimate_text <- sprintf("%.2f (%.2f-%.2f)", dat$HR, dat$Lower95, dat$Upper95)
dat$FDR_text <- ifelse(
  dat$BH_FDR < 0.001,
  "<0.001*",
  paste0(formatC(dat$BH_FDR, format = "f", digits = 3), ifelse(dat$BH_FDR < 0.05, "*", ""))
)

dir.create(dirname(output_source), recursive = TRUE, showWarnings = FALSE)
fwrite(dat, output_source, sep = "\t", na = "")

domain_order <- names(domain_map)
rows <- list()
row_index <- 0L
for (domain in domain_order) {
  row_index <- row_index + 1L
  rows[[length(rows) + 1L]] <- data.frame(
    row_index = row_index,
    is_header = TRUE,
    Domain = domain,
    Display_label = domain,
    HR = NA_real_, Lower95 = NA_real_, Upper95 = NA_real_,
    Direction_status = NA_character_, Estimate_text = "", FDR_text = "",
    Diagnostic_symbol = "",
    stringsAsFactors = FALSE
  )
  block <- dat[dat$Domain == domain, , drop = FALSE]
  for (i in seq_len(nrow(block))) {
    row_index <- row_index + 1L
    rows[[length(rows) + 1L]] <- data.frame(
      row_index = row_index,
      is_header = FALSE,
      Domain = domain,
      Display_label = block$Display_label[i],
      HR = block$HR[i], Lower95 = block$Lower95[i], Upper95 = block$Upper95[i],
      Direction_status = block$Direction_status[i],
      Estimate_text = block$Estimate_text[i],
      FDR_text = block$FDR_text[i],
      Diagnostic_symbol = block$Diagnostic_symbol[i],
      stringsAsFactors = FALSE
    )
  }
}
plot_dat <- do.call(rbind, rows)
plot_dat$y <- rev(seq_len(nrow(plot_dat)))

palette <- c(
  "Higher hazard" = "#B64A4A",
  "Lower hazard" = "#346B9A",
  "Not FDR-significant" = "#8B8B8B"
)

base_theme <- theme_classic(base_size = 7, base_family = "Arial") +
  theme(
    plot.title = element_text(face = "bold", size = 8, margin = margin(b = 3)),
    axis.text.y = element_blank(),
    axis.ticks.y = element_blank(),
    axis.line.y = element_blank(),
    plot.margin = margin(3, 3, 3, 3),
    legend.position = "bottom",
    legend.title = element_blank(),
    legend.text = element_text(size = 6.4),
    legend.key.width = grid::unit(3.5, "mm")
  )

label_panel <- ggplot(plot_dat, aes(y = y)) +
  geom_text(
    data = plot_dat[plot_dat$is_header, ],
    aes(x = 0, label = Display_label),
    hjust = 0, fontface = "bold", colour = "#1F3B4D", size = 2.55
  ) +
  geom_text(
    data = plot_dat[!plot_dat$is_header, ],
    aes(x = 0.02, label = Display_label),
    hjust = 0, colour = "#222222", size = 2.25
  ) +
  scale_x_continuous(limits = c(0, 1), expand = c(0, 0)) +
  scale_y_continuous(limits = c(0.5, max(plot_dat$y) + 0.5), expand = c(0, 0)) +
  labs(title = "Clinical variable") +
  theme_void(base_family = "Arial") +
  theme(
    plot.title = element_text(face = "bold", size = 8, margin = margin(b = 3)),
    plot.margin = margin(3, 1, 3, 3)
  )

forest_panel <- ggplot(plot_dat[!plot_dat$is_header, ], aes(y = y)) +
  geom_vline(xintercept = 1, linewidth = 0.35, linetype = "dashed", colour = "#444444") +
  geom_segment(
    aes(x = Lower95, xend = Upper95, yend = y),
    linewidth = 0.45, colour = "#5A5A5A"
  ) +
  geom_point(
    aes(x = HR, fill = Direction_status),
    shape = 21, size = 2.15, stroke = 0.35, colour = "white"
  ) +
  scale_fill_manual(values = palette, breaks = names(palette), drop = FALSE) +
  scale_x_log10(
    limits = c(0.1, 8),
    breaks = c(0.1, 0.25, 0.5, 1, 2, 4, 8),
    labels = c("0.1", "0.25", "0.5", "1", "2", "4", "8")
  ) +
  scale_y_continuous(limits = c(0.5, max(plot_dat$y) + 0.5), expand = c(0, 0)) +
  labs(title = "Hazard ratio (95% CI)", x = "HR per prespecified contrast", y = NULL) +
  base_theme +
  theme(plot.margin = margin(3, 2, 3, 2))

numeric_panel <- ggplot(plot_dat, aes(y = y)) +
  geom_text(
    data = plot_dat[!plot_dat$is_header, ],
    aes(x = 0, label = Estimate_text),
    hjust = 0, size = 2.2, colour = "#222222"
  ) +
  geom_text(
    data = plot_dat[!plot_dat$is_header, ],
    aes(x = 0.69, label = FDR_text),
    hjust = 0.5, size = 2.2, colour = "#222222"
  ) +
  geom_text(
    data = plot_dat[!plot_dat$is_header, ],
    aes(x = 0.93, label = Diagnostic_symbol),
    hjust = 1, size = 2.3, colour = "#7A3E00"
  ) +
  scale_x_continuous(limits = c(0, 1), expand = c(0, 0)) +
  scale_y_continuous(limits = c(0.5, max(plot_dat$y) + 0.5), expand = c(0, 0)) +
  labs(title = "HR (95% CI)       BH-FDR") +
  theme_void(base_family = "Arial") +
  theme(
    plot.title = element_text(face = "bold", size = 8, margin = margin(b = 3)),
    plot.margin = margin(3, 3, 3, 1)
  )

caption <- paste(
  "Separate univariable Cox models; N=504 and 84 deaths. Variable labels follow Table 1; contrasts and units are reported in Table S2.",
  "*BH-FDR<0.05; \u2020nominal proportional-hazards diagnostic P<0.05; \u2021nonlinearity likelihood-ratio P<0.05. Infection-source overall likelihood-ratio P=0.0038 (lung/chest reference).",
  "These estimates are descriptive, unadjusted and non-causal.",
  sep = "\n"
)

final_plot <- (label_panel + forest_panel + numeric_panel) +
  plot_layout(widths = c(3.25, 2.30, 2.05), guides = "collect") +
  plot_annotation(
    title = "Supplementary Figure A9 | Exploratory clinical univariable Cox analysis",
    subtitle = "Higher or lower subsequent 60-day mortality hazard per prespecified contrast",
    caption = caption,
    theme = theme(
      plot.title = element_text(family = "Arial", face = "bold", size = 10, hjust = 0),
      plot.subtitle = element_text(family = "Arial", size = 8, colour = "#444444", hjust = 0),
      plot.caption = element_text(family = "Arial", size = 6.5, hjust = 0, lineheight = 1.15),
      plot.margin = margin(6, 12, 9, 10)
    )
  ) & theme(legend.position = "bottom")

base <- file.path(
  root,
  "submission/figures/Supplementary_Figure_A9_clinical_univariable_Cox"
)
dir.create(dirname(base), recursive = TRUE, showWarnings = FALSE)
width_in <- 183 / 25.4
height_in <- 255 / 25.4

svglite::svglite(paste0(base, ".svg"), width = width_in, height = height_in)
print(final_plot)
dev.off()

grDevices::cairo_pdf(
  paste0(base, ".pdf"), width = width_in, height = height_in,
  family = "Arial"
)
print(final_plot)
dev.off()

ragg::agg_tiff(
  paste0(base, ".tiff"), width = width_in, height = height_in,
  units = "in", res = 600, background = "white", compression = "lzw"
)
print(final_plot)
dev.off()

ragg::agg_png(
  paste0(base, ".png"), width = width_in, height = height_in,
  units = "in", res = 300, background = "white"
)
print(final_plot)
dev.off()

message("Created Figure A9 and aggregate source data from: ", input_file)
