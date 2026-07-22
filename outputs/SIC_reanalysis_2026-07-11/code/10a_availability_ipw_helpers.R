assert_avail_packages <- function(pkgs = c(
  "data.table", "dplyr", "tidyr", "stringr", "tibble", "survival",
  "fgsea", "future", "future.apply", "ggplot2", "detectseparation"
)) {
  missing <- pkgs[!vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)]
  if (length(missing)) stop("Missing R packages: ", paste(missing, collapse = ", "))
  invisible(TRUE)
}

derive_center <- function(patient_id) sub("_[^_]+$", "", patient_id)

prepare_availability_base <- function(clinical, logcpm_samples) {
  d <- clinical |>
    dplyr::mutate(
      day_num = as.integer(day_num),
      center = derive_center(PatientID),
      stop = as.numeric(surv_time),
      event = as.integer(sTatus)
    )
  base <- d |>
    dplyr::filter(day_num == 1L) |>
    dplyr::distinct(PatientID, .keep_all = TRUE)
  sample_map <- d |>
    dplyr::filter(SampleName %in% logcpm_samples) |>
    dplyr::transmute(PatientID, day_num, SampleName) |>
    dplyr::distinct()
  base |>
    dplyr::mutate(
      RNA_D3_available = as.integer(PatientID %in% sample_map$PatientID[sample_map$day_num == 3L]),
      RNA_D5_available = as.integer(PatientID %in% sample_map$PatientID[sample_map$day_num == 5L])
    )
}

build_entry_cohort <- function(entry, base, d5_rna_ids = NULL) {
  if (!is.null(d5_rna_ids)) {
    base$RNA_D5_available <- as.integer(base$PatientID %in% d5_rna_ids)
  }
  stopifnot(all(c("PatientID", "center", "stop", "event", "RNA_D5_available") %in% names(base)))
  risk <- base |>
    dplyr::mutate(entry = as.numeric(entry)) |>
    dplyr::filter(stop > entry)
  centres <- risk |>
    dplyr::group_by(center) |>
    dplyr::summarise(
      N = dplyr::n(), observed = sum(RNA_D5_available == 1L),
      unobserved = sum(RNA_D5_available == 0L), .groups = "drop"
    ) |>
    dplyr::mutate(class = dplyr::case_when(
      observed == 0L ~ "zero",
      unobserved == 0L ~ "all",
      TRUE ~ "partial"
    ))
  supported <- risk |>
    dplyr::left_join(centres[, c("center", "class")], by = "center") |>
    dplyr::filter(class != "zero") |>
    dplyr::mutate(
      center = factor(center),
      centre_class = factor(class, levels = c("partial", "all")),
      available = RNA_D5_available
    )
  counts <- tibble::tibble(
    entry = as.numeric(entry), source_N = nrow(base),
    structural_N = sum(base$stop <= entry), risk_N = nrow(risk),
    support_N = nrow(supported), observed_N = sum(supported$available == 1L),
    unobserved_N = sum(supported$available == 0L),
    observed_events = sum(supported$event[supported$available == 1L])
  )
  list(counts = counts, centres = centres, risk = risk, supported = supported)
}

audit_time_origin <- function(base, entries) {
  deaths <- base$event == 1L
  cens <- base$event == 0L
  tibble::tibble(
    statement = c(
      "surv_time provenance", "deaths", "censored", "event_over_60",
      "event_at_or_before_zero", "censored_not_60", "minimum_event_time",
      "maximum_event_time", paste0("structural_at_entry_", names(entries))
    ),
    value = c(
      "Hospital_days for deaths; administrative 60-day censoring for non-deaths",
      sum(deaths), sum(cens), sum(deaths & base$stop > 60),
      sum(deaths & base$stop <= 0), sum(cens & base$stop != 60),
      min(base$stop[deaths]), max(base$stop[deaths]),
      vapply(entries, function(e) sum(base$stop <= e), numeric(1))
    ),
    interpretation = c(
      "Nominal Day-1 study-time origin; exact sample timestamps are unavailable",
      rep("Audit value", 7),
      rep("Excluded from the corresponding delayed-entry risk set", length(entries))
    )
  )
}

