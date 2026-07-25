# Scientific Reports Transfer Redesign Specification

## 1. Purpose

This specification defines the journal-specific conversion of the frozen Journal of Intensive Care submission into a Scientific Reports submission while preserving the underlying scientific results, numerical outputs, figures, and analysis provenance.

The conversion is not a new analysis. It is a controlled editorial, structural, and reporting transformation of the immutable `jic-submission-v1.0` release.

## 2. Authoritative baseline

The only authoritative source for the conversion is the public GitHub release:

- Tag: `jic-submission-v1.0`
- Repository: `lvhao1123/SIC-longitudinal-multiomics`

The following release assets and tracked files define the baseline submission package:

- `submission/manuscript_files/JIC_manuscript_clean.docx`
- `submission/manuscript_files/Additional_file_1_Supplementary_methods_and_figures.docx`
- `submission/manuscript_files/Additional_file_2_Supplementary_Tables_S1-S8.zip`
- `submission/manuscript_files/STROBE_checklist_cohort_completed.docx`
- all publication figures, source-data tables, numerical-truth layers, manifests, and QA records present in the release

The original release must not be edited, retagged, deleted, or overwritten.

## 3. Scientific freeze

The following are immutable unless a verified inconsistency is found and separately approved by the author:

- cohort sizes and event counts;
- landmark risk-set definitions;
- outcome horizon and censoring rules;
- all hazard ratios, confidence intervals, P values, adjusted P values, FDR values, NES values, and sensitivity-analysis metrics;
- pathway directions and significance classifications;
- all main and supplementary scientific figures;
- all source-data and machine-readable result tables;
- all prespecified estimands, model specifications, weighting definitions, PH diagnostics, and QA outcomes.

No new statistical analysis, pathway analysis, subgroup analysis, prediction model, or mechanistic experiment will be added during the transfer conversion.

If a discrepancy is detected among the manuscript, figure, supplementary file, source data, numerical truth table, or frozen QA outputs, work must stop at that item. The discrepancy must be documented and presented to the author before any scientific value is changed.

## 4. Permitted scientific editing

Scientific editing may:

- clarify the distinction between Day-1 cohort definition and Day-1, Day-3, and Day-5 landmark risk sets;
- replace language implying within-patient molecular trajectories with language describing landmark-specific or stage-dependent prognostic associations where appropriate;
- clarify that Day-5 estimates apply to the Day-5-surviving, positivity-supported analysis population;
- strengthen explanation of concordant and discordant transcriptomic and proteomic findings;
- organise biological interpretation into immune-inflammatory, metabolic-stress, and coagulation-tissue-injury/repair modules;
- explain that cross-omic discordance may reflect layer-specific regulation, temporal offsets, assay coverage, and sample availability, while labelling these explanations as hypothesis-generating;
- strengthen the methodological contribution of landmark risk-set construction, PH auditing, positivity assessment, IPW sensitivity analysis, and data-free reproducibility;
- distinguish association discovery from causal inference, validated biomarkers, clinical prediction, and therapeutic targets;
- add literature-supported context without adding unsupported results.

Scientific editing must not:

- describe observational associations as causal mechanisms;
- describe Hallmark enrichment as direct measurement of cellular function or cell type;
- describe different landmark cohorts as paired within-patient trajectories unless the underlying analysis supports that claim;
- generalise Day-5 estimates to the full Day-1 SIC population;
- claim a clinically validated prognostic model, diagnostic biomarker, or therapeutic target;
- introduce numerical results absent from the frozen outputs.

## 5. Journal target and article type

Target journal: `Scientific Reports`

Article type: `Article`

The manuscript title remains unchanged:

> Landmark-specific transcriptomic and proteomic associations with 60-day mortality in Day-1-defined sepsis-induced coagulopathy: a multicentre longitudinal cohort study

## 6. Main-manuscript structure

The clean submission manuscript will use this order:

1. Title page
2. Abstract
3. Keywords
4. Introduction
5. Results
6. Discussion
7. Methods
8. Data availability
9. Code availability
10. References
11. Acknowledgements
12. Author contributions
13. Competing interests
14. AI-assisted tools in manuscript and code preparation
15. Figure legends
16. Table 1

The existing standalone Conclusions section will be incorporated into the final paragraph of the Discussion.

The manuscript must be single-column, left aligned, with Arabic page numbers in the footer. Line numbering should be enabled for review convenience.

## 7. Abstract and keywords

The abstract must:

- be unstructured and contain no subheadings;
- contain no references;
- be no more than 200 words;
- introduce the clinical problem for a broad scientific audience;
- state the multicentre longitudinal landmark design;
- report only frozen principal results;
- make the conditional Day-5 estimand clear;
- end with a bounded implication rather than a causal or therapeutic claim.

Keywords must be limited to six:

1. Sepsis-induced coagulopathy
2. Multi-omics
3. Landmark analysis
4. Transcriptomics
5. Proteomics
6. Mortality

