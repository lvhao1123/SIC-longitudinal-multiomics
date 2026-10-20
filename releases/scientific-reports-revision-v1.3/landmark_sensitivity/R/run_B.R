args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 1L) stop("Usage: Rscript run_B.R OUTPUT_DIRECTORY")
script_arg <- grep("^--file=", commandArgs(FALSE), value=TRUE)
SCRIPT_DIR <- dirname(normalizePath(sub("^--file=", "", script_arg[[1]]), winslash="/", mustWork=TRUE))
source(file.path(SCRIPT_DIR, "common.R"), encoding="UTF-8")

main_B <- function() {
  log_con <- start_log("B")
  on.exit(end_log(log_con), add = TRUE)
  on.exit(writeLines(capture.output(sessionInfo()),
                     file.path(ROOT, "logs", "B_sessionInfo.txt")), add = TRUE)
  entries <- c(D1 = 0, D3 = 2, D5 = 4)
  expected_N <- list(RNA = c(D1 = 504L, D3 = 420L, D5 = 320L),
                     Protein = c(D1 = 168L, D3 = 147L, D5 = 114L))
  expected_events <- list(RNA = c(D1 = 84L, D3 = 67L, D5 = 53L),
                          Protein = c(D1 = 27L, D3 = 18L, D5 = 14L))
  all_results <- list()
  family_summary <- list()
  empty_fit <- function(reason) {
    data.frame(N = 0L, Events = 0L, Centres = 0L, Event_centres = 0L,
               logHR = NA_real_, HR = NA_real_, lower95 = NA_real_,
               upper95 = NA_real_, SE = NA_real_, z = NA_real_,
               pval = NA_real_, PH_p = NA_real_, fit_ok = FALSE,
               warning = "", error = reason)
  }

  for (omics in c("RNA", "Protein")) {
    input <- load_inputs(omics)
    x <- input$x
    md <- input$md
    hallmark <- input$hallmark
    members <- lapply(hallmark, function(g) intersect(g, rownames(x)))
    coverage <- lengths(members)
    eligible <- coverage >= 10L
    nfamily <- sum(eligible)
    stopifnot(length(hallmark) == 50L, nfamily > 0L,
              !anyDuplicated(names(hallmark)), !anyDuplicated(colnames(x)))

    # Rank all included features within each sample.
    fractional_rank <- apply(x, 2L, function(v) {
      rank(v, ties.method = "average", na.last = "keep") / sum(is.finite(v))
    })
    dimnames(fractional_rank) <- dimnames(x)
    raw_scores <- matrix(NA_real_, nrow = 50L, ncol = ncol(x),
                         dimnames = list(names(hallmark), colnames(x)))
    for (pathway in names(hallmark)[eligible]) {
      raw_scores[pathway, ] <- colMeans(
        fractional_rank[members[[pathway]], , drop = FALSE]
      ) - 0.5
    }
    rm(fractional_rank)
    private_landmarks <- list()

    for (tm in names(entries)) {
      entry <- unname(entries[tm])
      risk <- md[md$Time == tm & md$stop > entry, , drop = FALSE]
      stopifnot(nrow(risk) == expected_N[[omics]][tm],
                sum(risk$event) == expected_events[[omics]][tm],
                !anyDuplicated(risk$PatientID), !anyDuplicated(risk$SampleName))
      sample_index <- match(risk$SampleName, colnames(raw_scores))
      stopifnot(!anyNA(sample_index))
      scores <- raw_scores[, sample_index, drop = FALSE]
      scores_z <- matrix(NA_real_, nrow = 50L, ncol = nrow(risk),
                        dimnames = dimnames(scores))
      rows <- vector("list", 50L)

      for (j in seq_along(hallmark)) {
        pathway <- names(hallmark)[j]
        score_mean <- score_sd <- NA_real_
        status <- "insufficient_coverage"
        fit <- empty_fit("Fewer than 10 available pathway members")
        if (eligible[j]) {
          s <- as.numeric(scores[j, ])
          stopifnot(all(is.finite(s)))
          score_mean <- mean(s)
          score_sd <- sd(s)
          if (!is.finite(score_sd) || score_sd <= 0) {
            status <- "no_score_variation"
            fit <- empty_fit("No finite positive within-riskset score SD")
          } else {
            scores_z[j, ] <- (s - score_mean) / score_sd
            fit <- fit_score(scores_z[j, ], risk, entry)
            stopifnot(fit$N == nrow(risk), fit$Events == sum(risk$event))
            status <- if (isTRUE(fit$fit_ok)) "estimated" else "fit_failed"
            if (!isTRUE(fit$fit_ok)) {
              fit[c("logHR", "HR", "lower95", "upper95", "SE", "z", "pval", "PH_p")] <- NA_real_
            }
          }
        }
        rows[[j]] <- cbind(
          data.frame(Omics = omics, Time = tm, Entry = entry, Pathway = pathway,
                     Coverage = unname(coverage[j]), Coverage_min = 10L,
                     Eligible = unname(eligible[j]), Nfamily = nfamily,
                     Riskset_N = nrow(risk), Riskset_Events = sum(risk$event),
                     Score_mean = score_mean, Score_SD = score_sd, Status = status),
          fit
        )
      }
      result <- rbindlist(rows, use.names = TRUE, fill = FALSE)
      result$FDR <- bh_fixed(result$pval, n = nfamily)
      stopifnot(nrow(result) == 50L, sum(result$Eligible) == nfamily,
                all(is.na(result$FDR[!result$fit_ok])))
      key <- paste(omics, tm, sep = "_")
      all_results[[key]] <- result
      family_summary[[key]] <- data.frame(
        Omics = omics, Time = tm, Entry = entry, N = nrow(risk),
        Events = sum(risk$event), Total_pathways = 50L, Nfamily = nfamily,
        Insufficient_coverage = sum(!eligible), Estimated = sum(result$fit_ok),
        Failed_eligible = sum(result$Eligible & !result$fit_ok),
        FDR_below_0_05 = sum(result$FDR < 0.05, na.rm = TRUE),
        BH_denominator = nfamily
      )
      private_landmarks[[tm]] <- list(metadata = risk, raw_scores = scores,
                                      standardised_scores = scores_z)
      cat(key, "N =", nrow(risk), "events =", sum(risk$event),
          "eligible =", nfamily, "estimated =", sum(result$fit_ok), "\n")
      flush.console()
    }
    saveRDS(list(coverage = coverage, eligible = eligible,
                 feature_count = nrow(x), landmarks = private_landmarks),
            file.path(ROOT, "local_cache", paste0("B_", omics, "_pathway_scores.rds")))
    rm(input, x, md, raw_scores, private_landmarks)
  }
  result <- rbindlist(all_results, use.names = TRUE, fill = FALSE)
  summary <- rbindlist(family_summary, use.names = TRUE, fill = FALSE)
  stopifnot(nrow(result) == 300L, nrow(summary) == 6L,
            !anyDuplicated(result[, .(Omics, Time, Pathway)]))
  write_table(result, "results/B/all_pathway_cox.tsv")
  write_table(summary, "qa/B_family_summary.tsv")
  cat("B completed: 300 pathway rows across six separately adjusted families.\n")
}

main_B()