audit_boundary_conflicts <- function(base, entries) {
  tidyr::crossing(PatientID = base$PatientID, entry_name = names(entries)) |>
    dplyr::left_join(base[, c("PatientID", "stop", "event", "RNA_D5_available")], by = "PatientID") |>
    dplyr::mutate(entry = entries[entry_name]) |>
    dplyr::filter(RNA_D5_available == 1L, stop <= entry) |>
    dplyr::arrange(entry, stop)
}

required_availability_vars <- c(
  "PatientID", "center", "stop", "event", "age", "sex", "SOFA", "pf",
  "lac", "plt", "inr", "ddimer", "infectionSite_SD", "RNA_D3_available",
  "RNA_D5_available"
)

audit_missingness <- function(d, entry_name) {
  absent <- setdiff(required_availability_vars, names(d))
  if (length(absent)) stop("Missing required columns: ", paste(absent, collapse = ", "))
  tibble::tibble(
    entry = entry_name,
    variable = required_availability_vars,
    missing_N = vapply(d[required_availability_vars], function(x) sum(is.na(x) | (is.character(x) & trimws(x) == "")), integer(1)),
    total_N = nrow(d)
  )
}

audit_protein_nesting <- function(protein_qc, base, entry = 4) {
  ids <- split(protein_qc$PatientID, protein_qc$Time)
  ids <- lapply(ids, unique)
  d5_valid <- intersect(ids$D5, base$PatientID[base$stop > entry])
  tibble::tibble(
    D1_N = length(ids$D1), D3_N = length(ids$D3), D5_N = length(ids$D5),
    D3_not_D1 = length(setdiff(ids$D3, ids$D1)),
    D5_not_D1 = length(setdiff(ids$D5, ids$D1)),
    D5_not_D3 = length(setdiff(ids$D5, ids$D3)),
    D5_risk_valid_N = length(d5_valid),
    D5_post_entry_events = sum(base$event[match(d5_valid, base$PatientID)])
  )
}

safe_z_constants <- function(x) {
  x <- as.numeric(x)
  c(mean = mean(x), sd = stats::sd(x))
}

transform_availability_covariates <- function(target, constants = NULL) {
  partial <- target[target$centre_class == "partial", , drop = FALSE]
  source <- if (is.null(constants)) partial else target
  raw <- list(
    age_z = source$age,
    SOFA_z = source$SOFA,
    pf_z = source$pf,
    log2_lac_z = log2(source$lac),
    log2_plt_z = log2(source$plt),
    log2_inr_z = log2(source$inr),
    log2_ddimer_z = log2(source$ddimer)
  )
  if (any(!is.finite(unlist(raw)))) stop("Non-finite transformed availability covariates")
  if (is.null(constants)) {
    constants <- do.call(rbind, lapply(raw, safe_z_constants))
    if (any(!is.finite(constants)) || any(constants[, "sd"] <= 0)) stop("Invalid transformation constants")
  }
  full_raw <- list(
    age_z = as.numeric(target$age), SOFA_z = as.numeric(target$SOFA), pf_z = as.numeric(target$pf),
    log2_lac_z = log2(as.numeric(target$lac)), log2_plt_z = log2(as.numeric(target$plt)),
    log2_inr_z = log2(as.numeric(target$inr)), log2_ddimer_z = log2(as.numeric(target$ddimer))
  )
  out <- target
  for (nm in names(full_raw)) out[[nm]] <- (full_raw[[nm]] - constants[nm, "mean"]) / constants[nm, "sd"]
  out$sex <- factor(out$sex)
  out$infectionSite_SD <- factor(out$infectionSite_SD)
  out$center <- factor(out$center)
  attr(out, "transform_constants") <- constants
  out
}

build_availability_formula <- function(spec) {
  stopifnot(spec %in% c("SOFA_D3", "SOFA_noD3", "PF_PLT_D3", "PF_PLT_noD3"))
  severity <- if (grepl("^SOFA", spec)) "SOFA_z" else "pf_z + log2_plt_z"
  d3 <- if (grepl("_D3$", spec)) " + RNA_D3_available" else ""
  stats::as.formula(paste0(
    "available ~ age_z + sex + ", severity,
    " + log2_lac_z + log2_inr_z + log2_ddimer_z + infectionSite_SD + center", d3
  ))
}

factor_zero_cell_audit <- function(d, vars, outcome = "available") {
  out <- lapply(vars, function(v) {
    tab <- as.data.frame(table(level = d[[v]], outcome = d[[outcome]], useNA = "ifany"))
    names(tab)[3] <- "N"
    tab$variable <- v
    tab
  })
  dplyr::bind_rows(out) |>
    dplyr::select(variable, level, outcome, N)
}