## 8. Main-text length and readability

The preferred limit for Introduction + Results + Discussion is 4,500 words, excluding Abstract, Methods, References, and figure legends.

The converted manuscript must minimise specialist jargon, define nonstandard abbreviations at first use, and explain landmark analysis, positivity support, and inverse-probability weighting sufficiently for scientifically literate readers outside critical-care biostatistics.

## 9. Main Table 1 and Supplementary Table S9

The main manuscript will retain a one-page concise Table 1.

The concise table will include the clinically central baseline variables agreed with the author, including:

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

The exact variable set may be reduced only when necessary to keep the table legible on one page. Every retained value, denominator, summary statistic, P value, and footnote must match the frozen full baseline table.

The complete original baseline table will become `Supplementary Table S9`. The main table legend and Results text will state that complete baseline characteristics are provided in Supplementary Table S9.

## 10. Supplementary-information design

The supplementary package will use a hybrid structure.

### 10.1 Composite supplementary-information file

Create:

- `Scientific_Reports_Supplementary_Information.docx`
- `Scientific_Reports_Supplementary_Information.pdf`

The first page must contain the manuscript title and complete author list.

The composite file will contain:

- Supplementary Methods;
- Supplementary Figs. S1-S9;
- complete baseline characteristics as Supplementary Table S9;
- titles, descriptions, field notes, and a file index for Supplementary Tables S1-S8.

### 10.2 Machine-readable workbooks

The existing S1-S8 `.xlsx` workbooks will remain separate machine-readable supplementary files. They will not be converted into long PDF tables.

### 10.3 Renumbering

All previous `Supplementary Figure A1-A9` items will be renamed and cited as `Supplementary Fig. S1-S9`.

The renumbering must be propagated consistently through:

- main-manuscript text;
- supplementary-information headings;
- figure legends;
- supplementary table and figure index;
- file names for submission-facing copies;
- README and manifest descriptions;
- any validation scripts that inspect display-item references.

The internal historical JIC release file names need not be changed. New submission-facing copies may be created under Scientific Reports-specific paths.

Every supplementary item must be cited at the appropriate location in the main manuscript. The word `Supplementary` must appear in every citation. Individual panels of supplementary figures must not be cited separately.

The composite supplementary file must be below 50 MB.

## 11. References

References must use standard Nature style:

- sequential numerical citations in square brackets;
- one publication per reference number;
- all authors listed when fewer than six;
- first author followed by `et al.` when six or more authors;
- surname followed by initials;
- journal titles abbreviated and italicised;
- volume number bold;
- full page range or article number;
- year in parentheses.

Reference conversion must preserve citation-to-reference mapping. No reference may be added solely to decorate the Discussion. New references may be added only when they directly support an approved interpretive clarification and have been verified against the primary source.

## 12. Ethics, data, code, and competing interests

The Methods section must contain the complete human-research ethics statement, including:

- approving ethics committee and approval identifier;
- compliance with the Declaration of Helsinki and applicable regulations;
- confirmation of written informed consent from participants or legally authorised representatives, as applicable to the parent study.

The end matter must contain a mandatory Data availability statement. It will distinguish:

- controlled-access participant-level clinical, transcriptomic, and proteomic data under OMIX011182;
- the authors' lack of authority to redistribute those participant-level data;
- public aggregate result tables, figure source data, and reproducibility materials.

A separate Code availability section will point to the Scientific Reports-specific immutable GitHub release after that release exists.

Competing interests will use the explicit statement:

> The authors declare no competing interests.

## 13. AI-use disclosure

The manuscript will include one disclosure subsection at the end of Methods or in the end matter immediately associated with Methods:

### AI-assisted tools in manuscript and code preparation

> ChatGPT (OpenAI) was used as an assistive tool during manuscript drafting, restructuring, language editing, and the development and review of analysis scripts. All analyses were executed through the version-controlled workflow, and the reported numerical results, tables, and figures were verified against the frozen outputs and predefined quality-assurance checks. The authors retained final responsibility for the study design, analytical choices, interpretation, source verification, and conclusions; critically reviewed and revised all AI-assisted material; and approved the final manuscript. Generative AI was not used to create or modify the scientific figures.

This disclosure must not imply AI authorship. ChatGPT must not appear in the author list or author-contribution statement.

## 14. Cover letter

Create `Scientific_Reports_Cover_Letter.docx`.

It must include:

- manuscript title and article type;
- corresponding-author affiliation and contact details exactly matching the manuscript and submission system;
- a concise explanation of suitability for Scientific Reports based on technical validity, multicentre longitudinal design, landmark methodology, multi-omic analysis, and reproducibility;
- a factual transfer statement:

> This manuscript was previously submitted to the Journal of Intensive Care and is now being submitted to Scientific Reports following a Springer Nature journal-transfer recommendation.

