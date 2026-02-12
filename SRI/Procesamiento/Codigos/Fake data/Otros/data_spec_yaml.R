# =============================================================================
# HUMAN-READABLE DATA SPECIFICATION (YAML FORMAT)
# =============================================================================
# This script provides functions to convert data_spec objects to/from YAML
# format, which is much easier to read and edit by humans.
#
# YAML format advantages:
# - Human-readable and editable
# - Can be version-controlled with meaningful diffs
# - Can be reviewed/audited by non-programmers
# - Still fully machine-parseable
# =============================================================================

# Install yaml package if needed
if (!require("yaml", quietly = TRUE)) {
  install.packages("yaml")
}
library(yaml)

# Null-coalescing operator (in case not loaded from main script)
if (!exists("%||%")) {
  `%||%` <- function(x, y) if (is.null(x)) y else x
}

# Source the main synthetic data generation script
# Try to find it relative to this script, or in current directory
tryCatch({
  this_script <- sys.frame(1)$ofile
  if (!is.null(this_script)) {
    source(file.path(dirname(this_script), "fake_data_creation2.R"))
  } else {
    source("fake_data_creation2.R")
  }
}, error = function(e) {
  # Fallback: try current directory
  source("fake_data_creation2.R")
})

# -----------------------------------------------------------------------------
# CONVERT DATA_SPEC TO YAML
# -----------------------------------------------------------------------------

#' Convert a data_spec object to a clean list for YAML export
#' @param data_spec data specification object
#' @return list suitable for YAML conversion
spec_to_yaml_list <- function(data_spec) {

  # Convert variable specs to a cleaner format
  vars_list <- lapply(data_spec$variables, function(var) {
    # Remove NULL values and convert special types
    var_clean <- Filter(Negate(is.null), var)

    # Convert named vectors to lists for better YAML display
    if (!is.null(var_clean$value_labels)) {
      var_clean$value_labels <- as.list(var_clean$value_labels)
    }
    if (!is.null(var_clean$quantiles)) {
      var_clean$quantiles <- as.list(var_clean$quantiles)
    }
    if (!is.null(var_clean$category_probs) && !is.null(var_clean$categories)) {
      # Combine categories and probs for readability
      names(var_clean$category_probs) <- as.character(var_clean$categories)
      var_clean$category_probs <- as.list(var_clean$category_probs)
    }

    # Round numeric values for readability
    numeric_fields <- c("mean", "sd", "min", "max", "skewness", "cv",
                        "missing_prop", "log_mean", "log_sd")
    for (field in numeric_fields) {
      if (!is.null(var_clean[[field]]) && is.numeric(var_clean[[field]])) {
        var_clean[[field]] <- round(var_clean[[field]], 6)
      }
    }

    return(var_clean)
  })

  # Create metadata section
  # Handle both extraction_date and creation_date (for manually created specs)
  date_field <- data_spec$extraction_date %||% data_spec$creation_date %||% Sys.time()

  metadata <- list(
    n_original = data_spec$n_original,
    n_vars = data_spec$n_vars,
    extraction_date = format(date_field, "%Y-%m-%d %H:%M:%S"),
    format_version = "1.0"
  )

  list(
    metadata = metadata,
    variables = vars_list
  )
}

#' Save data_spec to YAML file
#' @param data_spec data specification object
#' @param file path to save YAML file
#' @param include_header include explanatory header comments
save_spec_yaml <- function(data_spec, file, include_header = TRUE) {

  yaml_list <- spec_to_yaml_list(data_spec)

  # Custom YAML handler for better formatting
  yaml_content <- yaml::as.yaml(yaml_list,
                                 indent = 2,
                                 indent.mapping.sequence = TRUE)

  if (include_header) {
    header <- paste0(
      "# =============================================================================\n",
      "# DATA SPECIFICATION FILE\n",
      "# =============================================================================\n",
      "# This file describes the statistical properties of a dataset.\n",
      "# It can be used to generate synthetic data with similar characteristics.\n",
      "#\n",
      "# Variable types:\n",
      "#   - numeric: Continuous or discrete numbers\n",
      "#   - character: Text strings\n",
      "#   - character_labelled: Labelled categorical (Stata-style)\n",
      "#\n",
      "# Distribution forms (dist_form):\n",
      "#   - normal: Gaussian distribution\n",
      "#   - lognormal: Right-skewed positive values\n",
      "#   - categorical: Discrete categories with probabilities\n",
      "#   - heavy_tailed: Extreme values, use quantile-based generation\n",
      "#   - numeric_id: Unique identifier (integer-like)\n",
      "#   - categorical_string: Text categories\n",
      "#   - high_cardinality_id: Many unique values (ID-like)\n",
      "# =============================================================================\n\n"
    )
    yaml_content <- paste0(header, yaml_content)
  }

  writeLines(yaml_content, file)
  message("Data specification saved to: ", file)
}

