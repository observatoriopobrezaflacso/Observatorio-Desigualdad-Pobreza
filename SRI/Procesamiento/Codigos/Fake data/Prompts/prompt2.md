> Modify the previously generated R code so that the synthetic dataset can be generated **without reading or accessing the original dataset**.

> Specifically:

1. > The code must **not require the original data file or data frame as input** at runtime.
   >
2. > Introduce a **data specification object** (e.g. a list or tibble called **data_spec**) that stores, for each variable:
   >

   * > Variable name
     >
   * > Data type / class (numeric, integer, character, labelled, date, etc.)
     >
   * > Distributional form (normal-like, skewed, heavy-tailed, categorical, count, ID-like string, etc.)
     >
   * > Key summary statistics (mean, sd, min, max, quantiles where relevant)
     >
   * > Missingness proportion
     >
   * > Categorical levels and their probabilities (if applicable)
     >
   * > Stata / haven metadata (labels, value labels, formats)
     >
3. > Refactor fake_data_creation()** so that:**
   >

   * > It takes **data_spec** and **n** as inputs
     >
   * > It generates synthetic variables **solely from the specification**, not from real data
     >
   * > The output dataset preserves variable names, classes, attributes, and overall structure
     >
4. > Keep the code **modular and reusable**, so that:
   >

   * > One script can be used to *extract* a **data_spec** from a real dataset (optional, separate step)
     >
   * > Another script can generate synthetic data **only from the saved specification**
     >
5. > Include a minimal example of:
   >

   * > A manually defined **data_spec** for a few variables
     >
   * > Calling fake_data_creation(data_spec, n = 1000)
     >
