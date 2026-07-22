import fs from "node:fs/promises";
import path from "node:path";
import { SpreadsheetFile, Workbook } from "@oai/artifact-tool";

const root = process.cwd();
const frozenRoot = process.env.SIC_FROZEN_OUTPUT_ROOT || path.join(
  root,
  "private_outputs",
  "audit_2026-07-15",
  "SIC_reanalysis_2026-07-11",
);
const outputDir = path.join(root, "submission", "supplementary_files");
const previewDir = path.join(root, "private_audit", "supplementary_workbook_previews");
await fs.mkdir(outputDir, { recursive: true });
await fs.mkdir(previewDir, { recursive: true });

const COLORS = {
  navy: "#1F4E78",
  paleBlue: "#DCE6F1",
  paleGray: "#F2F2F2",
  white: "#FFFFFF",
  text: "#222222",
  line: "#D9E2F3",
};

const TABLE1_CLINICAL_LABELS = {
  age: "Age",
  height: "Height",
  weight: "Weight",
  BMI: "BMI",
  hrmax: "HRmax",
  mapmax: "MAPmax",
  sapmax: "SBPmax",
  rrmax: "RRmax",
  tmax: "Tmax",
  lac: "Lactate",
  k: "K",
  na: "Na",
  cl: "Cl",
  bun: "BUN",
  alb: "Albumin",
  cr: "Creatinine",
  bilirubin: "Bilirubin",
  crp: "CRP",
  procal: "PCT",
  wbc: "WBC count",
  plt: "Platelet count",
  inr: "INR",
  aptt: "aPTT",
  ddimer: "D-dimer",
  SOFA: "SOFA score",
  pf: "PaO₂/FiO₂ ratio",
  sex: "Male sex",
  diabete: "Diabetes mellitus",
  hyperten: "Hypertension",
  myoinfarc: "Myocardial infarction",
  cardiofailure: "Heart failure",
  cerebrovasc: "Cerebrovascular disease",
  dementia: "Dementia",
  copd: "COPD",
  paralysis: "Paralysis",
  renafailure: "Renal failure",
  infectionSite_SD: "Infection source",
};

const TABLE1_INFECTION_CONTRASTS = {
  "Abdomen vs Lung/Chest": "Abdomen vs Lung/chest",
  "Biliary/Liver vs Lung/Chest": "Biliary/liver vs Lung/chest",
  "Others/Unknown vs Lung/Chest": "Others/unknown vs Lung/chest",
  "SoftTissue vs Lung/Chest": "Soft tissue vs Lung/chest",
  "Urinary vs Lung/Chest": "Urinary vs Lung/chest",
};

function source(...parts) {
  return path.join(frozenRoot, ...parts);
}

async function requireFile(file) {
  try {
    await fs.access(file);
  } catch {
    throw new Error(`Required frozen aggregate file is missing: ${file}`);
  }
}

function columnName(index) {
  let n = index + 1;
  let out = "";
  while (n > 0) {
    const rem = (n - 1) % 26;
    out = String.fromCharCode(65 + rem) + out;
    n = Math.floor((n - 1) / 26);
  }
  return out;
}

function writeReadme(sheet, meta) {
  const rows = [
    ["Field", "Description"],
    ["Supplementary table", meta.id],
    ["Title", meta.title],
    ["Population / analysis", meta.population],
    ["Contents", meta.contents],
    ["Statistical definition", meta.statistics],
    ["Interpretation limitation", meta.limitation],
    ["Data-access note", "Participant-level CMAISE data are controlled access under OMIX011182 and are not redistributed in this workbook."],
    ["Reproducibility note", "Values were copied from frozen aggregate result files; no statistical model was refitted during workbook assembly."],
  ];
  sheet.getRange(`A1:B${rows.length}`).values = rows;
  sheet.showGridLines = false;
  sheet.freezePanes.freezeRows(1);
  sheet.getRange("A1:B1").format = {
    fill: COLORS.navy,
    font: { bold: true, color: COLORS.white },
    borders: { preset: "outside", style: "thin", color: COLORS.navy },
  };
  sheet.getRange(`A2:A${rows.length}`).format = {
    fill: COLORS.paleBlue,
    font: { bold: true, color: COLORS.text },
  };
  sheet.getRange(`A1:B${rows.length}`).format.wrapText = true;
  sheet.getRange(`A1:B${rows.length}`).format.verticalAlignment = "center";
  sheet.getRange(`A1:A${rows.length}`).format.columnWidth = 24;
  sheet.getRange(`B1:B${rows.length}`).format.columnWidth = 92;
  sheet.getRange(`A1:B${rows.length}`).format.autofitRows();
}