prefit_availability_audit <- function(target_transformed, spec) {
  partial <- droplevels(target_transformed[target_transformed$centre_class == "partial", , drop = FALSE])
  form <- build_availability_formula(spec)
  mm <- stats::model.matrix(form, data = partial)
  sep_fit <- stats::glm(form, data = partial, family = stats::binomial(), method = detectseparation::detect_separation)
  sep_coef <- stats::coef(sep_fit)
  separated <- any(is.infinite(sep_coef))
  factors <- c("sex", "infectionSite_SD", "center")
  if (grepl("_D3$", spec)) factors <- c(factors, "RNA_D3_available")
  list(
    summary = tibble::tibble(
      spec = spec, N = nrow(partial), observed = sum(partial$available == 1L),
      unobserved = sum(partial$available == 0L), parameters = ncol(mm),
      rank = qr(mm)$rank, rank_deficient = qr(mm)$rank < ncol(mm),
      separation = separated
    ),
    zero_cells = factor_zero_cell_audit(partial, factors),
    model_matrix = mm,
    formula = form,
    separation_coefficients = sep_coef
  )
}

weighted_mean_var <- function(x, w) {
  ok <- is.finite(x) & is.finite(w) & w > 0
  m <- stats::weighted.mean(x[ok], w[ok])
  v <- sum(w[ok] * (x[ok] - m)^2) / sum(w[ok])
  c(mean = m, var = v)
}

weighted_smd <- function(target, weight_data, variables) {
  obs <- weight_data[weight_data$available == 1L, , drop = FALSE]
  rows <- list()
  add_numeric <- function(v, label = v, x_target = target[[v]], x_obs = obs[[v]]) {
    mt <- mean(x_target); vt <- stats::var(x_target)
    un <- weighted_mean_var(x_obs, rep(1, length(x_obs)))
    wt <- weighted_mean_var(x_obs, obs$analysis_weight)
    den_un <- sqrt((un["var"] + vt) / 2)
    den_wt <- sqrt((wt["var"] + vt) / 2)
    tibble::tibble(variable = label,
      SMD_before = as.numeric((un["mean"] - mt) / den_un),
      SMD_after = as.numeric((wt["mean"] - mt) / den_wt))
  }
  for (v in variables) {
    if (is.factor(target[[v]]) || is.character(target[[v]])) {
      levs <- union(unique(as.character(target[[v]])), unique(as.character(obs[[v]])))
      for (lev in levs) rows[[length(rows) + 1L]] <- add_numeric(
        v, paste0(v, "=", lev), as.numeric(as.character(target[[v]]) == lev),
        as.numeric(as.character(obs[[v]]) == lev)
      )
    } else rows[[length(rows) + 1L]] <- add_numeric(v)
  }
  dplyr::bind_rows(rows)
}

