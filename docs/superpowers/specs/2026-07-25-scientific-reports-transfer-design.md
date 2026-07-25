# Scientific Reports Transfer Redesign Specification

## 1. Purpose and authoritative baseline

This specification defines the journal-specific conversion of the frozen Journal of Intensive Care submission into a Scientific Reports submission while preserving the scientific results, numerical outputs, figures, and analysis provenance. It is a controlled editorial and reporting transformation, not a new analysis.

The only authoritative baseline is the public release `jic-submission-v1.0` in `lvhao1123/SIC-longitudinal-multiomics`, including:

- `submission/manuscript_files/JIC_manuscript_clean.docx`
- `submission/manuscript_files/Additional_file_1_Supplementary_methods_and_figures.docx`
- `submission/manuscript_files/Additional_file_2_Supplementary_Tables_S1-S8.zip`
- `submission/manuscript_files/STROBE_checklist_cohort_completed.docx`
- all publication figures, source-data tables, numerical-truth layers, manifests, and QA records in that release

The original release must not be edited, retagged, deleted, or overwritten.

## 2. Scientific freeze

The following are immutable unless a verified inconsistency is documented and separately approved by the author:

- cohort sizes and event counts;
- landmark risk-set definitions;
- outcome horizon and censoring rules;
- all HRs, confidence intervals, P values, adjusted P values, FDR values, NES values, and sensitivity-analysis metrics;
- pathway directions and significance classifications;
- all scientific figures, source-data tables, and machine-readable result tables;
- all prespecified estimands, model specifications, weighting definitions, PH diagnostics, and QA outcomes.

No new statistical, pathway, subgroup, prediction, or mechanistic analysis will be added. If the manuscript, figure, supplementary file, source data, numerical truth, or QA output disagree, work must stop at that item and the discrepancy must be reported before any scientific value is changed.

## 3. Permitted scientific editing

Scientific editing may:

- clarify the distinction between the Day-1-defined cohort and Day-1, Day-3, and Day-5 landmark risk sets;
- replace wording that implies within-patient trajectories with landmark-specific or stage-dependent prognostic-association language where required;
- clarify that Day-5 estimates apply to Day-5 survivors in the positivity-supported analysis population;
- strengthen interpretation of concordant and discordant transcriptomic and proteomic findings;
- organise interpretation into immune-inflammatory, metabolic-stress, and coagulation-tissue-injury/repair modules;
- present cross-omic discordance as potentially reflecting layer-specific regulation, temporal offsets, assay coverage, or sample availability, explicitly as hypothesis-generating;
- emphasise landmark construction, PH auditing, positivity assessment, IPW sensitivity analysis, and data-free reproducibility;
- distinguish association discovery from causal inference, validated biomarkers, clinical prediction, and therapeutic targets;
- add verified literature-supported context without adding unsupported results.

Scientific editing must not:

- describe observational associations as causal mechanisms;
- describe Hallmark enrichment as direct measurement of cellular function or cell type;
- describe different landmark cohorts as paired within-patient trajectories unless supported by the analysis;
- generalise Day-5 estimates to the entire Day-1 SIC population;
- claim a validated clinical model, diagnostic biomarker, or therapeutic target;
- introduce numerical results absent from the frozen outputs.

## 4. Journal target, article type, and title

Target journal: `Scientific Reports`

Article type: `Article`

The title remains unchanged:

> Landmark-specific transcriptomic and proteomic associations with 60-day mortality in Day-1-defined sepsis-induced coagulopathy: a multicentre longitudinal cohort study

## 5. Main-manuscript design

The clean manuscript will use this order:

1. Title page
2. Abstract
3. Keywords
4. Introduction
5. Results
6. Discussion
7. Methods
   - includes human-research ethics and informed-consent reporting
   - includes a subsection headed `Code availability`
   - final subsection: `AI-assisted tools in manuscript and code preparation`
8. Data availability
9. References
10. Acknowledgements
11. Author contributions
12. Additional Information
   - Competing interests
13. Figure legends
14. Table 1

This order follows the current Scientific Reports guidance that Data availability appears before References, while the journal policy requires a Methods subsection headed `Code availability`. The standalone Conclusions section will be incorporated into the final Discussion paragraph. The document will be single-column and left aligned, with Arabic page numbers in the footer and line numbering enabled.

### 5.1 Abstract and keywords

The abstract must be unstructured, contain no references, and contain no more than 200 words. It must introduce the problem for a broad scientific audience, state the multicentre longitudinal landmark design, report only frozen principal results, make the conditional Day-5 estimand clear, and end with a bounded non-causal implication.

