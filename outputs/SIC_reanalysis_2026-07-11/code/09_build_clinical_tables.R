rm(list = ls())
source("outputs/SIC_reanalysis_2026-07-11/code/00_config.R")
suppressPackageStartupMessages({library(data.table); library(dplyr); library(tidyr); library(stringr); library(tibble); library(survival); library(splines)})
set.seed(20260712)

CLIN_OUT <- file.path(OUT_ROOT, "05_Clinical_Tables")
dir.create(CLIN_OUT, recursive = TRUE, showWarnings = FALSE)

dat <- fread(INPUT$clinical, data.table = FALSE) |>
  filter(day_num == 1) |>
  distinct(PatientID, .keep_all = TRUE) |>
  mutate(
    Outcome60 = factor(sTatus, levels = c(0, 1), labels = c("Survivor/censored", "Death")),
    infectionSite_SD = factor(infectionSite_SD),
    surv_time = as.numeric(surv_time), sTatus = as.integer(sTatus)
  )
stopifnot(nrow(dat) == 504, sum(dat$sTatus) == 84)

# Recover two clinically important baseline variables retained in the original
# CMAISE annotation but not copied into the reduced SIC annotation. The join is
# one-to-one by D1 SampleName and is audited below.
raw_d1 <- fread(INPUT$raw_clinical, data.table = FALSE) |>
  dplyr::select(SampleName, sex_raw = sex, site_raw = infectionSite_SD,
                Hospital_days, ca, pha) |>
  distinct(SampleName, .keep_all = TRUE)
dat <- left_join(dat, raw_d1, by = "SampleName")
stopifnot(nrow(dat) == 504, !any(is.na(dat$sex_raw)),
          all((dat$sex == 1) == (dat$sex_raw == "M")))

continuous <- tribble(
  ~variable, ~label, ~unit, ~increment,
  "age", "Age", "years", 10,
  "height", "Height", "cm", 10,
  "weight", "Weight", "kg", 10,
  "BMI", "Body mass index", "kg/m^2", 5,
  "hrmax", "Maximum heart rate", "beats/min", 10,
  "mapmax", "Maximum mean arterial pressure", "mmHg", 10,
  "sapmax", "Maximum systolic arterial pressure", "mmHg", 10,
  "rrmax", "Maximum respiratory rate", "breaths/min", 5,
  "tmax", "Maximum temperature", "degrees C", 1,
  "lac", "Lactate", "mmol/L", 1,
  "k", "Potassium", "mmol/L", 1,
  "na", "Sodium", "mmol/L", 5,
  "cl", "Chloride", "mmol/L", 5,
  "bun", "Blood urea nitrogen", "mg/dL", 5,
  "alb", "Albumin", "g/L", 5,
  "cr", "Creatinine", "micromol/L", 50,
  "bilirubin", "Bilirubin", "micromol/L", 10,
  "crp", "C-reactive protein", "mg/L", 10,
  "procal", "Procalcitonin", "ng/mL", 1,
  "wbc", "White blood cell count", "10^9/L", 1,
  "plt", "Platelet count", "10^9/L", 50,
  "inr", "International normalized ratio", "ratio", .5,
  "aptt", "Activated partial thromboplastin time", "seconds", 5,
  "ddimer", "D-dimer", "microg/mL", 1,
  "SOFA", "SOFA score", "points", 1,
  "pf", "PaO2/FiO2 ratio", "mmHg", 50
)

binary <- tribble(
  ~variable, ~label,
  "sex", "Male sex",
  "diabete", "Diabetes mellitus",
  "hyperten", "Hypertension",
  "myoinfarc", "Myocardial infarction",
  "cardiofailure", "Heart failure",
  "cerebrovasc", "Cerebrovascular disease",
  "dementia", "Dementia",
  "copd", "Chronic obstructive pulmonary disease",
  "paralysis", "Paralysis",
  "renafailure", "Renal failure"
)

