# =============================================================================
# HUMAN-READABLE DATA SPECIFICATION (YAML FORMAT)
# =============================================================================
# This script provides functions to convert data_spec objects to/from YAML
# format, which is much easier to read and edit by humans.
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

# # Source the main synthetic data generation script
# # Try to find it relative to this script, or in current directory
# tryCatch({
#   this_script <- sys.frame(1)$ofile
#   if (!is.null(this_script)) {
#     source(file.path(dirname(this_script), "fake_data_creation2.R"))
#   } else {
#     source("fake_data_creation2.R")
#   }
# }, error = function(e) {
#   # Fallback: try current directory
#   source("fake_data_creation2.R")
# })

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


data_spec <- extract_data_spec("/Users/vero/Library/CloudStorage/GoogleDrive-santy85258@gmail.com/Mi unidad/Trabajos/Observatorio de Políticas Públicas/Observatorio GH/SRI/Procesamiento/Bases/empleo2024.dta")
yaml_spec <- save_spec_yaml(data_spec, "my_data_spec2.yaml")
data_spec2 <- load_spec_yaml("my_data_spec2.yaml")