Keywords are limited to:

1. Sepsis-induced coagulopathy
2. Multi-omics
3. Landmark analysis
4. Transcriptomics
5. Proteomics
6. Mortality

### 5.2 Length and readability

Introduction + Results + Discussion should not exceed 4,500 words unless an exception is documented and approved. Specialist jargon will be minimised, nonstandard abbreviations defined, and landmark analysis, positivity support, and inverse-probability weighting explained for scientifically literate readers outside critical-care biostatistics.

Discussion will not use subheadings unless a clear readability need is documented. The reference list should normally remain within 60 references.

## 6. Main Table 1 and Supplementary Table S9

The main manuscript will retain a legible one-page Table 1. It will prioritise:

- age;
- sex;
- SOFA score;
- platelet count;
- INR;
- D-dimer;
- lactate;
- blood urea nitrogen;
- PaO2/FiO2;
- infection source;
- major comorbidities.

The set may be reduced only when necessary for one-page readability. Every value, denominator, summary statistic, P value, and footnote must match the frozen full table.

The complete baseline table will become `Supplementary Table S9`. The main table legend and Results will direct readers to Supplementary Table S9.

## 7. Supplementary-information design

Use a hybrid supplementary package.

Create:

- `Scientific_Reports_Supplementary_Information.docx`
- `Scientific_Reports_Supplementary_Information.pdf`

The first page will contain the manuscript title and full author list. The composite file will contain:

- Supplementary Methods;
- Supplementary Figs. S1-S9;
- complete baseline characteristics as Supplementary Table S9;
- titles, descriptions, field notes, and a file index for Supplementary Tables S1-S8.

The existing S1-S8 `.xlsx` workbooks remain separate machine-readable files and will not be converted into long PDF tables.

All former `Supplementary Figure A1-A9` items will become `Supplementary Fig. S1-S9`. This change must propagate through:

- main-manuscript citations;
- supplementary headings and legends;
- file indexes;
- submission-facing file names;
- README and manifest descriptions;
- validation scripts that inspect display-item references.

Historical JIC release file names remain unchanged. Every supplementary item must be cited at the appropriate point in the main manuscript, each citation must include the word `Supplementary`, and individual panels of supplementary figures must not be cited separately. The composite file must remain below 50 MB.

## 8. References

References will use standard Nature style:

- sequential numerical citations in square brackets;
- one publication per number;
- all authors when fewer than six, otherwise first author plus `et al.`;
- surname followed by initials;
- abbreviated italic journal title;
- bold volume number;
- full page range or article number;
- year in parentheses.

Citation-to-reference mapping must be preserved. New references may be added only when they directly support an approved interpretive clarification and have been checked against the primary source.

## 9. Ethics, data, code, and competing interests

Methods must include the complete human-research ethics statement:

- approving committee and approval identifier;
- compliance with the Declaration of Helsinki and applicable regulations;
- written informed consent from participants or legally authorised representatives, as applicable to the parent study.

A mandatory Data availability statement, placed before References, will distinguish:

- controlled participant-level clinical, transcriptomic, and proteomic data under OMIX011182;
- the authors' lack of authority to redistribute those data;
- public aggregate result tables, figure source data, and reproducibility materials.

Methods will contain a subsection headed `Code availability` pointing to the Scientific Reports-specific immutable release after it exists.

Additional Information will include:

### Competing interests

> The authors declare no competing interests.

## 10. AI-use disclosure

The final subsection of Methods will be:

### AI-assisted tools in manuscript and code preparation

> ChatGPT (OpenAI) was used as an assistive tool during manuscript drafting, restructuring, language editing, and the development and review of analysis scripts. All analyses were executed through the version-controlled workflow, and the reported numerical results, tables, and figures were verified against the frozen outputs and predefined quality-assurance checks. The authors retained final responsibility for the study design, analytical choices, interpretation, source verification, and conclusions; critically reviewed and revised all AI-assisted material; and approved the final manuscript. Generative AI was not used to create or modify the scientific figures.

The disclosure must not imply AI authorship. ChatGPT must not appear in the author list or author-contribution statement.

## 11. Cover letter

Create `Scientific_Reports_Cover_Letter.docx` containing:

- manuscript title and article type;
- corresponding-author affiliation and contact details matching the manuscript and submission system;
- a concise explanation of fit based on technical validity, multicentre longitudinal design, landmark methodology, multi-omics, and reproducibility;
- this factual transfer statement:

