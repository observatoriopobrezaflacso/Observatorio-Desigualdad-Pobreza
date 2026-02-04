> Using R code inside a function called **fake_data_creation**, create a synthetic (fake) version of the dataset

> /Users/vero/Library/CloudStorage/GoogleDrive-santy85258@gmail.com/Mi unidad/Trabajos/Observatorio de Políticas Públicas/Observatorio GH/SRI/Procesamiento/Bases/empleo2024.dta

> as accurately as possible.

> The procedure should:

1. > Systematically explore each variable in the original dataset (class/type, range, missingness, distribution, skewness, presence of outliers, and categorical levels if applicable).
   >
2. > Generate a corresponding synthetic variable that matches:
   >

   * > Data type (numeric, integer, factor, logical, date, etc.)
     >
   * > Marginal distribution (e.g., normal-like, skewed, heavy-tailed, discrete counts, categorical proportions)
     >
   * > Key summary statistics (mean, variance, quantiles) where relevant
     >
   * > Missing value patterns
     >
3. > Use appropriate data-generating processes:
   >

   * > Parametric distributions when suitable (normal, log-normal, Poisson, binomial, etc.)
     >
   * > Non-parametric or empirical approaches when distributions are irregular
     >
   * > Added noise or mixture models for heavy tails or multimodality
     >
4. > Preserve variable names and overall dataset structure.
   >

> The goal is that any analysis code written using the synthetic data can be run on the real dataset with minimal or no modifications.

> Write the code in a modular and general way so that the same function can be reused to generate synthetic versions of other datasets with similar characteristics (not hard-coded to this specific file).
>
