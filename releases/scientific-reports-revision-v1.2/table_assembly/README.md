# Aggregate table construction

Run `python analysis/run_current_tables.py NEW_OUTPUT_DIRECTORY` from the package root. This uses existing aggregate results, not participant-level data or model fitting. It prepares clinical displays and diagnostic summaries, then assembles the supplied S1–S18 workbooks.

Each workbook contract specifies its template, typed data blocks and SHA-256 checks. Templates have empty declared blocks; complete result workbooks are not copied back as calculation inputs. Table 1 and S9 use the same normalised clinical summary. S2/S13/S17 diagnostic counts are derived from their designated existing model results. `WORKBOOK_SHEET_MAP.tsv` and `SHEET_INPUT_OUTPUT_MAP.tsv` identify every sheet and input block.

Numeric results are retained at source precision; Excel number formats affect presentation only. Unavailable enrichment results remain blank with their status rather than becoming zero. Tests and FDR calculations are not performed by this entry.