async function addCsvSheet(workbook, csvPath, sheetName) {
  await requireFile(csvPath);
  const csvText = await fs.readFile(csvPath, "utf8");
  // The instance fromCSV method can only hydrate an empty collaborative
  // document. Import each CSV into a temporary workbook, then copy the parsed
  // values into the assembled multi-sheet workbook.
  const imported = await Workbook.fromCSV(csvText, { sheetName });
  const importedSheet = imported.worksheets.getItem(sheetName);
  const importedUsed = importedSheet.getUsedRange(true);
  const values = importedUsed.values;
  const sheet = workbook.worksheets.add(sheetName);
  const maxCols = Math.max(...values.map((row) => row.length));
  const rectangular = values.map((row) => [
    ...row,
    ...Array(maxCols - row.length).fill(null),
  ]);
  if (sheetName === "Univariable_Cox") {
    const headers = rectangular[0].map((value) => String(value ?? ""));
    const variableIndex = headers.indexOf("Variable");
    const labelIndex = headers.indexOf("Label");
    const contrastIndex = headers.indexOf("Contrast");
    const referenceIndex = headers.indexOf("Reference");
    if ([variableIndex, labelIndex, contrastIndex, referenceIndex].some((x) => x < 0)) {
      throw new Error("Supplementary Table S2 display columns were not found");
    }
    for (let rowIndex = 1; rowIndex < rectangular.length; rowIndex += 1) {
      const variable = String(rectangular[rowIndex][variableIndex] ?? "");
      const displayLabel = TABLE1_CLINICAL_LABELS[variable];
      if (!displayLabel) {
        throw new Error(`No Table 1 display label mapped for ${variable}`);
      }
      rectangular[rowIndex][labelIndex] = displayLabel;
      if (variable === "infectionSite_SD") {
        const contrast = String(rectangular[rowIndex][contrastIndex] ?? "");
        const displayContrast = TABLE1_INFECTION_CONTRASTS[contrast];
        if (!displayContrast) {
          throw new Error(`No Table 1 infection-source contrast mapped for ${contrast}`);
        }
        rectangular[rowIndex][contrastIndex] = displayContrast;
        rectangular[rowIndex][referenceIndex] = "Lung/chest";
      }
    }
  }
  sheet.getRangeByIndexes(0, 0, rectangular.length, maxCols).values = rectangular;
  const used = sheet.getUsedRange(true);
  const headerLine = csvText.split(/\r?\n/, 1)[0];
  const headers = headerLine.split(",").map((x) => x.replace(/^"|"$/g, ""));
  const rows = csvText.split(/\r?\n/).length - 1;
  const cols = headers.length;
  const endCol = columnName(cols - 1);
  sheet.showGridLines = false;
  sheet.freezePanes.freezeRows(1);
  sheet.getRange(`A1:${endCol}1`).format = {
    fill: COLORS.navy,
    font: { bold: true, color: COLORS.white },
    borders: { preset: "outside", style: "thin", color: COLORS.navy },
    wrapText: true,
    verticalAlignment: "center",
  };
  if (rows > 0) {
    sheet.getRange(`A2:${endCol}${rows + 1}`).format = {
      font: { color: COLORS.text },
      borders: {
        insideHorizontal: { style: "thin", color: COLORS.line },
      },
      verticalAlignment: "center",
    };
  }
  for (let i = 0; i < cols; i += 1) {
    const header = headers[i].toLowerCase();
    let width = 15;
    if (/label|variable|pathway|contrast|reference|note|leading|diagnostic|model/.test(header)) width = 28;
    if (/gene|protein|symbol|feature/.test(header)) width = 20;
    if (/p_value|pval|fdr|hazard|hr|lower|upper|beta|rho|nes|se$|ci/.test(header)) width = 14;
    const col = columnName(i);
    sheet.getRange(`${col}1:${col}${Math.max(rows + 1, 2)}`).format.columnWidth = width;
  }
  used.format.rowHeight = 16;
  sheet.getRange(`A1:${endCol}1`).format.rowHeight = 30;
  return sheet;
}