fit_observation_weights <- function(target, spec) {
  z <- transform_availability_covariates(target)
  prefit <- prefit_availability_audit(z, spec)
  if (prefit$summary$rank_deficient) stop("Rank-deficient availability model: ", spec)
  if (prefit$summary$separation) stop("Separated availability model: ", spec)
  partial <- droplevels(z[z$centre_class == "partial", , drop = FALSE])
  warnings <- character()
  fit <- withCallingHandlers(
    stats::glm(prefit$formula, data = partial, family = stats::binomial()),
    warning = function(w) { warnings <<- c(warnings, conditionMessage(w)); invokeRestart("muffleWarning") }
  )
  if (!isTRUE(fit$converged)) stop("Availability model did not converge: ", spec)
  p_partial <- stats::predict(fit, newdata = partial, type = "response")
  if (any(!is.finite(p_partial)) || any(p_partial <= 0 | p_partial > 1)) stop("Invalid availability probabilities: ", spec)
  z$raw_probability <- NA_real_
  z$raw_probability[z$centre_class == "all"] <- 1
  z$raw_probability[match(partial$PatientID, z$PatientID)] <- p_partial
  z$raw_weight <- ifelse(z$available == 1L, 1 / z$raw_probability, NA_real_)
  if (any(!is.finite(z$raw_weight[z$available == 1L]))) stop("Invalid inverse weights: ", spec)
  qs <- stats::quantile(z$raw_weight[z$available == 1L], c(.01, .99), names = FALSE, type = 7)
  z$trimmed_weight <- ifelse(z$available == 1L, pmin(pmax(z$raw_weight, qs[1]), qs[2]), NA_real_)
  z$analysis_weight <- z$trimmed_weight / mean(z$trimmed_weight[z$available == 1L])
  vars <- all.vars(prefit$formula)[-1L]
  balance <- weighted_smd(z, z, vars)
  ow <- z$analysis_weight[z$available == 1L]
  diag <- tibble::tibble(
    spec = spec, min_probability = min(z$raw_probability[z$centre_class == "partial"]),
    max_probability = max(z$raw_probability[z$centre_class == "partial"]),
    max_raw_weight = max(z$raw_weight, na.rm = TRUE), trim_p01 = qs[1], trim_p99 = qs[2],
    analysis_weight_mean = mean(ow), analysis_weight_min = min(ow), analysis_weight_max = max(ow),
    ESS = sum(ow)^2 / sum(ow^2), observed_N = length(ow),
    ESS_ratio = (sum(ow)^2 / sum(ow^2)) / length(ow),
    max_abs_SMD_before = max(abs(balance$SMD_before), na.rm = TRUE),
    max_abs_SMD_after = max(abs(balance$SMD_after), na.rm = TRUE),
    caution_min_p = min_probability < .01, caution_max_raw_weight = max_raw_weight > 20,
    caution_ESS = ESS_ratio < .50, caution_balance = max_abs_SMD_after > .10,
    warnings = paste(unique(warnings), collapse = " | ")
  )
  list(data = z, fit = fit, prefit = prefit, balance = balance, diagnostics = diag,
       transform_constants = attr(z, "transform_constants"))
}

fit_weighted_gene <- function(gene, values, metadata, run_ph = FALSE) {
  d <- metadata
  d$gene_z <- as.numeric(scale(values))
  warnings <- character()
  # survival::coxph requires cluster/id when robust=TRUE is combined with a
  # counting-process Surv response. The frozen design explicitly forbids id.
  # We therefore fit the identical weighted delayed-entry partial likelihood
  # and calculate the individual-observation Lin-Wei sandwich SE directly
  # from weighted dfbeta residuals. This is numerically identical to adding a
  # unique row cluster, without introducing cluster/id into the model call.
  fit <- tryCatch(withCallingHandlers(
    survival::coxph(
      survival::Surv(entry, stop, event) ~ gene_z + strata(center),
      data = d, weights = analysis_weight, ties = "efron", robust = FALSE,
      x = TRUE, y = TRUE, control = survival::coxph.control(iter.max = 50, eps = 1e-9)
    ), warning = function(w) { warnings <<- c(warnings, conditionMessage(w)); invokeRestart("muffleWarning") }
  ), error = function(e) e)
  empty <- tibble::tibble(
    gene_symbol = gene, beta = NA_real_, HR = NA_real_, robust_SE = NA_real_,
    z = NA_real_, pval = NA_real_, converged = FALSE, finite_beta = FALSE,
    finite_robust_SE = FALSE, fit_valid = FALSE, warning_text = paste(warnings, collapse = " | "),
    error_text = if (inherits(fit, "error")) conditionMessage(fit) else "",
    PH_attempted = run_ph, PH_success = FALSE, PH_p = NA_real_
  )
  if (inherits(fit, "error")) return(empty)
  sm <- summary(fit)$coefficients
  if (!("gene_z" %in% rownames(sm))) return(empty)
  beta <- unname(sm["gene_z", "coef"])
  dfbeta <- tryCatch(stats::residuals(fit, type = "dfbeta", weighted = TRUE), error = function(e) numeric())
  se <- if (length(dfbeta)) sqrt(sum(as.numeric(dfbeta)^2)) else NA_real_
  z <- beta / se
  conv <- !any(grepl("converg|infinite", warnings, ignore.case = TRUE))
  ph_success <- FALSE; ph_p <- NA_real_
  if (run_ph && conv && is.finite(z)) {
    ph <- tryCatch(survival::cox.zph(fit, transform = "km"), error = function(e) e)
    if (!inherits(ph, "error")) {
      ph_p <- as.numeric(ph$table["gene_z", "p"])
      ph_success <- is.finite(ph_p)
    }
  }
  tibble::tibble(
    gene_symbol = gene, beta = beta, HR = exp(beta), robust_SE = se, z = z,
    pval = 2 * stats::pnorm(-abs(z)), converged = conv,
    finite_beta = is.finite(beta), finite_robust_SE = is.finite(se) && se > 0,
    fit_valid = conv && is.finite(beta) && is.finite(se) && se > 0 && is.finite(z),
    warning_text = paste(unique(warnings), collapse = " | "), error_text = "",
    PH_attempted = run_ph, PH_success = ph_success, PH_p = ph_p
  )
}