fmt_cont <- function(x) {
  if (sum(is.finite(x)) == 0) return(NA_character_)
  q <- quantile(x, c(.25, .5, .75), na.rm = TRUE, names = FALSE)
  sprintf("%.2f [%.2f, %.2f]", q[2], q[1], q[3])
}
fmt_cat <- function(x, level, denom) {
  n <- sum(x == level, na.rm = TRUE)
  sprintf("%d (%.1f%%)", n, 100 * n / denom)
}
continuous_smd <- function(x, g) {
  a <- x[g == 0]; b <- x[g == 1]
  (mean(b, na.rm = TRUE) - mean(a, na.rm = TRUE)) /
    sqrt((var(a, na.rm = TRUE) + var(b, na.rm = TRUE)) / 2)
}
binary_smd <- function(x, g) {
  p0 <- mean(x[g == 0] == 1, na.rm = TRUE); p1 <- mean(x[g == 1] == 1, na.rm = TRUE)
  den <- sqrt((p0 * (1 - p0) + p1 * (1 - p1)) / 2)
  ifelse(den > 0, (p1 - p0) / den, NA_real_)
}

table1_cont <- bind_rows(lapply(seq_len(nrow(continuous)), function(i) {
  v <- continuous$variable[i]; x <- as.numeric(dat[[v]])
  tibble(
    Section = "Continuous variables", Variable = continuous$label[i], Level = "",
    Unit = continuous$unit[i], Overall = fmt_cont(x),
    `Survivor/censored` = fmt_cont(x[dat$sTatus == 0]), Death = fmt_cont(x[dat$sTatus == 1]),
    Missing_overall = sum(is.na(x)), Missing_survivor = sum(is.na(x[dat$sTatus == 0])),
    Missing_death = sum(is.na(x[dat$sTatus == 1])), SMD = continuous_smd(x, dat$sTatus),
    P_value = suppressWarnings(wilcox.test(x ~ dat$sTatus, exact = FALSE)$p.value)
  )
}))

table1_bin <- bind_rows(lapply(seq_len(nrow(binary)), function(i) {
  v <- binary$variable[i]; x <- as.numeric(dat[[v]])
  tibble(
    Section = "Binary variables", Variable = binary$label[i], Level = "1 vs 0", Unit = "n (%)",
    Overall = fmt_cat(x, 1, sum(!is.na(x))),
    `Survivor/censored` = fmt_cat(x[dat$sTatus == 0], 1, sum(!is.na(x[dat$sTatus == 0]))),
    Death = fmt_cat(x[dat$sTatus == 1], 1, sum(!is.na(x[dat$sTatus == 1]))),
    Missing_overall = sum(is.na(x)), Missing_survivor = sum(is.na(x[dat$sTatus == 0])),
    Missing_death = sum(is.na(x[dat$sTatus == 1])), SMD = binary_smd(x, dat$sTatus),
    P_value = suppressWarnings(fisher.test(table(x, dat$sTatus))$p.value)
  )
}))

infection_levels <- levels(dat$infectionSite_SD)
infection_p <- suppressWarnings(fisher.test(table(dat$infectionSite_SD, dat$sTatus), simulate.p.value = TRUE, B = 100000)$p.value)
table1_inf <- bind_rows(lapply(seq_along(infection_levels), function(i) {
  lev <- infection_levels[i]; x <- dat$infectionSite_SD
  z <- as.integer(x == lev)
  tibble(
    Section = "Infection source", Variable = ifelse(i == 1, "Infection source", ""), Level = lev, Unit = "n (%)",
    Overall = fmt_cat(x, lev, sum(!is.na(x))),
    `Survivor/censored` = fmt_cat(x[dat$sTatus == 0], lev, sum(!is.na(x[dat$sTatus == 0]))),
    Death = fmt_cat(x[dat$sTatus == 1], lev, sum(!is.na(x[dat$sTatus == 1]))),
    Missing_overall = ifelse(i == 1, sum(is.na(x)), NA_integer_),
    Missing_survivor = ifelse(i == 1, sum(is.na(x[dat$sTatus == 0])), NA_integer_),
    Missing_death = ifelse(i == 1, sum(is.na(x[dat$sTatus == 1])), NA_integer_),
    SMD = binary_smd(z, dat$sTatus), P_value = ifelse(i == 1, infection_p, NA_real_)
  )
}))

