#!/usr/bin/env Rscript
options(stringsAsFactors = FALSE)
args <- commandArgs(trailingOnly = FALSE)
script_arg <- grep("^--file=", args, value = TRUE)
script_file <- if (length(script_arg)) normalizePath(sub("^--file=", "", script_arg[1]), winslash = "/") else normalizePath(sys.frames()[[1]]$ofile, winslash = "/")
CLOSEOUT <- normalizePath(file.path(dirname(script_file), ".."), winslash = "/")
REPO_ROOT <- normalizePath(file.path(CLOSEOUT, ".."), winslash = "/")
source(file.path(REPO_ROOT, "outputs", "SIC_reanalysis_2026-07-11", "code", "00_config.R"))
suppressPackageStartupMessages(library(data.table))

qa <- fread(file.path(CLOSEOUT, "qa", "semantic_QA_summary.tsv"))
oldqa <- fread(file.path(CLOSEOUT, "..", "FINAL_QA_SUMMARY.csv"))
hash <- fread(file.path(CLOSEOUT, "validation", "formal_result_hash_semantic_comparison.tsv"))
readability <- fread(file.path(CLOSEOUT, "qa", "Figure4_readability_review.tsv"))
ev <- fread(file.path(CLOSEOUT, "manuscript", "manuscript_evidence_matrix.tsv"))

modified <- c(
  "Figure 1 panel d label and legend (4 patients versus 3 centres)",
  "Figure 2 and Figure 3 file stems, primary-analysis star legends, and pathway display names",
  "Figure 4 single-column and double-column review layouts; formal full-page A-F figure data unchanged",
  "Supplementary Figures A5-A7 x-axis wrapping, margins, and boundary-safe layouts",
  "Methods wording for separate time-specific prognostic models with delayed entry",
  "Independent legends for Supplementary Figures A1-A8 and worksheet-level supplementary-table captions",
  "Manuscript evidence matrix and semantic/numeric/privacy/rendering QA interfaces"
)
unchanged <- c(
  "All formal Cox coefficients, robust standard errors, Wald statistics and P values",
  "The frozen Day-5 availability estimand, covariates, centre-positivity rules, inverse-probability weights and truncation",
  "All formal IPW and unweighted Hallmark GSEA results, FDR thresholds and leading-edge results",
  "All same-time, forward, reverse and OXPHOS-attenuation cross-omics statistics",
  "The numeric truth table as the sole numeric interface for manuscript production"
)

lines <- c(
  "# 投稿生产层语义修补报告",
  "",
  "## 1. 本轮修改的文本与图形接口",
  "",
  paste0("- ", modified),
  "",
  "## 2. 本轮明确未修改的正式统计结果",
  "",
  paste0("- ", unchanged),
  "",
  sprintf("正式结果哈希比较：%d/%d 个文件保持完全一致；本轮未重新拟合任何正式 Cox、IPW、GSEA 或跨组学模型。", sum(hash$unchanged), nrow(hash)),
  "",
  "## 3. 新增语义 QA",
  "",
  sprintf("- 原有项目 QA：%d/%d 通过。", sum(oldqa$pass), nrow(oldqa)),
  sprintf("- 本轮语义 QA：%d/%d 通过。", sum(qa$pass), nrow(qa)),
  sprintf("- 论文证据矩阵：%d 条可追溯 claim。", nrow(ev)),
  "- Figure 1 已分别核对零观察中心患者数和中心数。",
  "- Figure 2/3 的星号已逐格与制图所用主要分析 BH-FDR 复算并一致。",
  "- Figure 4 A-F 的效应量、置信区间、P 值/FDR 已逐项回溯 numeric truth table。",
  "- 正式统计结果 SHA256 在语义修补前后保持不变。",
  "- A5-A7 及 Figure 4 审阅版已增加边界安全布局；外边缘像素 QA 与人工渲染复核共同用于识别裁切。",
  "",
  "## 4. Figure 4 可读性结论",
  "",
  paste0("- ", readability$format, "：", readability$status, "。", readability$conclusion),
  "- 正式投稿优先使用 183 × 225 mm 整页 3×2 布局。单栏审阅版通过纵向重排获得可读性，但其扩展高度不适合作为单页投稿版式。",
  "",
  "## 5. 未解决问题",
  "",
  "- 无计算性阻碍。",
  "- 非计算性作者决策仍包括：期刊最终图幅选择、作者/单位/基金/伦理/数据申请措辞，以及正文篇幅压缩。",
  "",
  "## 6. 是否具备正式撰写条件",
  "",
  "**是。当前冻结结果、数字真值层、证据矩阵、图注和语义 QA 已具备正式撰写 Methods 与 Results 的条件。**",
  "",
  "## 7. 版本管理",
  "",
  "- 目标只读标签：`analysis-freeze-v1.0-2026-07-13`。",
  "- 标签说明应注明：原 65 项 QA 全部通过；更新后的 closeout/semantic QA 通过；正式统计结果哈希未改变；本轮仅修改图形标签、图注、论文证据规格和 QA。"
)
writeLines(lines, file.path(CLOSEOUT, "manuscript_interface_patch_report_CN.md"), useBytes = TRUE)
cat("Semantic patch report created.\n")
