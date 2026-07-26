# Scientific Reports v1.1 final-package QA

## Authoritative files

The exact author-confirmed final package is distributed as the GitHub Release asset `scientific-reports-submission-v1.1-assets.zip`. The asset is authoritative over the pre-final candidate documents generated in closed pull request #3.

| File | SHA-256 | Result |
|---|---|---|
| `Scientific_Reports_final_726.docx` | `c2b7628752c69088da9fd2f329b8675f9222c5615ab10f96c4c2753b41ebb2fe` | PASS |
| `Scientific_Reports_Supplementary_Information.pdf` | `35baa2f462fc5575876fda8c6b198dfa16b804a6d826351ee87570db6c37fb30` | PASS - 16 pages |
| `Supplementary_methods_figures726.docx` | `81e9d2ed62bf75b123c9ec72d2ac15c15a10ea4bd8f5f50f706caa21adc24342` | PASS - 9 embedded figures |
| `STROBE_Final_726.docx` | `f0551df250c196a17d2ce3b129aba576994237d7baff3a103994e3682a3fbddb` | PASS - corrected 43-page/16-page convention |
| `Scientific_Reports_Supplementary_Tables_S1-S8_and_Field_Dictionary.zip` | `c39b2ff3b0ecbf662cdd3035cd9a1b0ef46ac4b10ed3f3de9b24b99bc44b6439` | PASS |
| `Supplementary_Table_S9_Complete_baseline_characteristics.xlsx` | `c703d8545a54f163e6e330f90c7c2574ee1706a9a00c530bfd5a679b4054d5e3` | PASS |

The cover letter is intentionally excluded from the public repository and Release asset.

## Document QA

- Main manuscript pagination authority: 43 pages in the author's Microsoft Word environment; Table 1 is on page 43.
- Supplementary pagination authority: supplied 16-page PDF.
- The editable Supplementary DOCX can reflow to 17 pages in LibreOffice; this is renderer variance, not missing content.
- Main manuscript: 4 embedded figures, no comments, no tracked changes, and clean ASCII hyperlink targets.
- Supplementary DOCX: 9 embedded figures, no comments and no tracked changes.
- STROBE: 2-page rendered checklist with no clipping.

## Figure QA

The figures embedded in the final manuscript and Supplementary Information are the scientific authority. Independent PNG/TIFF/PDF copies are included in the Release asset.

- Exact match to the previous public PNG: Figure 4 and Supplementary Figures S1, S3, S5, S6, S7 and S8.
- Authoritative final embedded version differs from the previous public PNG: Figures 1-3 and Supplementary Figures S2, S4 and S9.
- Corrected Supplementary Figure S2 contains all six scenario labels and the `Prespecified scenario` marker.
- All changed figures were visually inspected at full resolution; no clipping, panel loss, missing legend or unreadable label was identified.

## Numerical and table QA

- All 27 prespecified core manuscript checks passed against aggregate source data/locked outputs: cohort and event counts; RNA and protein NES/FDR examples; cross-omic correlations and forward estimates; and IPW probability, weight, ESS, balance and pathway-concordance diagnostics.
- Main Table 1 was compared cell-by-cell with the current Supplementary Table S9: 108 comparisons, 0 mismatches. The final Table 1 correctly includes potassium (`K`).
- Supplementary Tables S1-S8, the field dictionary and S9 are valid OOXML workbooks and contain the expected worksheet names.

## Privacy and reproducibility boundary

- No participant-level clinical or omic data are included.
- No participant identifiers, traceable sample identifiers, original centre identifiers, individual observation probabilities or individual IPW weights are included.
- Repository code, aggregate source data, numeric-truth layers and data-free tests remain in the Git tree.
- A complete rerun requires separately authorised CMAISE/OMIX011182 data.

## Release-history protection

`jic-submission-v1.0` remains immutable at commit `fb0fe912af51435a82f95b4bfe25d758fa1c6646`. The Scientific Reports work uses a distinct branch, tag and Release asset.