table1 <- bind_rows(table1_cont, table1_bin, table1_inf)
fwrite(table1, file.path(CLIN_OUT, "Table1_baseline_characteristics.csv"))

fit_continuous <- function(v, label, unit, increment) {
  x <- as.numeric(dat[[v]]) / increment
  d <- data.frame(time = dat$surv_time, event = dat$sTatus, x = x)
  d <- d[complete.cases(d), ]
  fit <- coxph(Surv(time, event) ~ x, data = d, ties = "efron", x = TRUE, y = TRUE)
  sm <- summary(fit); zph <- cox.zph(fit, transform = "km", terms = FALSE)
  linear_fit <- fit
  spline_fit <- tryCatch(coxph(Surv(time, event) ~ ns(x, df = 3), data = d, ties = "efron"), error = function(e) NULL)
  nonlinear_p <- if (!is.null(spline_fit)) {
    ll0 <- logLik(linear_fit); ll1 <- logLik(spline_fit)
    pchisq(2 * (as.numeric(ll1) - as.numeric(ll0)),
           df = attr(ll1, "df") - attr(ll0, "df"), lower.tail = FALSE)
  } else NA_real_
  tibble(
    Variable = v, Label = label, Type = "continuous", Contrast = paste0("per ", increment, " ", unit),
    Reference = NA_character_, N = nrow(d), Events = sum(d$event),
    HR = unname(sm$conf.int[1, "exp(coef)"]), Lower95 = unname(sm$conf.int[1, "lower .95"]),
    Upper95 = unname(sm$conf.int[1, "upper .95"]), P_value = unname(sm$coefficients[1, "Pr(>|z|)"]),
    PH_p = unname(zph$table[1, "p"]), Nonlinearity_LRT_p = nonlinear_p,
    Sparse_event_flag = FALSE, Zero_event_flag = FALSE,
    Note = if (isTRUE(nonlinear_p < .05)) "Nonlinear association suggested; consider restricted cubic spline" else ""
  )
}

fit_binary <- function(v, label) {
  x <- factor(dat[[v]], levels = c(0, 1))
  d <- data.frame(time = dat$surv_time, event = dat$sTatus, x = x)
  d <- d[complete.cases(d), ]; tab <- table(d$x, d$event)
  fit <- coxph(Surv(time, event) ~ x, data = d, ties = "efron", x = TRUE, y = TRUE)
  sm <- summary(fit); zph <- tryCatch(cox.zph(fit, transform = "km"), error = function(e) NULL)
  deaths1 <- if ("1" %in% rownames(tab)) tab["1", "1"] else 0
  tibble(
    Variable = v, Label = label, Type = "binary", Contrast = "1 vs 0", Reference = "0",
    N = nrow(d), Events = sum(d$event), HR = unname(sm$conf.int[1, "exp(coef)"]),
    Lower95 = unname(sm$conf.int[1, "lower .95"]), Upper95 = unname(sm$conf.int[1, "upper .95"]),
    P_value = unname(sm$coefficients[1, "Pr(>|z|)"]), PH_p = ifelse(is.null(zph), NA_real_, zph$table[1, "p"]),
    Nonlinearity_LRT_p = NA_real_, Sparse_event_flag = deaths1 < 5, Zero_event_flag = deaths1 == 0,
    Note = ifelse(deaths1 < 5, "Sparse exposed-group events; ordinary Cox estimate may be unstable", "")
  )
}

cox_cont <- bind_rows(lapply(seq_len(nrow(continuous)), function(i)
  fit_continuous(continuous$variable[i], continuous$label[i], continuous$unit[i], continuous$increment[i])))
cox_bin <- bind_rows(lapply(seq_len(nrow(binary)), function(i)
  fit_binary(binary$variable[i], binary$label[i])))

# Infection source is analysed as one categorical factor with Lung/Chest as the preferred reference.
ref <- if ("Lung/Chest" %in% levels(dat$infectionSite_SD)) "Lung/Chest" else names(which.max(table(dat$infectionSite_SD)))
dinf <- data.frame(time = dat$surv_time, event = dat$sTatus,
                   site = relevel(droplevels(dat$infectionSite_SD), ref = ref))
