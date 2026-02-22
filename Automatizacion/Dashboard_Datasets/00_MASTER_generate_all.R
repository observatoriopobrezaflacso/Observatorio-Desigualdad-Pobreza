# ============================================================================
# MASTER SCRIPT: Generate All Dashboard Datasets
# Purpose: Run all dataset generation scripts in sequence
# Author: Claude + User
# Date: 2026-02-22
# ============================================================================

# Set working directory
setwd("/Users/vero/Documents/Observatorio GH/Observatorio-Desigualdad-Pobreza/Automatizacion/Dashboard_Datasets")

# Install required packages if not already installed
required_packages <- c("haven", "dplyr", "writexl", "tidyr", "Hmisc", "WDI")

for (pkg in required_packages) {
  if (!require(pkg, character.only = TRUE, quietly = TRUE)) {
    cat("Installing package:", pkg, "\n")
    install.packages(pkg, repos = "https://cloud.r-project.org")
  }
}

# ============================================================================
# EXECUTION SEQUENCE
# ============================================================================

cat("\n")
cat("==================================================================\n")
cat("  DASHBOARD DATASET GENERATION - MASTER SCRIPT\n")
cat("==================================================================\n")
cat("\n")

start_time <- Sys.time()

# Define scripts to run
scripts <- c(
  "01_pobreza_educacion.R",
  "02_pobreza_edad.R",
  "03_pobreza_region.R",
  "04_pobreza_multidimensional.R",
  "05_variacion_estadistica.R",
  "06_empleo_toy.R",
  "07_salarios_brechas_toy.R",
  "08_distribucion_crecimiento.R",
  "09_desigualdad.R",
  "10_tributacion.R"
)

# Track results
results <- data.frame(
  script = scripts,
  status = character(length(scripts)),
  time_seconds = numeric(length(scripts)),
  stringsAsFactors = FALSE
)

# Run each script
for (i in seq_along(scripts)) {
  script <- scripts[i]
  cat("\n")
  cat("------------------------------------------------------------------\n")
  cat("[", i, "/", length(scripts), "] Running:", script, "\n")
  cat("------------------------------------------------------------------\n")

  script_start <- Sys.time()

  tryCatch({
    source(script, echo = FALSE)
    script_end <- Sys.time()
    elapsed <- as.numeric(difftime(script_end, script_start, units = "secs"))

    results$status[i] <- "✓ SUCCESS"
    results$time_seconds[i] <- round(elapsed, 2)

    cat("\n✓ Completed in", round(elapsed, 2), "seconds\n")

  }, error = function(e) {
    script_end <- Sys.time()
    elapsed <- as.numeric(difftime(script_end, script_start, units = "secs"))

    results$status[i] <- "✗ FAILED"
    results$time_seconds[i] <- round(elapsed, 2)

    cat("\n✗ ERROR:", conditionMessage(e), "\n")
  })
}

# ============================================================================
# SUMMARY
# ============================================================================

end_time <- Sys.time()
total_time <- as.numeric(difftime(end_time, start_time, units = "secs"))

cat("\n")
cat("==================================================================\n")
cat("  EXECUTION SUMMARY\n")
cat("==================================================================\n")
cat("\n")

print(results, row.names = FALSE)

cat("\n")
cat("Total execution time:", round(total_time / 60, 2), "minutes\n")
cat("Successful scripts:", sum(results$status == "✓ SUCCESS"), "/", nrow(results), "\n")
cat("Failed scripts:", sum(results$status == "✗ FAILED"), "/", nrow(results), "\n")
cat("\n")

# Save summary
write.csv(results, "execution_summary.csv", row.names = FALSE)
cat("Summary saved to: execution_summary.csv\n")

cat("\n")
cat("==================================================================\n")
cat("  OUTPUT LOCATION\n")
cat("==================================================================\n")
cat("\n")
cat("All datasets saved to:\n")
cat("/Users/vero/Documents/Observatorio GH/Observatorio-Desigualdad-Pobreza/Dashboards/Data Final/\n")
cat("\n")
cat("==================================================================\n")

# Return results invisibly
invisible(results)