async function exportAndPreview(workbook, fileName) {
  const outputPath = path.join(outputDir, fileName);
  const xlsx = await SpreadsheetFile.exportXlsx(workbook);
  await xlsx.save(outputPath);
  const readme = workbook.worksheets.getItem("README");
  const preview = await workbook.render({
    sheetName: readme.name,
    range: "A1:B9",
    scale: 1.25,
    format: "png",
  });
  const previewBytes = new Uint8Array(await preview.arrayBuffer());
  await fs.writeFile(path.join(previewDir, fileName.replace(/\.xlsx$/, ".png")), previewBytes);
  return outputPath;
}

async function buildCsvWorkbook(spec) {
  const existing = path.join(outputDir, spec.fileName);
  if (process.env.SIC_REBUILD_SUPPLEMENTS !== "TRUE") {
    try {
      await fs.access(existing);
      return existing;
    } catch {
      // Build the missing workbook below.
    }
  }
  const workbook = Workbook.create();
  const readme = workbook.worksheets.add("README");
  writeReadme(readme, spec);
  for (const sheet of spec.sheets) {
    await addCsvSheet(workbook, source(...sheet.source), sheet.name);
  }
  return exportAndPreview(workbook, spec.fileName);
}

async function buildSanitisedS8Workbook(inputPath, outputPath) {
  const sourceDir = path.dirname(inputPath);
  const sheetFiles = {
    Entry_risksets: "SupplementaryTable_Entry_risksets.tsv",
    Centre_positivity: "SupplementaryTable_Centre_positivity.tsv",
    Time_origin_audit: "SupplementaryTable_Time_origin_audit.tsv",
    Covariate_missingness: "SupplementaryTable_Covariate_missingness.tsv",
    Protein_availability: "SupplementaryTable_Protein_availability.tsv",
    Prefit_diagnostics: "SupplementaryTable_Prefit_diagnostics.tsv",
    Weight_diagnostics: "SupplementaryTable_Weight_diagnostics.tsv",
    Balance_SMD: "SupplementaryTable_Balance_SMD.tsv",
    Transform_constants: "SupplementaryTable_Transform_constants.tsv",
    Cox_PH_audit: "SupplementaryTable_Cox_PH_audit.tsv",
    Hallmark_all_models: "SupplementaryTable_Hallmark_all_models.tsv",
    Hallmark_leading_edges: "SupplementaryTable_Hallmark_leading_edges.tsv",
    Hallmark_comparison: "SupplementaryTable_Hallmark_comparison.tsv",
    Scenario_metrics: "SupplementaryTable_Scenario_metrics.tsv",
    Frozen_internal_QA: "SupplementaryTable_Frozen_internal_QA.tsv",
  };
  const workbook = Workbook.create();
  const previewRanges = new Map();
  const prohibited = new Set(["PatientID", "SampleName"]);
  let removed = 0;
  for (const [sheetName, fileName] of Object.entries(sheetFiles)) {
    const tsvPath = path.join(sourceDir, fileName);
    await requireFile(tsvPath);
    const text = (await fs.readFile(tsvPath, "utf8")).replace(/^\uFEFF/, "");
    const rows = text
      .split(/\r?\n/)
      .filter((line) => line.length > 0)
      .map((line) => line.split("\t").map((value) => {
        const trimmed = value.trim();
        if (trimmed === "") return null;
        if (/^-?(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?$/.test(trimmed)) {
          return Number(trimmed);
        }
        return value;
      }));
    const filtered = rows.filter((row) => {
      const containsIdentifier = row.some(
        (value) => prohibited.has(String(value ?? "").trim()),
      );
      if (containsIdentifier) removed += 1;
      return !containsIdentifier;
    });
    const maxCols = Math.max(...filtered.map((row) => row.length));
    const rectangular = filtered.map((row) => [
      ...row,
      ...Array(maxCols - row.length).fill(null),
    ]);
    const worksheet = workbook.worksheets.add(sheetName);
    worksheet.getRangeByIndexes(0, 0, rectangular.length, maxCols).values = rectangular;
    worksheet.showGridLines = false;
    worksheet.freezePanes.freezeRows(1);
    const endCol = columnName(maxCols - 1);
    previewRanges.set(sheetName, `A1:${endCol}${Math.min(rectangular.length, 40)}`);
    worksheet.getRange(`A1:${endCol}1`).format = {
      fill: COLORS.navy,
      font: { bold: true, color: COLORS.white },
      borders: { preset: "outside", style: "thin", color: COLORS.navy },
      wrapText: true,
      verticalAlignment: "center",
    };
    if (rectangular.length > 1) {
      worksheet.getRange(`A2:${endCol}${rectangular.length}`).format = {
        borders: {
          insideHorizontal: { style: "thin", color: COLORS.line },
        },
        verticalAlignment: "center",
      };
    }
    for (let colIndex = 0; colIndex < maxCols; colIndex += 1) {
      const header = String(rectangular[0][colIndex] ?? "").toLowerCase();
      let width = 15;
      if (/pathway|variable|model|analysis|diagnostic|leading|scenario|criterion/.test(header)) width = 28;
      if (/gene|symbol|feature|centre|center/.test(header)) width = 20;
      worksheet.getRange(
        `${columnName(colIndex)}1:${columnName(colIndex)}${rectangular.length}`,
      ).format.columnWidth = width;
    }
    worksheet.getRange(`A1:${endCol}1`).format.rowHeight = 30;
  }
  if (![0, 3].includes(removed)) {
    throw new Error(`Unexpected S8 identifier-audit rows removed: ${removed}`);
  }

  const visibleValues = workbook.worksheets.items.flatMap((worksheet) => {
    const range = worksheet.getUsedRange(true);
    return range ? range.values.flat() : [];
  });
  if (visibleValues.some((value) => prohibited.has(String(value ?? "").trim()))) {
    throw new Error("S8 still contains a visible direct-identifier label");
  }
  const formulaError = /^(#REF!|#DIV\/0!|#VALUE!|#NAME\?|#N\/A)$/;
  if (visibleValues.some((value) => formulaError.test(String(value ?? "").trim()))) {
    throw new Error("S8 contains a visible formula error");
  }
  const inspectResults = [];
  for (const worksheet of workbook.worksheets.items) {
    for (const [label, searchTerm] of [
      ["privacy", "PatientID|SampleName"],
      ["formula", "#REF!|#DIV/0!|#VALUE!|#NAME\\?|#N/A"],
    ]) {
      const result = await workbook.inspect({
        kind: "match",
        sheetId: worksheet.name,
        range: previewRanges.get(worksheet.name),
        searchTerm,
        options: { useRegex: true, maxResults: 20 },
        summary: `S8 ${label} scan: ${worksheet.name}`,
        maxChars: 2000,
      });
      inspectResults.push(result.ndjson);
    }
  }
  await fs.writeFile(
    path.join(previewDir, "S8_privacy_and_formula_inspect.ndjson"),
    `${inspectResults.join("\n")}\n`,
    "utf8",
  );

  const s8PreviewDir = path.join(previewDir, "S8_all_sheets");
  await fs.mkdir(s8PreviewDir, { recursive: true });
  for (const worksheet of workbook.worksheets.items) {
    const preview = await workbook.render({
      sheetName: worksheet.name,
      range: previewRanges.get(worksheet.name),
      scale: 1,
      format: "png",
    });
    await fs.writeFile(
      path.join(s8PreviewDir, `${worksheet.name}.png`),
      new Uint8Array(await preview.arrayBuffer()),
    );
  }

  const xlsx = await SpreadsheetFile.exportXlsx(workbook);
  await xlsx.save(outputPath);
  const inspectSidecar = `${outputPath}.inspect.ndjson`;
  try {
    await fs.copyFile(
      inspectSidecar,
      path.join(previewDir, "S8_export_inspect.ndjson"),
    );
    await fs.unlink(inspectSidecar);
  } catch (error) {
    if (error?.code !== "ENOENT") throw error;
  }
  return outputPath;
}

const specs = [
  {
    id: "Supplementary Table S1",
    fileName: "Supplementary_Table_S1_Clinical_variable_definitions.xlsx",
    title: "Clinical variable definitions, transformations and prespecified data handling",
    population: "Day-1 SIC cohort and clinical-data audit supporting Table 1 and the exploratory clinical Cox analysis.",
    contents: "Variable dictionary, infection-source mapping, variables excluded for missingness and aggregate sparse-event audit.",
    statistics: "Definitions and audit outputs only; no new inferential model is introduced.",
    limitation: "This workbook documents prespecified processing and does not provide time-updated Day-3 or Day-5 clinical physiology.",
    sheets: [
      { name: "Variable_dictionary", source: ["05_Clinical_Tables", "Clinical_variable_dictionary.csv"] },
      { name: "Infection_mapping", source: ["05_Clinical_Tables", "Clinical_infection_source_mapping.csv"] },
      { name: "Excluded_missing", source: ["05_Clinical_Tables", "Clinical_excluded_missing_variables.csv"] },
      { name: "Sparse_event_audit", source: ["05_Clinical_Tables", "Clinical_sparse_event_audit.csv"] },
    ],
  },
  {
    id: "Supplementary Table S2",
    fileName: "Supplementary_Table_S2_Clinical_univariable_Cox.xlsx",
    title: "Exploratory clinical univariable Cox regression results",
    population: "504 patients meeting the Day-1 SIC definition; 84 deaths within 60 days.",
    contents: "All 41 prespecified displayed contrasts with HR, 95% CI, nominal P value, BH-FDR, PH diagnostic, nonlinearity diagnostic and sparse-event flags.",
    statistics: "Separate univariable Cox models with Efron handling of ties; BH correction across displayed contrasts; infection source also assessed by an overall likelihood-ratio test.",
    limitation: "Associations are descriptive clinical context and are not independent predictors, causal effects or covariate-selection criteria for molecular models.",
    sheets: [
      { name: "Univariable_Cox", source: ["05_Clinical_Tables", "Clinical_univariable_Cox.csv"] },
      { name: "Diagnostics", source: ["05_Clinical_Tables", "Clinical_analysis_diagnostics.csv"] },
    ],
  },
  {
    id: "Supplementary Table S3",
    fileName: "Supplementary_Table_S3_RNA_gene_wise_Cox_PH.xlsx",
    title: "Time-specific RNA gene-wise Cox and proportional-hazards results",
    population: "Risk-valid whole-blood RNA-seq samples at Days 1, 3 and 5 using separate landmark-specific survival models.",
    contents: "All gene-wise centre-stratified Cox estimates, Wald-z statistics, BH-FDR values and exact proportional-hazards diagnostics, plus model diagnostics.",
    statistics: "Surv(entry, stop, event) ~ gene_z + strata(centre), Efron ties; Day-3 and Day-5 models use delayed entry at the prespecified sampling landmarks.",
    limitation: "Gene-wise associations are exploratory prognostic rankings and do not establish independent biomarkers or causal mechanisms.",
    sheets: [
      { name: "Gene_Cox_PH", source: ["01_RNA_TMM", "02_all_RNA_TMM_center_stratified_cox_zph.csv"] },
      { name: "Cox_diagnostics", source: ["01_RNA_TMM", "05_RNA_TMM_Cox_diagnostics.csv"] },
    ],
  },
  {
    id: "Supplementary Table S4",
    fileName: "Supplementary_Table_S4_RNA_Hallmark_GSEA.xlsx",
    title: "RNA Hallmark GSEA and leading-edge results",
    population: "Complete time-specific RNA Cox Wald-z rankings at Days 1, 3 and 5.",
    contents: "Primary and PH-pass Hallmark results, complete leading-edge genes and GSEA diagnostics.",
    statistics: "fgseaMultilevel against the complete Hallmark family; BH-FDR calculated within each time point and analysis family.",
    limitation: "NES encodes enrichment along mortality-associated rankings, not absolute pathway activation or longitudinal change in expression.",
    sheets: [
      { name: "Hallmark_GSEA", source: ["01_RNA_TMM", "03_RNA_TMM_Hallmark_primary_PHpass.csv"] },
      { name: "Leading_edges", source: ["01_RNA_TMM", "04_RNA_TMM_Hallmark_leading_edge_long.csv"] },
      { name: "GSEA_diagnostics", source: ["01_RNA_TMM", "05_RNA_TMM_GSEA_diagnostics.csv"] },
    ],
  },
  {
    id: "Supplementary Table S5",
    fileName: "Supplementary_Table_S5_Protein_wise_Cox_PH.xlsx",
    title: "Time-specific plasma protein Cox and proportional-hazards results",
    population: "Risk-valid plasma proteomic samples at Days 1, 3 and 5.",
    contents: "All centre-stratified primary and sample-median-adjusted sensitivity models, PH diagnostics and model diagnostics.",
    statistics: "Separate landmark-specific Cox models with centre stratification; protein abundance is standardised within time point.",
    limitation: "Later protein analyses have limited subsequent events, especially Day 5, and are interpreted at pathway level as hypothesis-generating evidence.",
    sheets: [
      { name: "Protein_Cox_PH", source: ["02_Protein", "02_all_Protein_models_cox_zph.csv"] },
      { name: "Model_diagnostics", source: ["02_Protein", "05_Protein_model_diagnostics.csv"] },
    ],
  },
  {
    id: "Supplementary Table S6",
    fileName: "Supplementary_Table_S6_Protein_Hallmark_GSEA.xlsx",
    title: "Plasma protein Hallmark GSEA and leading-edge results",
    population: "Complete protein-wise Cox Wald-z rankings from primary and prespecified sensitivity models.",
    contents: "All Hallmark model results, complete leading-edge proteins and GSEA diagnostics.",
    statistics: "fgseaMultilevel with BH-FDR correction within each time point and model family.",
    limitation: "The Hallmark epithelial-mesenchymal transition label is interpreted as extracellular-matrix/tissue-remodelling enrichment when supported by its protein leading edge, not as proof of a cellular transition.",
    sheets: [
      { name: "Hallmark_all_models", source: ["02_Protein", "03_Protein_Hallmark_all_models.csv"] },
      { name: "Leading_edges", source: ["02_Protein", "04_Protein_Hallmark_leading_edge_long.csv"] },
      { name: "GSEA_diagnostics", source: ["02_Protein", "05_Protein_GSEA_diagnostics.csv"] },
    ],
  },
  {
    id: "Supplementary Table S7",
    fileName: "Supplementary_Table_S7_Cross_omics_models.xlsx",
    title: "Contemporaneous, forward and reverse-order cross-omic pathway models",
    population: "Patients with matched whole-blood RNA and plasma protein pathway scores for the relevant time point or interval.",
    contents: "Adjusted contemporaneous partial Spearman correlations, forward RNA-to-later-protein models, reverse-order protein-to-later-RNA models and feature coverage.",
    statistics: "Prespecified clinical and technical adjustment with BH-FDR correction within each model family; forward models condition on the prior protein score.",
    limitation: "Temporal asymmetry is an observational cross-compartment association and does not establish causal transfer, translation lag or mediation.",
    sheets: [
      { name: "Same_time", source: ["03_CrossOmics", "04_same_time_RNA_Protein_partial_spearman.csv"] },
      { name: "Forward_models", source: ["03_CrossOmics", "05_forward_cross_lag_HC3.csv"] },
      { name: "Reverse_models", source: ["03_CrossOmics", "06_reverse_cross_lag_HC3.csv"] },
      { name: "Feature_coverage", source: ["03_CrossOmics", "07_core_pathway_feature_coverage.csv"] },
    ],
  },
];

const outputs = [];
for (const spec of specs) {
  outputs.push(await buildCsvWorkbook(spec));
}

const s8Input = path.join(
  root,
  "submission",
  "public_source_data",
  "Supplementary_Tables_Availability_IPW.xlsx",
);
await requireFile(s8Input);
const s8Output = path.join(outputDir, "Supplementary_Table_S8_D5_availability_IPW.xlsx");
await buildSanitisedS8Workbook(s8Input, s8Output);
// Keep the public source-data copy aligned with the independently uploadable
// workbook. This removes identifier-field audit rows only; no frozen statistic
// or inferential result is changed.
await fs.copyFile(s8Output, s8Input);
outputs.push(s8Output);

const figureRows = [];
for (let i = 1; i <= 9; i += 1) {
  const names = {
    1: "centre_positivity",
    2: "probability_weight_distributions",
    3: "pre_post_weight_SMD",
    4: "all_Hallmark_unweighted_vs_IPW",
    5: "core_pathway_scenario_heatmap",
    6: "six_scenario_robustness_metrics",
    7: "entry_boundary_sensitivity",
    8: "D5_protein_availability",
    9: "clinical_univariable_Cox",
  };
  figureRows.push([
    `A${i}`,
    "Supplementary figure",
    `Supplementary_Figure_A${i}_${names[i]}.pdf`,
    `submission/figures/Supplementary_Figure_A${i}_${names[i]}.pdf`,
    "PDF for submission; SVG/TIFF/PNG repository exports are also provided.",
  ]);
}
const tableFiles = [
  "Supplementary_Table_S1_Clinical_variable_definitions.xlsx",
  "Supplementary_Table_S2_Clinical_univariable_Cox.xlsx",
  "Supplementary_Table_S3_RNA_gene_wise_Cox_PH.xlsx",
  "Supplementary_Table_S4_RNA_Hallmark_GSEA.xlsx",
  "Supplementary_Table_S5_Protein_wise_Cox_PH.xlsx",
  "Supplementary_Table_S6_Protein_Hallmark_GSEA.xlsx",
  "Supplementary_Table_S7_Cross_omics_models.xlsx",
  "Supplementary_Table_S8_D5_availability_IPW.xlsx",
];
const tableRows = tableFiles.map((file, index) => [
  `S${index + 1}`,
  "Supplementary table",
  file,
  `submission/supplementary_files/${file}`,
  "Aggregate result workbook; no participant or sample identifiers.",
]);
const manifestRows = [
  ["manuscript_id", "attachment_type", "filename", "repository_path", "submission_note"],
  ...tableRows,
  ...figureRows,
];
const manifestText = manifestRows.map((row) => row.join("\t")).join("\n") + "\n";
await fs.writeFile(
  path.join(root, "submission", "manuscript_support", "Supplementary_upload_manifest.tsv"),
  manifestText,
  "utf8",
);

console.log(`Created ${outputs.length} supplementary workbooks in ${outputDir}`);
process.exitCode = 0;
