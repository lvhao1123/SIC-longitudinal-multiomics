# Construct controlled longitudinal annotation from an approved curated Day-1 workbook.
args <- commandArgs(trailingOnly=TRUE)
if (length(args) != 3L) stop("Usage: Rscript build_clinical_annotation.R RAW_CLINICAL_CSV CURATED_BASELINE_XLSX NEW_PRIVATE_OUTPUT_DIRECTORY")
raw_file <- args[1]; baseline_file <- args[2]; output_dir <- args[3]
if (dir.exists(output_dir)) stop("Output directory must not exist")
dir.create(output_dir, recursive=TRUE)
# Reproducible construction of SIC longitudinal clinical annotation
library(readr)
library(readxl)
library(dplyr)
library(stringr)

raw <- read_csv(raw_file, show_col_types = FALSE)
baseline <- read_excel(baseline_file)

baseline <- baseline %>%
  mutate(
    PatientID = str_remove(SampleName, "_d1$"),
    BaselineSampleName = SampleName
  )

# Baseline annotation for omics merging. These are Day1 covariates, not Day3/Day5 measurements.
annotation <- tidyr::crossing(
  PatientID = baseline$PatientID,
  day_num = c(1L, 3L, 5L)
) %>%
  mutate(SampleName = paste0(PatientID, "_d", day_num)) %>%
  left_join(
    baseline %>% select(-SampleName),
    by = "PatientID"
  ) %>%
  mutate(
    ClinicalDataNature = "Day1 baseline covariates carried forward for omics annotation"
  )

# Preserve raw longitudinal clinical values and append baseline values with a baseline_ prefix.
raw_cohort <- raw %>%
  mutate(
    PatientID = str_remove(SampleName, "_d[0-9]+$"),
    day_num = as.integer(str_extract(SampleName, "(?<=_d)[0-9]+$"))
  ) %>%
  filter(PatientID %in% baseline$PatientID, day_num %in% c(1L, 3L, 5L))

baseline_prefixed <- baseline %>%
  select(-BaselineSampleName) %>%
  rename_with(~ paste0("baseline_", .x), -PatientID)

raw_plus_baseline <- raw_cohort %>%
  left_join(baseline_prefixed, by = "PatientID")

write_csv(annotation, file.path(output_dir, "SIC_504_baseline_carried_forward_annotation.csv"))
write_csv(raw_plus_baseline, file.path(output_dir, "SIC_504_raw_clinical_plus_curated_baseline.csv"))