> This manuscript was previously submitted to the Journal of Intensive Care and is now being submitted to Scientific Reports following a Springer Nature journal-transfer recommendation.

- confirmation that the work is original, unpublished, not under consideration elsewhere, and approved by all authors;
- no preferred reviewers and no reviewer exclusions;
- no prior discussions with a Scientific Reports Editorial Board Member;
- the controlled-data and public-code boundary where useful.

The letter must not imply that Journal of Intensive Care completed scientific peer review or requested specific revisions.

## 12. Change-marking deliverables

Create:

- `Scientific_Reports_manuscript_clean.docx`
- `Scientific_Reports_manuscript_highlighted.docx`
- `Scientific_Reports_revision_report.docx`

Yellow highlighting will identify newly written paragraphs, substantially rewritten interpretation, methodological-boundary clarifications, claim restrictions, and new policy disclosures. Routine section moves, formatting conversion, reference-style conversion, and systematic renumbering will be documented in the revision report instead of being highlighted throughout.

Revision-report classifications:

- `clarification`
- `interpretive expansion`
- `claim restriction`
- `journal compliance`
- `structural relocation`
- `cross-reference renumbering`

## 13. STROBE update

STROBE will be updated only after manuscript and supplementary pagination are stable.

Create:

- `STROBE_Scientific_Reports_completed.docx`
- `STROBE_Scientific_Reports_audit.tsv`

Every entry will be remapped to the final section and page. The audit will verify reporting of cohort design, eligibility and Day-1 SIC definition, Day-3/Day-5 landmark risk sets, outcome, missing data, assay availability, positivity, IPW, Cox/PH diagnostics, multiplicity/FDR, sensitivity analyses, limitations, generalisability, ethics, and data/code availability.

## 14. Quality assurance

### 14.1 Scientific integrity

- compare all manuscript numerals with frozen numerical-truth and source-data layers;
- compare all concise Table 1 values with Supplementary Table S9;
- introduce no new result;
- permit no unsupported causal, therapeutic, or validation claim.

### 14.2 Cross-reference integrity

- zero residual `Supplementary Figure A1-A9` citations in submission-facing files;
- all Supplementary Figs. S1-S9 cited;
- Supplementary Tables S1-S9 cited or indexed appropriately;
- main figures and tables cited in numerical order;
- no broken section, display-item, or bibliography references.

### 14.3 Journal-format integrity

- unstructured abstract of no more than 200 words;
- no more than six keywords;
- unchanged title;
- Introduction + Results + Discussion no more than 4,500 words unless approved;
- no more than eight main display items;
- each figure legend no more than 350 words;
- main Table 1 no more than one page;
- Supplementary Information below 50 MB;
- Nature reference style;
- Data availability before References;
- Methods subsection headed `Code availability`;
- no graphical abstract or footnotes.

### 14.4 Document hygiene

- no unresolved comments or tracked changes in clean files;
- no hidden text, accidental fields, or stale hyperlinks;
- visible page and line numbering;
- editable tables;
- page-by-page PDF rendering review;
- safe font substitution or embedding;
- legible figures.

### 14.5 Privacy and reproducibility

- no participant identifiers or controlled data added;
- public manifest rebuilt;
- SHA-256 hashes regenerated;
- existing privacy, semantic, repository, and canonical-hash tests rerun;
- Scientific Reports-specific metadata tests added where needed.

## 15. Repository and release design

All work will occur on:

- `release/scientific-reports-submission-v1.1`

The original JIC tag and release remain unchanged.

New release:

- tag: `scientific-reports-submission-v1.1`
- target: final merged `main`
- date: actual GitHub publication date

The release will include the clean manuscript, highlighted manuscript and revision report, composite Supplementary Information DOCX/PDF, S1-S9 supplementary tables and index, updated STROBE and audit, README, CITATION metadata, manifest, hashes, and QA outputs.

The public release will not include the Cover Letter, participant-level data, controlled OMIX files, editorial correspondence, reviewer information, credentials, or local paths.

## 16. Acceptance criteria

The conversion is complete only when:

1. the scientific freeze is preserved;
2. all manuscript, cover-letter, supplementary, table, STROBE, and change-report deliverables exist;
3. all Scientific Reports-specific checks pass;
4. repository QA passes with zero failures;
5. a pull request contains only expected conversion changes;
6. the pull request is merged after author review;
7. `scientific-reports-submission-v1.1` is published from final `main`;
8. the release is publicly accessible without authentication and its source archive contains the expected files.