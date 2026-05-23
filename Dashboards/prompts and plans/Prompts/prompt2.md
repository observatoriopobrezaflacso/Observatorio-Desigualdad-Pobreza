---



# Dashboard Build Prompt

**Role:** You are extending and improving the dashboard created in /docs using the specifications in Dashboards/Dashboard outline.docx.

---

## Step 1 — Plan (do this BEFORE writing any code or generating data)

* Review the specifications in Dashboards/Dashboard outline.docx thoroughly.
* Review the existing datasets in ` `Dashboards/`Data Final/ ` to understand the schema, format (file type, column naming conventions, delimiters), and structure.
* Identify every graph/visualization required by the specs.
* For each graph, determine which dataset(s) it needs.
* Compare against existing datasets in ` `Dashboards/`Data Final/ ` — note which already exist and which are missing.
* Output a table listing:  **Graph Name → Required Dataset(s) → Status (Exists / Needs Generation)** .
* **STOP and wait for my approval before proceeding.**

---

## Step 2 — Generate Missing Datasets

* Generate only the missing datasets identified in Step 1.
* Match the exact format of existing datasets in `Dashboards/Data Final/` (same file type, column naming conventions, data types, date formats, etc.).
* Save all new datasets to `Dashboards/Data Final/`.
* Summarize what was generated.
* Generate all the scripts using R and save them in the  Dashboards folder.
* Test the scripts and fix errors.

---

## Step 3 — Build the Dashboard

* Extend and improve the dashboard in /docs per the Dashboards/Dashboard outline.docx specifications using all datasets (existing + newly generated).
* Ensure every graph from the spec is represented.

---

## Constraints

* Do not skip or combine steps.
* Do not generate datasets that already exist — reuse them.
* If anything in the specs is ambiguous, ask before assuming.