#' Load data_spec from YAML file
#' @param file path to YAML file
#' @return data_spec object
load_spec_yaml <- function(file) {

  yaml_list <- yaml::read_yaml(file)

  # Convert variables back to proper format
  variables <- lapply(yaml_list$variables, function(var) {

    # Convert value_labels back to named vector
    if (!is.null(var$value_labels)) {
      labels <- unlist(var$value_labels)
      var$value_labels <- setNames(labels, names(var$value_labels))
    }

    # Convert quantiles back to named vector
    if (!is.null(var$quantiles)) {
      quants <- unlist(var$quantiles)
      var$quantiles <- setNames(quants, names(var$quantiles))
    }

    # Convert category_probs back
    if (!is.null(var$category_probs)) {
      if (is.list(var$category_probs)) {
        probs <- unlist(var$category_probs)
        cat_names <- names(probs)

        # Check if categories are numeric or character
        if (var$dist_form == "categorical_string" ||
            var$type == "character" ||
            any(is.na(suppressWarnings(as.numeric(cat_names))))) {
          # Keep as character
          var$categories <- cat_names
        } else {
          # Convert to numeric
          var$categories <- as.numeric(cat_names)
        }
        var$category_probs <- as.numeric(probs)
      }
    }

    return(var)
  })

  # Reconstruct data_spec object
  extraction_date <- tryCatch(
    as.POSIXct(yaml_list$metadata$extraction_date),
    error = function(e) Sys.time()
  )

  data_spec <- list(
    variables = variables,
    n_original = yaml_list$metadata$n_original,
    n_vars = yaml_list$metadata$n_vars,
    var_names = names(variables),
    extraction_date = extraction_date
  )

  class(data_spec) <- c("data_spec", "list")

  return(data_spec)
}

# -----------------------------------------------------------------------------
# CONVERT DATA_SPEC TO CSV (for tabular view)
# -----------------------------------------------------------------------------

#' Convert data_spec to a summary data frame
#' @param data_spec data specification object
#' @return data frame with one row per variable
spec_to_dataframe <- function(data_spec) {

  rows <- lapply(data_spec$variables, function(var) {
    data.frame(
      name = var$name,
      type = var$type %||% NA,
      dist_form = var$dist_form %||% NA,
      n_unique = var$n_unique %||% NA,
      missing_pct = round((var$missing_prop %||% 0) * 100, 2),
      mean = round(var$mean %||% NA, 4),
      sd = round(var$sd %||% NA, 4),
      min = round(var$min %||% NA, 4),
      max = round(var$max %||% NA, 4),
      n_categories = length(var$categories %||% NULL),
      is_labelled = var$is_labelled %||% FALSE,
      stata_label = var$stata_label %||% NA,
      stringsAsFactors = FALSE
    )
  })

  do.call(rbind, rows)
}

#' Save data_spec summary to CSV
#' @param data_spec data specification object
#' @param file path to save CSV file
save_spec_csv <- function(data_spec, file) {
  df <- spec_to_dataframe(data_spec)
  write.csv(df, file, row.names = FALSE)
  message("Summary CSV saved to: ", file)
}

# -----------------------------------------------------------------------------
# PRETTY PRINT DATA_SPEC
# -----------------------------------------------------------------------------

