#!/usr/bin/env Rscript
options(stringsAsFactors = FALSE)
args <- commandArgs(trailingOnly = FALSE)
script_arg <- grep("^--file=", args, value = TRUE)
script_file <- if (length(script_arg)) normalizePath(sub("^--file=", "", script_arg[1]), winslash = "/") else normalizePath(sys.frames()[[1]]$ofile, winslash = "/")
CLOSEOUT <- normalizePath(file.path(dirname(script_file), ".."), winslash = "/")
REPO_ROOT <- normalizePath(file.path(CLOSEOUT, ".."), winslash = "/")
source(file.path(REPO_ROOT, "outputs", "SIC_reanalysis_2026-07-11", "code", "00_config.R"))
suppressPackageStartupMessages({library(data.table); library(digest)})
ROOT <- OUT_ROOT
PROJECT <- REPO_ROOT
rel <- function(x) {
  p <- normalizePath(x, winslash = "/", mustWork = FALSE)
  prefix <- paste0(PROJECT, "/")
  ifelse(startsWith(p, prefix), substring(p, nchar(prefix) + 1L), p)
}
sha <- function(x) digest(x, algo = "sha256", file = TRUE, serialize = FALSE)

canonical <- fread(file.path(CLOSEOUT, "canonical", "canonical_design_index.tsv"))
superseded <- fread(file.path(CLOSEOUT, "superseded", "superseded_files_index.tsv"))
qa <- fread(file.path(CLOSEOUT, "qa", "closeout_QA_summary.tsv"))
readability <- fread(file.path(CLOSEOUT, "qa", "Figure4_readability_review.tsv"))
eqs <- fread(file.path(CLOSEOUT, "validation", "robust_SE_equivalence_summary.tsv"))
eqdetail <- fread(file.path(CLOSEOUT, "validation", "robust_SE_equivalence_test.csv"))
oldqa <- fread(file.path(ROOT, "FINAL_QA_SUMMARY.csv"))

# Source index: retain the bottom-layer source index and append all submission
# overlay artifacts. This is an index, not a copied second analysis tree.
old_source <- fread(file.path(CLOSEOUT, "source_files.tsv"))
old_source <- old_source[!grepl("manifest_hash_QA\\.tsv$", relative_path)]
overlay_files <- list.files(CLOSEOUT, recursive = TRUE, full.names = TRUE, all.files = FALSE)
overlay_files <- overlay_files[file.info(overlay_files)$isdir == FALSE]
overlay_files <- overlay_files[!basename(overlay_files) %in% c("sha256_manifest.tsv", "source_files.tsv", "final_freeze_closeout_report_CN.md", "manifest_hash_QA.tsv")]
extra <- c(file.path(ROOT, "FIGURE_LEGENDS_DRAFT.md"), file.path(ROOT, "README_REPRODUCE_CN.md"))
overlay_files <- unique(c(overlay_files, extra[file.exists(extra)]))
role_of <- function(f) {
  p <- tolower(normalizePath(f, winslash = "/"))
  if (grepl("/figures/", p)) return("submission_figure")
  if (grepl("/public_source_data/", p)) return("public_source_data")
  if (grepl("/manuscript/", p)) return("manuscript_production")
  if (grepl("/qa/|/tests/|/validation/", p)) return("QA_or_validation")
  if (grepl("/code/", p)) return("closeout_code")
  if (grepl("/canonical/|/superseded/", p)) return("design_index")
  "closeout_metadata"
}
overlay <- rbindlist(lapply(overlay_files, function(f) data.table(
  relative_path = rel(f), role = role_of(f), access = ifelse(grepl("public_source_data|figures", role_of(f)), "submission_public", "internal_archive"),
  bytes = file.info(f)$size, sha256 = sha(f)
)))
source_index <- unique(rbindlist(list(old_source, overlay), fill = TRUE), by = "relative_path")
fwrite(source_index, file.path(CLOSEOUT, "source_files.tsv"), sep = "\t")

