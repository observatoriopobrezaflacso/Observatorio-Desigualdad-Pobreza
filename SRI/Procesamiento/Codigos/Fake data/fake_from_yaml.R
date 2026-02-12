# =============================================================================
# GENERATE SYNTHETIC DATA FROM YAML SPECIFICATION
# =============================================================================
# This script reads a YAML specification and generates synthetic data
# that closely matches the original data's distributions.
# =============================================================================

# Null-coalescing operator
`%||%` <- function(x, y) if (is.null(x)) y else x

# Get the directory where this script is located
get_script_dir <- function() {
  # Try multiple methods
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("^--file=", args, value = TRUE)
  if (length(file_arg) > 0) {
    return(dirname(normalizePath(sub("^--file=", "", file_arg))))
  }
  # Fallback to current directory
  return(getwd())
}

script_dir <- get_script_dir()
source(file.path(script_dir, "fake_data_creation2.R"))
source(file.path(script_dir, "data_spec_yaml.R"))

# =============================================================================
# CONFIGURATION
# =============================================================================

# Path to YAML specification file
yaml_file <- file.path('/Users/vero/Library/CloudStorage/GoogleDrive-santy85258@gmail.com/Mi unidad/Trabajos/Observatorio de Políticas Públicas/Observatorio GH/SRI/Procesamiento/Bases/empleo2024_spec.yaml')

# Number of rows to generate
n_rows <- 10000


# Random seed for reproducibility
seed <- 42

# Output file
output_file <- file.path(script_dir, "../../Bases/empleo2024_fake_from_yaml.csv")

# =============================================================================
# GENERATE SYNTHETIC DATA
# =============================================================================

cat("================================================================================\n")
cat("              SYNTHETIC DATA GENERATION FROM YAML\n")
cat("================================================================================\n\n")

# Check if YAML file exists
if (!file.exists(yaml_file)) {
  stop("YAML file not found: ", yaml_file)
}

cat("Input:  ", yaml_file, "\n")
cat("Output: ", output_file, "\n")
cat("Rows:   ", n_rows, "\n")
cat("Seed:   ", seed, "\n\n")

# Load specification from YAML
cat("Loading YAML specification...\n")
data_spec <- load_spec_yaml(yaml_file)

cat("  Variables: ", data_spec$n_vars, "\n")
cat("  Original rows: ", data_spec$n_original, "\n\n")

# Generate synthetic data
cat("Generating synthetic data...\n")
fake_data <- fake_data_creation(data_spec, n = n_rows, seed = seed, verbose = TRUE)

# Save to CSV
cat("\nSaving to CSV...\n")
write.csv(fake_data, output_file, row.names = FALSE)
cat("Saved to: ", output_file, "\n")

# =============================================================================
# QUICK VALIDATION
# =============================================================================

cat("\n================================================================================\n")
cat("                         QUICK VALIDATION\n")
cat("================================================================================\n\n")

# Show preview
cat("Preview (first 5 rows, first 8 columns):\n\n")
print(fake_data[1:5, 1:8])

# Check a few distributions
cat("\n\nSample distributions:\n")

check_vars <- c("area", "p02", "p03", "p06")
for (v in check_vars) {
  if (v %in% names(fake_data)) {
    cat("\n", v, ":\n")
    vals <- as.numeric(fake_data[[v]])
    vals_clean <- vals[!is.na(vals)]

    cat("  N valid: ", length(vals_clean), "\n")
    cat("  NA %:    ", round(mean(is.na(vals)) * 100, 1), "%\n")

    if (length(unique(vals_clean)) <= 10) {
      cat("  Distribution:\n")
      print(round(prop.table(table(vals_clean)) * 100, 1))
    } else {
      cat("  Mean: ", round(mean(vals_clean), 2), "\n")
      cat("  SD:   ", round(sd(vals_clean), 2), "\n")
    }
  }
}

cat("\n================================================================================\n")
cat("Done!\n")
cat("================================================================================\n")