- confirmation that the work is original, unpublished, and not under consideration elsewhere;
- confirmation that all authors approved the submission;
- statement that no preferred reviewers are proposed and no reviewer exclusions are requested;
- statement that there were no prior discussions with a Scientific Reports Editorial Board Member;
- controlled-data and public-code boundary where useful.

The cover letter must not imply that Journal of Intensive Care completed scientific peer review or requested specific revisions.

## 15. Change-marking deliverables

Create:

- `Scientific_Reports_manuscript_clean.docx`
- `Scientific_Reports_manuscript_highlighted.docx`
- `Scientific_Reports_revision_report.docx`

The highlighted manuscript will use yellow highlighting only for:

- newly written paragraphs;
- substantially rewritten scientific interpretation;
- methodological-boundary clarifications;
- claim restrictions;
- newly inserted journal-policy disclosures.

Routine section moves, formatting conversion, reference-style conversion, and systematic renumbering will be listed in the revision report rather than highlighted throughout the document.

The revision report will classify substantive edits as:

- `clarification`;
- `interpretive expansion`;
- `claim restriction`;
- `journal compliance`;
- `structural relocation`;
- `cross-reference renumbering`.

## 16. STROBE update

STROBE will be updated only after final manuscript and supplementary pagination are stable.

Create:

- `STROBE_Scientific_Reports_completed.docx`
- `STROBE_Scientific_Reports_audit.tsv`

Every checklist entry must be remapped to the final Scientific Reports section and page. The audit must verify reporting of:

- cohort design;
- eligibility and Day-1 SIC definition;
- Day-3 and Day-5 landmark risk sets;
- outcome definition;
- missing data;
- assay availability;
- positivity assessment;
- inverse-probability weighting;
- Cox and PH diagnostics;
- multiplicity and FDR control;
- sensitivity analyses;
- limitations;
- generalisability;
- ethics;
- data and code availability.

## 17. Quality assurance

The conversion must pass all of the following before release:

### 17.1 Scientific integrity

- all manuscript numerals compared against frozen numerical-truth and source-data layers;
- all main Table 1 values compared against Supplementary Table S9;
- no new scientific result introduced;
- no causal or therapeutic claim unsupported by the design.

### 17.2 Cross-reference integrity

- zero residual `Supplementary Figure A1-A9` citations in submission-facing files;
- all Supplementary Figs. S1-S9 cited;
- all Supplementary Tables S1-S9 cited or indexed appropriately;
- all main figures and tables cited in numerical order;
- no broken figure, table, section, or reference links.

### 17.3 Journal-format integrity

- abstract no more than 200 words and unstructured;
- no more than six keywords;
- title unchanged;
- Introduction + Results + Discussion no more than 4,500 words unless a documented exception is approved;
- no more than eight main display items;
- each figure legend no more than 350 words;
- main Table 1 no more than one page;
- Supplementary Information below 50 MB;
- Nature reference style;
- no graphical abstract.

### 17.4 Document hygiene

- no unresolved comments;
- no tracked changes in clean files;
- no hidden text, accidental fields, or stale hyperlinks;
- page and line numbering visible;
- all tables editable;
- PDF rendering checked page by page;
- fonts embedded or substituted safely;
- figures remain legible at intended size.

### 17.5 Privacy and reproducibility

- no participant-level identifiers or controlled data added;
- public manifest rebuilt;
- SHA-256 hashes regenerated for new release assets;
- existing privacy, semantic, repository, and canonical-hash tests rerun;
- new Scientific Reports metadata tests added where needed.

## 18. Repository and release design

All work will occur on:

- branch: `release/scientific-reports-submission-v1.1`

The original JIC tag and release remain unchanged.

The new release will use:

- tag: `scientific-reports-submission-v1.1`
- target: final merged `main`
- release date: actual publication date of the GitHub release

The release will include:

- Scientific Reports clean manuscript;
- Scientific Reports highlighted manuscript or revision report when appropriate for the repository archive;
- composite Supplementary Information DOCX/PDF;
- S1-S9 supplementary tables and submission-facing index;
- updated STROBE checklist and audit;
- updated README, CITATION metadata, manifest, hashes, and QA outputs.

The public release will not include:

- Cover Letter;
- participant-level clinical or molecular data;
- controlled OMIX files;
- private editorial correspondence;
- private reviewer recommendations;
- internal credentials or local paths.

## 19. Acceptance criteria

The conversion is complete only when:

1. the author-approved scientific freeze is preserved;
2. the clean manuscript, highlighted manuscript, revision report, cover letter, Supplementary Information, S1-S9 files, and STROBE deliverables exist;
3. all Scientific Reports-specific format and policy checks pass;
4. all repository QA checks pass with zero failures;
5. a pull request shows only expected submission-conversion changes;
6. the pull request is merged after author review;
7. `scientific-reports-submission-v1.1` is published from the final `main` commit;
8. the release is publicly accessible in an unauthenticated browser and its source archive contains the expected files.