dinf <- dinf[complete.cases(dinf), , drop = FALSE]
fit_inf <- coxph(Surv(time, event) ~ site, data = dinf, ties = "efron", x = TRUE, y = TRUE)
sm_inf <- summary(fit_inf); zph_inf <- tryCatch(cox.zph(fit_inf, transform = "km", terms = FALSE), error = function(e) NULL)
fit_inf0 <- coxph(Surv(time, event) ~ 1, data = dinf, ties = "efron")
ll0_inf <- logLik(fit_inf0); ll1_inf <- logLik(fit_inf)
overall_inf_p <- pchisq(2 * (as.numeric(ll1_inf) - as.numeric(ll0_inf)),
                       df = attr(ll1_inf, "df") - attr(ll0_inf, "df"),
                       lower.tail = FALSE)
inf_tab <- table(dinf$site, dinf$event)
cox_inf <- bind_rows(lapply(seq_len(nrow(sm_inf$coefficients)), function(i) {
  term <- rownames(sm_inf$coefficients)[i]; lev <- str_remove(term, "^site")
  deaths <- if (lev %in% rownames(inf_tab)) inf_tab[lev, "1"] else NA_integer_
  tibble(
    Variable = "infectionSite_SD", Label = "Infection source", Type = "categorical",
    Contrast = paste0(lev, " vs ", ref), Reference = ref, N = nrow(dinf), Events = sum(dinf$event),
    HR = unname(sm_inf$conf.int[i, "exp(coef)"]), Lower95 = unname(sm_inf$conf.int[i, "lower .95"]),
    Upper95 = unname(sm_inf$conf.int[i, "upper .95"]), P_value = unname(sm_inf$coefficients[i, "Pr(>|z|)"]),
    # cox.zph tests a multi-level factor as one term; repeat that factor-level
    # diagnostic beside each displayed contrast rather than indexing contrasts.
    PH_p = ifelse(is.null(zph_inf), NA_real_, zph_inf$table[1, "p"]), Nonlinearity_LRT_p = NA_real_,
    Sparse_event_flag = deaths < 5, Zero_event_flag = deaths == 0,
    Note = ifelse(deaths < 5, "Sparse level events; consider Firth Cox sensitivity", "")
  )
}))

cox <- bind_rows(cox_cont, cox_bin, cox_inf) |>
  mutate(BH_FDR = p.adjust(P_value, "BH"), PH_BH_FDR = p.adjust(PH_p, "BH"),
         Overall_factor_LRT_p = ifelse(Variable == "infectionSite_SD", overall_inf_p, NA_real_)) |>
  relocate(BH_FDR, .after = P_value)
fwrite(cox, file.path(CLIN_OUT, "Clinical_univariable_Cox.csv"))

sparse <- bind_rows(lapply(c(binary$variable, "infectionSite_SD"), function(v) {
  x <- dat[[v]]
  as.data.frame(table(Level = x, Event = dat$sTatus, useNA = "ifany")) |>
    pivot_wider(names_from = Event, values_from = Freq, values_fill = 0, names_prefix = "event_") |>
    mutate(Variable = v, Total = rowSums(across(starts_with("event_"))),
           Sparse_deaths = event_1 < 5, Zero_deaths = event_1 == 0) |>
    relocate(Variable)
}))
fwrite(sparse, file.path(CLIN_OUT, "Clinical_sparse_event_audit.csv"))

# Preserve raw-to-analysis provenance for the infection-source grouping and
# the manually cleaned event-time field.
site_mapping <- dat |>
  count(site_raw, site_final = infectionSite_SD, name = "N") |>
  arrange(site_final, site_raw)
fwrite(site_mapping, file.path(CLIN_OUT, "Clinical_infection_source_mapping.csv"))

outcome_audit <- dat |>
  transmute(
    SampleName, PatientID, event = sTatus, mort_flg,
    Hospital_days_raw = Hospital_days, surv_time_analysis = surv_time,
    Expected_from_rule = ifelse(sTatus == 1, Hospital_days, 60),
    Manual_time_discrepancy = abs(surv_time - Expected_from_rule) > 1e-8
  )