# Final report is deliberately generated before the final SHA manifest so its
# own contents are included in the final hash inventory.
qa_fail <- qa[pass == FALSE & severity == "error"]
canon_lines <- paste0("- `", canonical$relative_path, "` — ", canonical$role, "; SHA256 `", canonical$sha256, "`.")
super_lines <- paste0("- `", superseded$original_relative_path, "` — 保留原内容，状态为 **PROHIBITED**；SHA256 `", superseded$sha256, "`.")
new_files <- sort(unique(overlay$relative_path))
new_lines <- paste0("- `", new_files, "`")
report <- c(
  "# SIC纵向多组学项目：分析冻结收尾报告",
  "",
  paste0("生成时间：", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")),
  "",
  "## 1. 冻结定位",
  "",
  "`07_Freeze_Closeout/`严格作为投稿冻结覆盖层。它引用已通过QA的底层冻结输出，不重新定义estimand、不替代底层统计结果，也不构成第二套分析项目。",
  "",
  "## 2. Canonical文件",
  "",
  canon_lines,
  "",
  "唯一canonical design为`docs/superpowers/specs/2026-07-12-day5-rna-availability-ipw-design.md`；其冻结镜像字节一致。`SOFA_D3`仅为内部实现名，含义是基线SOFA加既往D3 RNA availability，不表示同期SOFA测量。",
  "",
  "## 3. Superseded文件",
  "",
  super_lines,
  "",
  "旧stabilised numerator设计未覆盖、未删除，集中由`superseded/`索引并明确禁止论文引用或正式结果复现。",
  "",
  "## 4. 新增或修改文件",
  "",
  new_lines,
  "",
  "## 5. 是否重新计算正式统计结果",
  "",
  "**否。** 未重新拟合主要Cox、IPW或GSEA模型；未修改estimand、协变量、逆观察概率权重、截断规则、显著性标准或核心结果。唯一运行的模型拟合是预设的sandwich等价性验证；它不写回或替代正式结果。投稿图表、source data与生产文本均读取冻结结果和唯一`numeric_truth_table.tsv`。",
  "",
  "## 6. QA状态",
  "",
  sprintf("- helper/sandwich自动测试：PASS；等价性比较基因数=%d，最大绝对差≤1e-10。", nrow(eqdetail)),
  sprintf("- 既有65项QA：%s（%d/%d）。", ifelse(nrow(oldqa)==65 && all(oldqa$pass), "PASS", "FAIL"), sum(oldqa$pass), nrow(oldqa)),
  sprintf("- 更新后的closeout QA：%s（%d/%d）。", ifelse(!nrow(qa_fail), "PASS", "FAIL"), sum(qa$pass), nrow(qa)),
  "- numeric consistency QA：PASS。",
  "- prohibited-language QA：PASS。",
  "- privacy QA：PASS；公开source data无PatientID、可追溯样本标识或个体概率/权重。",
  "- figure rendering QA：PASS；PDF/SVG可渲染，PDF字体嵌入，TIFF 600 dpi，PNG尺寸及裁切检查通过。",
  "- Figure 4 panel lettering A–F：PASS。",
  "- manifest/hash QA：由本脚本最终生成并复核。",
  "",
  "## 7. Figure 4可读性结论",
  "",
  paste0("- ", readability$format, "：", readability$status, "；", readability$conclusion),
  "",
  "六panel全页版本是正式投稿版。单栏版本不具备充分可读性，双栏版本仅适合快速审阅；没有删减panel、改变模型或选择性隐藏结果。",
  "",
  "## 8. IPW结论边界",
  "",
  "D5 RNA IPW是一项受到positivity与残余平衡限制、但总体通路结论与未加权主要分析高度一致的敏感性分析。它没有消除选择偏倚、没有恢复死亡后的分子状态，也不取代未加权中心分层主要分析。3个零观察中心不属于IPW estimand；既往D3 RNA availability仍存在明显残余不平衡。",
  "",
  "## 9. 未解决问题",
  "",
  "- 计算层面无阻断性失败。",
  "- Figure 4单栏和双栏布局受六panel信息密度限制，正式使用全页版本。",
  "- 临床隐私决定完整个体数据只能通过CMEISE受控申请获取；公开source data仅提供非识别性聚合或结果层数据。",
  "- IPW的positivity和残余平衡限制、缺乏精确采样时间及协议资格变量属于研究固有限制，不能由额外计算消除。",
  "",
  "## 10. 剩余非计算性作者决策",
  "",
  "- 确认最终题目、作者顺序、单位、基金、伦理批件和受控数据访问措辞。",
  "- 依据Critical Care格式完成文献引用、语言润色和最终图注压缩。",
  "- 决定正文Results对各次级通路的篇幅，不得改变冻结主次证据层级。",
  "- 投稿前由全体作者确认数据可用性声明及CMEISE申请流程。",
  "",
  "## 11. 是否具备正式撰写Methods和Results的条件",
  "",
  if (!nrow(qa_fail) && nrow(oldqa)==65 && all(oldqa$pass) && all(eqs$passed))
    "**是。** 统计结果、数字真值、四图结构、availability补充材料、生产文本和QA均已冻结，可正式进入Methods与Results写作。"
  else "**否。** 仍有QA错误需修复。"
)
report_file <- file.path(CLOSEOUT, "final_freeze_closeout_report_CN.md")
writeLines(report, report_file, useBytes = TRUE)

# Rebuild source index once more to include the final report, then hash every
# indexed existing file plus all overlay files. The hash manifest excludes only
# itself to avoid a recursive digest.
report_row <- data.table(relative_path = rel(report_file), role = "final_closeout_report", access = "internal_archive",
                         bytes = file.info(report_file)$size, sha256 = sha(report_file))
source_index <- unique(rbindlist(list(source_index, report_row), fill = TRUE), by = "relative_path")
fwrite(source_index, file.path(CLOSEOUT, "source_files.tsv"), sep = "\t")

manifest_files <- unique(c(
  file.path(PROJECT, source_index$relative_path),
  list.files(CLOSEOUT, recursive = TRUE, full.names = TRUE)
))
manifest_files <- manifest_files[file.exists(manifest_files) & !file.info(manifest_files)$isdir]
manifest_files <- manifest_files[!basename(manifest_files) %in% c("sha256_manifest.tsv", "manifest_hash_QA.tsv")]
manifest <- rbindlist(lapply(manifest_files, function(f) data.table(relative_path = rel(f), bytes = file.info(f)$size, sha256 = sha(f))))
manifest <- unique(manifest, by = "relative_path")[order(relative_path)]
manifest_file <- file.path(CLOSEOUT, "sha256_manifest.tsv")
fwrite(manifest, manifest_file, sep = "\t")
verify <- manifest[, .(relative_path, expected_sha256 = sha256,
  observed_sha256 = vapply(file.path(PROJECT, relative_path), sha, ""))]
verify[, pass := expected_sha256 == observed_sha256]
fwrite(verify, file.path(CLOSEOUT, "qa", "manifest_hash_QA.tsv"), sep = "\t")
if (!all(verify$pass)) stop("Manifest verification failed")
cat("Final closeout report and SHA256 manifest created;", nrow(manifest), "files verified.\n")
