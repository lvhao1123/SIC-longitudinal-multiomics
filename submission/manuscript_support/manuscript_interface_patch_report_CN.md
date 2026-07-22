# 投稿生产层语义修补报告

## 1. 本轮修改的文本与图形接口

- Figure 1 panel d label and legend (4 patients versus 3 centres)
- Figure 2 and Figure 3 file stems, primary-analysis star legends, and pathway display names
- Figure 4 single-column and double-column review layouts; formal full-page A-F figure data unchanged
- Supplementary Figures A5-A7 x-axis wrapping, margins, and boundary-safe layouts
- Methods wording for separate time-specific prognostic models with delayed entry
- Independent legends for Supplementary Figures A1-A8 and worksheet-level supplementary-table captions
- Manuscript evidence matrix and semantic/numeric/privacy/rendering QA interfaces

## 2. 本轮明确未修改的正式统计结果

- All formal Cox coefficients, robust standard errors, Wald statistics and P values
- The frozen Day-5 availability estimand, covariates, centre-positivity rules, inverse-probability weights and truncation
- All formal IPW and unweighted Hallmark GSEA results, FDR thresholds and leading-edge results
- All same-time, forward, reverse and OXPHOS-attenuation cross-omics statistics
- The numeric truth table as the sole numeric interface for manuscript production

正式结果哈希比较：40/40 个文件保持完全一致；本轮未重新拟合任何正式 Cox、IPW、GSEA 或跨组学模型。

## 3. 新增语义 QA

- 原有项目 QA：65/65 通过。
- 本轮语义 QA：48/48 通过。
- 论文证据矩阵：314 条可追溯 claim。
- Figure 1 已分别核对零观察中心患者数和中心数。
- Figure 2/3 的星号已逐格与制图所用主要分析 BH-FDR 复算并一致。
- Figure 4 A-F 的效应量、置信区间、P 值/FDR 已逐项回溯 numeric truth table。
- 正式统计结果 SHA256 在语义修补前后保持不变。
- A5-A7 及 Figure 4 审阅版已增加边界安全布局；外边缘像素 QA 与人工渲染复核共同用于识别裁切。

## 4. Figure 4 可读性结论

- single-column 89 mm：PASS_EXTENDED_HEIGHT。Readable after a one-column-by-six-panel reflow; the 440-mm height is a review export, not a single-page submission layout.
- double-column 183 mm：PASS。Readable after a two-column-by-three-row reflow; axes and confidence intervals remain visible.
- full-page 183x225 mm：PASS。Preferred submission layout; labels, confidence intervals and legends are readable.
- 正式投稿优先使用 183 × 225 mm 整页 3×2 布局。单栏审阅版通过纵向重排获得可读性，但其扩展高度不适合作为单页投稿版式。

## 5. 未解决问题

- 无计算性阻碍。
- 非计算性作者决策仍包括：期刊最终图幅选择、作者/单位/基金/伦理/数据申请措辞，以及正文篇幅压缩。

## 6. 是否具备正式撰写条件

**是。当前冻结结果、数字真值层、证据矩阵、图注和语义 QA 已具备正式撰写 Methods 与 Results 的条件。**

## 7. 版本管理

- 目标只读标签：`analysis-freeze-v1.0-2026-07-13`。
- 标签说明应注明：原 65 项 QA 全部通过；更新后的 closeout/semantic QA 通过；正式统计结果哈希未改变；本轮仅修改图形标签、图注、论文证据规格和 QA。