#' Print a human-readable summary of a data_spec
#' @param data_spec data specification object
#' @param max_vars maximum number of variables to show in detail
print_spec_summary <- function(data_spec, max_vars = 20) {

  cat("\n")
  cat("================================================================================\n")
  cat("                         DATA SPECIFICATION SUMMARY\n")
  cat("================================================================================\n\n")

  cat("METADATA:\n")
  cat("  Original rows:    ", format(data_spec$n_original, big.mark = ","), "\n")
  cat("  Variables:        ", data_spec$n_vars, "\n")
  cat("  Extracted:        ", as.character(data_spec$extraction_date), "\n\n")

  # Type summary
  types <- sapply(data_spec$variables, function(v) v$type)
  dist_forms <- sapply(data_spec$variables, function(v) v$dist_form)

  cat("VARIABLE TYPES:\n")
  type_table <- table(types)
  for (t in names(type_table)) {
    cat("  ", sprintf("%-20s", t), ": ", type_table[t], "\n")
  }

  cat("\nDISTRIBUTION FORMS:\n")
  dist_table <- table(dist_forms)
  for (d in names(dist_table)) {
    cat("  ", sprintf("%-20s", d), ": ", dist_table[d], "\n")
  }

  cat("\n--------------------------------------------------------------------------------\n")
  cat("VARIABLE DETAILS (showing first ", min(max_vars, data_spec$n_vars), " of ", data_spec$n_vars, "):\n")
  cat("--------------------------------------------------------------------------------\n\n")

  vars_to_show <- head(names(data_spec$variables), max_vars)

  for (var_name in vars_to_show) {
    var <- data_spec$variables[[var_name]]

    cat(sprintf("%-30s", var_name))
    cat(" | ", sprintf("%-10s", var$type))
    cat(" | ", sprintf("%-18s", var$dist_form))
    cat(" | NA: ", sprintf("%5.1f%%", (var$missing_prop %||% 0) * 100))

    if (var$type == "numeric" && !is.null(var$mean)) {
      cat(" | mean=", sprintf("%8.2f", var$mean))
      cat(", sd=", sprintf("%8.2f", var$sd %||% 0))
    } else if (!is.null(var$n_unique)) {
      cat(" | unique=", sprintf("%6d", var$n_unique))
    }

    if (!is.null(var$stata_label)) {
      cat("\n", sprintf("%30s", ""), " -> ", substr(var$stata_label, 1, 50))
    }

    cat("\n")
  }

  if (data_spec$n_vars > max_vars) {
    cat("\n... and ", data_spec$n_vars - max_vars, " more variables\n")
  }

  cat("\n================================================================================\n")
}

# -----------------------------------------------------------------------------
# WORKFLOW EXAMPLE
# -----------------------------------------------------------------------------

# Example usage:
#
# # 1. Extract specification from data (uses functions from fake_data_creation2.R)
# data_spec <- extract_data_spec("my_data.dta")
#
# # 2. Save to human-readable YAML
# save_spec_yaml(data_spec, "my_data_spec.yaml")
#
# # 3. Also save a CSV summary for quick overview
# save_spec_csv(data_spec, "my_data_spec_summary.csv")
#
# # 4. Print summary to console
# print_spec_summary(data_spec)
#
# # 5. Later: Load YAML and generate synthetic data
# data_spec <- load_spec_yaml("my_data_spec.yaml")
# fake_data <- fake_data_creation(data_spec, n = 1000)

# -----------------------------------------------------------------------------
# PARALLEL EXTRACTION WITH YAML OUTPUT
# -----------------------------------------------------------------------------

#' Extract data specs from multiple files in parallel and save as YAML
#' @param file_paths character vector of paths to data files
#' @param output_dir directory to save YAML files
#' @param n_cores number of cores to use
#' @param save_csv also save CSV summaries
extract_and_save_yaml <- function(file_paths, output_dir, n_cores = NULL, save_csv = TRUE) {

  # Create output directory if needed
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  # Extract specs in parallel
  all_specs <- extract_data_spec_parallel(file_paths, n_cores = n_cores)

  # Save each as YAML (and optionally CSV)
  for (name in names(all_specs)) {
    yaml_file <- file.path(output_dir, paste0(name, "_spec.yaml"))
    save_spec_yaml(all_specs[[name]], yaml_file)

    if (save_csv) {
      csv_file <- file.path(output_dir, paste0(name, "_spec_summary.csv"))
      save_spec_csv(all_specs[[name]], csv_file)
    }

    # Print summary
    print_spec_summary(all_specs[[name]], max_vars = 10)
  }

  message("\nAll specifications saved to: ", output_dir)
  return(all_specs)
}

# =============================================================================
# RUN EXAMPLE
# =============================================================================

if (FALSE) {  # Set to TRUE to run

  setwd("/Users/vero/Library/CloudStorage/GoogleDrive-santy85258@gmail.com/Mi unidad/Trabajos/Observatorio de Politicas Publicas/Observatorio GH/SRI")

  base_path <- "Procesamiento/Bases"

  # Define datasets
  datasets <- c(
    file.path(base_path, "empleo2024.dta")
  )

  # Extract and save as YAML
  all_specs <- extract_and_save_yaml(
    datasets,
    output_dir = "Procesamiento/Bases/specs_yaml",
    n_cores = 4,
    save_csv = TRUE
  )

  # Later: Load from YAML and generate synthetic data
  spec <- load_spec_yaml("Procesamiento/Bases/specs_yaml/empleo2024_spec.yaml")
  fake_data <- fake_data_creation(spec, n = 1000)
}