run_weighted_cox_matrix <- function(expr_gene_by_sample, metadata, run_ph = FALSE, workers = 3L) {
  stopifnot(all(metadata$SampleName %in% colnames(expr_gene_by_sample)))
  expr <- expr_gene_by_sample[, metadata$SampleName, drop = FALSE]
  genes <- rownames(expr)
  future::plan(future::multisession, workers = workers)
  on.exit(future::plan(future::sequential), add = TRUE)
  ans <- future.apply::future_lapply(seq_along(genes), function(i) {
    fit_weighted_gene(genes[i], expr[i, ], metadata, run_ph = run_ph)
  }, future.seed = TRUE, future.packages = "survival")
  dplyr::bind_rows(ans) |>
    dplyr::mutate(padj = stats::p.adjust(pval, method = "BH"))
}

run_weighted_gsea <- function(cox, hallmark, analysis_label, seed = 20260712) {
  ranks_tbl <- cox |>
    dplyr::filter(fit_valid, is.finite(z)) |>
    dplyr::arrange(dplyr::desc(abs(z))) |>
    dplyr::distinct(gene_symbol, .keep_all = TRUE)
  ranks <- sort(stats::setNames(ranks_tbl$z, ranks_tbl$gene_symbol), decreasing = TRUE)
  set.seed(seed)
  ans <- fgsea::fgseaMultilevel(
    pathways = hallmark, stats = ranks, sampleSize = 1001, nPermSimple = 10000,
    minSize = 15, maxSize = 500, eps = 0, scoreType = "std", nproc = 1
  ) |>
    tibble::as_tibble() |>
    dplyr::mutate(
      analysis = analysis_label,
      direction = dplyr::if_else(NES > 0, "positive-risk", "negative-risk"),
      leadingEdge_text = vapply(leadingEdge, paste, collapse = ";", FUN.VALUE = character(1))
    )
  ans
}

jaccard_text <- function(a, b) {
  aa <- setdiff(strsplit(ifelse(is.na(a), "", a), ";", fixed = TRUE)[[1]], "")
  bb <- setdiff(strsplit(ifelse(is.na(b), "", b), ";", fixed = TRUE)[[1]], "")
  if (!length(union(aa, bb))) return(NA_real_)
  length(intersect(aa, bb)) / length(union(aa, bb))
}

compare_hallmark_all <- function(unweighted, weighted) {
  out <- dplyr::full_join(
    unweighted |>
      dplyr::transmute(pathway, NES_unweighted = NES, FDR_unweighted = padj,
                       leadingEdge_unweighted = leadingEdge_text),
    weighted |>
      dplyr::transmute(pathway, NES_weighted = NES, FDR_weighted = padj,
                       leadingEdge_weighted = leadingEdge_text),
    by = "pathway"
  ) |>
    dplyr::mutate(
      delta_NES = NES_weighted - NES_unweighted,
      direction_agreement = sign(NES_unweighted) == sign(NES_weighted),
      FDR_class = dplyr::case_when(
        FDR_unweighted < .05 & FDR_weighted < .05 ~ "both",
        FDR_unweighted < .05 ~ "unweighted_only",
        FDR_weighted < .05 ~ "IPW_only",
        TRUE ~ "neither"
      ),
      leading_edge_jaccard = mapply(jaccard_text, leadingEdge_unweighted, leadingEdge_weighted)
    )
  attr(out, "metrics") <- tibble::tibble(
    spearman_NES = stats::cor(out$NES_unweighted, out$NES_weighted, method = "spearman", use = "complete.obs"),
    direction_agreement = mean(out$direction_agreement, na.rm = TRUE),
    significant_set_jaccard = {
      a <- out$pathway[out$FDR_unweighted < .05]
      b <- out$pathway[out$FDR_weighted < .05]
      length(intersect(a, b)) / length(union(a, b))
    }
  )
  out
}