fwrite(outcome_audit, file.path(CLIN_OUT, "Clinical_outcome_time_provenance_audit.csv"))

# pH and calcium are retained only in a missingness/provenance audit, following
# the prespecified decision not to include partially missing variables in the
# formal clinical Cox table.
excluded_missing <- tibble(
  Variable = c("pha", "ca"),
  Label = c("Arterial pH", "Calcium"),
  Missing_N = c(sum(is.na(dat$pha)), sum(is.na(dat$ca))),
  Missing_percent = 100 * Missing_N / nrow(dat),
  Formal_Cox_included = FALSE,
  Reason = "Prespecified exclusion because of missing baseline observations"
)
fwrite(excluded_missing, file.path(CLIN_OUT, "Clinical_excluded_missing_variables.csv"))

# Sensitivity audit: exclude the five records whose cleaned event time differs
# from raw Hospital_days. This does not validate the corrections; it quantifies
# whether the clinical conclusions hinge on them.
dat_main <- dat
dat <- dat_main |> filter(!SampleName %in% outcome_audit$SampleName[outcome_audit$Manual_time_discrepancy])
cox_cont_drop5 <- bind_rows(lapply(seq_len(nrow(continuous)), function(i)
  fit_continuous(continuous$variable[i], continuous$label[i], continuous$unit[i], continuous$increment[i])))
cox_bin_drop5 <- bind_rows(lapply(seq_len(nrow(binary)), function(i)
  fit_binary(binary$variable[i], binary$label[i])))
dat <- dat_main

drop5 <- bind_rows(cox_cont_drop5, cox_bin_drop5) |>
  dplyr::select(Variable, HR_drop5 = HR, P_drop5 = P_value) |>
  left_join(cox |> filter(Variable != "infectionSite_SD") |>
              dplyr::select(Variable, HR_main = HR, P_main = P_value, BH_FDR_main = BH_FDR),
            by = "Variable") |>
  mutate(
    HR_ratio_drop5_to_main = HR_drop5 / HR_main,
    Direction_consistent = sign(log(HR_drop5)) == sign(log(HR_main))
  )
fwrite(drop5, file.path(CLIN_OUT, "Clinical_drop5_event_time_sensitivity.csv"))

dictionary <- bind_rows(
  continuous |> mutate(Type = "continuous", Coding = paste0("Cox HR ", "per ", increment, " ", unit)) |>
    select(Variable = variable, Label = label, Type, Unit = unit, Coding),
  binary |> mutate(Type = "binary", Unit = "0/1", Coding = "1 vs 0") |>
    select(Variable = variable, Label = label, Type, Unit, Coding),
  tibble(Variable = "infectionSite_SD", Label = "Infection source", Type = "categorical", Unit = "category",
         Coding = paste0("Reference: ", ref))
)
fwrite(dictionary, file.path(CLIN_OUT, "Clinical_variable_dictionary.csv"))

diagnostics <- tibble(
  Metric = c("Patients", "Deaths", "Survivors/censored", "Continuous variables", "Binary variables",
             "Cox rows", "Nominal Cox P<0.05", "Cox BH-FDR<0.05", "Nominal PH P<0.05", "Sparse-event rows",
             "Author-confirmed event-time corrections", "Sex mapping verified (1=male)"),
  Value = c(nrow(dat), sum(dat$sTatus), sum(dat$sTatus == 0), nrow(continuous), nrow(binary), nrow(cox),
            sum(cox$P_value < .05, na.rm = TRUE), sum(cox$BH_FDR < .05, na.rm = TRUE),
            sum(cox$PH_p < .05, na.rm = TRUE), sum(cox$Sparse_event_flag, na.rm = TRUE),
            sum(outcome_audit$Manual_time_discrepancy), TRUE)
)
fwrite(diagnostics, file.path(CLIN_OUT, "Clinical_analysis_diagnostics.csv"))
writeLines(capture.output(sessionInfo()), file.path(CLIN_OUT, "sessionInfo_Clinical.txt"))
