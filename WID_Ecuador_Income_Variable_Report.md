# How WID.world Calculates the Income Variable: An Analytical Report with Reference to Ecuador

**Prepared: February 2026**

---

## Table of Contents

1. [Income Variable Definition](#1-income-variable-definition)
2. [Computation Methodology (DINA Framework)](#2-computation-methodology-dina-framework)
3. [Data Sources for Ecuador](#3-data-sources-for-ecuador)
4. [Assumptions, Limitations &amp; Country Specifics](#4-assumptions-limitations--country-specifics)
5. [WID Code Structure &amp; Key Variables for Ecuador](#5-wid-code-structure--key-variables-for-ecuador)
6. [References &amp; Citations](#6-references--citations)

---

## 1. Income Variable Definition

### 1.1. Benchmark Concept: Pre-tax National Income

WID.world's **benchmark distributional income concept** is **pre-tax national income**. It is defined as:

> The sum of all pre-tax personal income flows generated from labor and capital, received **after** the functioning of the pension system and unemployment insurance, but **before** other forms of redistribution such as income tax and social assistance benefits.

In formula terms:

```
Pre-tax National Income = Pre-tax Labor Income + Pre-tax Capital Income
```

This concept **includes**:

- Wages and salaries
- Self-employment income (mixed income)
- Capital income (dividends, interest, rents, retained earnings allocated to individuals)
- Social insurance benefits (pensions, unemployment insurance)

This concept **excludes**:

- Income tax
- Social assistance benefits (other than social insurance)
- Other forms of government redistribution

### 1.2. Relationship to National Income

WID.world prefers **National Income (NI)** over GDP as its macroeconomic anchor:

```
National Income = GDP − Consumption of Fixed Capital (depreciation) + Net Foreign Income
```

National Income is considered more meaningful because:

- It subtracts capital depreciation (which is income to no one)
- It accounts for income transferred to or from foreign capital owners
- A country with large GDP but extensive depreciation and foreign outflows has less income to distribute to residents

### 1.3. Other Income Concepts Available

| Income Concept                       | WID Code               | Description                                                                              |
| ------------------------------------ | ---------------------- | ---------------------------------------------------------------------------------------- |
| **Pre-tax national income**    | `ptinc`              | Benchmark concept. After pension/unemployment insurance, before taxes/social assistance  |
| **Post-tax national income**   | `diinc`              | After all redistribution, including in-kind transfers (health, education)                |
| **Post-tax disposable income** | (variant of `diinc`) | After cash redistribution only (excludes in-kind transfers)                              |
| **Pre-tax factor income**      | `fiinc`              | Before*any* redistribution (including pensions). Sensitive to population age structure |
| **Fiscal income**              | (legacy WTID concept)  | Close to taxable income; definition varies by country. Only available for top 10%        |

### 1.4. Unit of Measurement

- **Equal-split adults** (code suffix `j`): Income is divided equally among all adult members of a household (the preferred unit for international comparisons)
- **Individualistic adults** (code suffix `i`): Income attributed to each individual income earner
- **Tax units** (code suffix `t`): Household taken as the statistical unit

The standard population for distributional series is **adults aged 20 and over** (age code `992`).

### 1.5. Currency and Price Standardization

- All monetary amounts are in **local currency at constant prices** for individual countries (Ecuador: US dollars, since dollarization in 2000)
- Series are expressed at **last year's prices** (the price index base year is updated with each annual database release)
- For cross-country comparisons, WID provides PPP-adjusted and MER-adjusted regional aggregates
- Ecuador's country code in WID is `EC`

---

## 2. Computation Methodology (DINA Framework)

WID.world constructs its inequality series using the **Distributional National Accounts (DINA)** methodology. The DINA Guidelines (3rd edition, updated January 2026) serve as the authoritative methodological document. The central objective is to distribute national income across the entire population—from the poorest to the richest—in a manner fully consistent with macroeconomic aggregates.

### 2.1. Step-by-Step Process

The DINA methodology follows five core steps:

#### Step 1: Establish Macroeconomic Control Totals

- Start from **national accounts** compiled by the relevant statistical authority (for Ecuador: the Central Bank of Ecuador, BCE)
- Derive **Net National Income** from GDP by subtracting consumption of fixed capital and adding net foreign income
- Decompose national income into labor income, capital income (including retained corporate earnings), and government income components
- These aggregates serve as the binding "control totals" to which all distributional estimates must sum

#### Step 2: Use Household Surveys for the Bulk of the Distribution

- For Ecuador, the primary survey source is the **Encuesta Nacional de Empleo, Desempleo y Subempleo (ENEMDU)**, conducted by the Instituto Nacional de Estadística y Censos (INEC)
- Surveys capture labor income, self-employment income, pensions, and some forms of capital income for the middle and lower portions of the distribution
- Surveys are **harmonized** across Latin American countries using standardized income concepts (following the approach of De Rosa, Flores, and Morgan, 2020)

#### Step 3: Use Fiscal/Tax Data for Top Incomes

- Household surveys are well known to **underestimate top incomes** due to non-response and underreporting by the wealthy
- For Ecuador, tabulated **income tax data** from the Servicio de Rentas Internas (SRI) is used to correct the top of the distribution
- Generalized **Pareto interpolation** (via the `gpinter` tool) is applied to tax tabulations to estimate continuous income distributions at the top
- Ecuador's tax data shows a "clear regal shape" in top income distributions, indicating the robustness of the data for capturing top shares

#### Step 4: Reconcile and Scale to National Accounts

- The income distribution obtained from surveys (Steps 2–3) is **rescaled** so that the total matches the national accounts control totals from Step 1
- This "scaling factor" accounts for income components included in national accounts but typically underreported in surveys or absent from tax data (e.g., retained corporate earnings, imputed rents, informal income, undistributed profits)
- For Ecuador, a notable methodological adjustment was implemented starting in 2018: **Operating Surplus and Mixed Income have been reported separately** in the national accounts (previously they were combined). This change affects the scaling factor and accounts for most of the observed differences in the updated DINA series

#### Step 5: Produce Synthetic Micro-files

- The final output is a set of **synthetic micro-files** that describe the income distribution of all adult individuals in a country-year
- These allow computation of shares, averages, and thresholds for any percentile group (e.g., bottom 50%, top 10%, top 1%)
- The micro-files are consistent with national accounts totals and enable cross-country and over-time comparisons

### 2.2. Treatment of Top Incomes

- Top incomes are estimated by replacing the upper tail of the survey distribution with tax-data-based estimates
- The **generalized Pareto interpolation** method (Blanchet, Fournier, and Piketty, 2017) enables smooth estimation across the full distribution
- For countries where detailed tabulated tax data is available (as for Ecuador via the SRI), the method can estimate shares, averages, and thresholds for very fine percentile groups (e.g., top 0.1%, top 0.01%)

### 2.3. Treatment of Bottom Incomes

- Bottom incomes are primarily captured through household surveys
- Imputations are made for **non-cash income** components included in national accounts but not in surveys (e.g., imputed rents, in-kind benefits)
- Social transfers in kind (health, education) are typically allocated using a **lump-sum method** (same average monetary value assigned to each adult), as part of the post-tax national income concept

### 2.4. Social Insurance and Pensions

For the benchmark **pre-tax national income** concept:

- Pensions are treated on a **distribution basis**: retirees are attributed the pension income they actually receive
- Social insurance contributions are subtracted from contributors' income
- This distinguishes pretax national income from pretax factor income, where pensions are treated on a contribution basis (attributed to workers, not retirees)

---

## 3. Data Sources for Ecuador

### 3.1. Primary Data Sources

| Data Source                       | Provider                                           | Role in WID Construction                                                     |
| --------------------------------- | -------------------------------------------------- | ---------------------------------------------------------------------------- |
| **National Accounts**       | Banco Central del Ecuador (BCE)                    | Provides macroeconomic control totals (GDP, NNI, labor/capital shares)       |
| **ENEMDU Household Survey** | INEC (Instituto Nacional de Estadística y Censos) | Main source for income distribution across the bulk of the population        |
| **Income Tax Data**         | SRI (Servicio de Rentas Internas)                  | Corrects top-income underestimation; provides tabulated income distributions |
| **Social Security Data**    | IESS (Instituto Ecuatoriano de Seguridad Social)   | Contributes to social insurance registers used in harmonization              |
| **Population Census Data**  | INEC                                               | Population denominators and demographic structure                            |

### 3.2. Role of Each Source

1. **National Accounts (BCE)**: Establish the total "pie" to be distributed. The BCE compiles GDP and its components (compensation of employees, operating surplus, mixed income, taxes on production). From 2018, Ecuador reports operating surplus and mixed income as separate items, improving the granularity of the data.
2. **ENEMDU Surveys (INEC)**: Annual employment and income surveys providing microdata on labor earnings, self-employment income, rental income, transfers, and other income components. These surveys are harmonized across Latin America following the methodology of De Rosa, Flores, and Morgan (2020).
3. **Tax Data (SRI)**: Tabulated income tax statistics that capture the upper tail of the distribution. The SRI publishes data on the number of taxpayers, declared income, and taxes paid by income brackets. WID researchers use these tabulations to apply generalized Pareto interpolation and correct survey-based estimates at the top.
4. **Social Security (IESS)**: Social security registers provide information on formal employment, earnings, and pension contributions/benefits, complementing survey and tax data.

### 3.3. Ecuador-Specific Documentation

The primary Ecuador-specific technical references within the WID ecosystem are:

- **De Rosa, M., Flores, I., and Morgan, M. (2020)**: "Income Inequality Series for Latin America in WID.world," *World Inequality Lab Technical Note N° 2020/02*. This note details sources and methods for all Latin American countries, including Ecuador-specific adjustments.
- **De Rosa, M., Flores, I., and Morgan, M. (2020)**: "Inequality in Latin America Revisited: Insights from Distributional National Accounts," *World Inequality Lab Issue Brief 2020/11*. Presents main findings, including Ecuador's decreasing inequality since 2000.
- **De Rosa, M., Flores, I., and Morgan, M. (2022)**: "More Unequal or Not as Rich? Revisiting the Latin American Exception," *World Inequality Lab Working Paper*. Explores the discrepancy between micro and macro incomes in the region.
- **2023 DINA Update for Latin America** (World Inequality Lab Technical Note): Notes that Ecuador displays "stable or slightly declining top shares" in recent years.
- **2024 DINA Update for Latin America** (World Inequality Lab Technical Note): Highlights that Ecuador's separate reporting of Operating Surplus and Mixed Income since 2018 affects the scaling factor.

---

## 4. Assumptions, Limitations & Country Specifics

### 4.1. Key Assumptions for Ecuador

1. **All national income is attributable to individuals**: The DINA framework assumes that all income recorded in national accounts ultimately flows to households and individuals, including undistributed corporate profits (which are allocated proportionally to capital income recipients).
2. **Survey income harmonization**: Ecuador's ENEMDU data is harmonized using the same income variable definitions as other Latin American surveys. Certain income components may be imputed or re-categorized to ensure cross-country comparability.
3. **Retained earnings allocation**: Undistributed corporate profits (retained earnings) are allocated to individuals in proportion to their capital income. This is an imputation, since the actual beneficiaries of retained earnings are not directly observed.
4. **Social transfers in kind**: For post-tax national income, public spending on health and education is allocated via a lump-sum method (equal value per adult). This is a strong assumption, as actual consumption of these services varies by income level.
5. **Equal-split assumption**: In the preferred "equal-split adults" series, income is split equally between adult partners in a couple. This may not reflect actual intra-household income allocation.

### 4.2. Limitations Specific to Ecuador

| Limitation                                     | Description                                                                                                                                                                                                                                                                                               |
| ---------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Informal sector coverage**             | Ecuador has a large informal economy. While national accounts aim to capture informal activity, surveys and tax data inevitably undercount informal incomes. WID methodology does not explicitly model informal sector income but indirectly captures it through the scaling to national accounts totals. |
| **Tax data coverage**                    | Only taxpayers filing returns are included in tax tabulations. In a context of low tax compliance and large informality, the tax data may not fully represent the top of the distribution.                                                                                                                |
| **Time span**                            | WID income distribution series for Ecuador are available from approximately**2000 to the present**. Historical series before 2000 are not yet available (future updates aim to extend coverage to 1990).                                                                                            |
| **Data quality heterogeneity**           | WID acknowledges that data quality across Latin American countries is "highly heterogeneous" and notes the need for further collaboration with local data producers.                                                                                                                                      |
| **Surveys capture ~50% of macro income** | For Latin America generally, survey data captures approximately half of the macroeconomic income. The gap is filled by the scaling procedure, which introduces uncertainty.                                                                                                                               |
| **Operating Surplus/Mixed Income split** | Before 2018, Ecuador's national accounts reported Operating Surplus and Mixed Income as a combined item. The 2018 separation improved data granularity but introduced a structural break in the scaling factor.                                                                                           |
| **Capital income underreporting**        | Capital income is poorly captured in both surveys and tax records in Ecuador. The imputation of retained earnings and other capital income components relies heavily on national accounts ratios.                                                                                                         |

### 4.3. Inequality Transparency Index

WID.world publishes an **Inequality Transparency Index** for each country, evaluating:

- Availability and quality of income and wealth surveys
- Availability and quality of income and wealth tax data
- Frequency and accessibility of data
- Whether micro-data or only tabulations are accessible

This index helps users assess the reliability of WID series for Ecuador relative to other countries.

### 4.4. Key Findings for Ecuador

- **Declining inequality since 2000**: The top 10% income share in Ecuador was approximately **38% of national income in 2019** (De Rosa, Flores, and Morgan, 2020)
- **COVID-19 impact**: Ecuador, along with Peru and Colombia, experienced a **sharp increase in income concentration in 2020**, likely driven by the asymmetric effects of the pandemic
- **Stable or slightly declining top shares** in the most recent years (2023 DINA Update)

---

## 5. WID Code Structure & Key Variables for Ecuador

### 5.1. Code Structure

Every WID variable code consists of four components:

```
[1 letter: Series Type] + [5 letters: Concept] + [3 digits: Age Group] + [1 letter: Population Unit]
```

**Examples for Ecuador (country code: EC):**

| Full Code      | Meaning                                                                                  |
| -------------- | ---------------------------------------------------------------------------------------- |
| `sptinc992j` | **Share** of **pre-tax national income**, adults ≥20, **equal-split** |
| `aptinc992j` | **Average** pre-tax national income, adults ≥20, equal-split                      |
| `tptinc992j` | **Threshold** for pre-tax national income, adults ≥20, equal-split                |
| `sdiinc992j` | Share of post-tax national income, adults ≥20, equal-split                              |
| `sfiinc992j` | Share of factor income, adults ≥20, equal-split                                         |
| `anninc999i` | Average national income per capita (all ages)                                            |
| `anninc992i` | Average national income per adult                                                        |

### 5.2. Series Types

| Code  | Type      | Unit                             |
| ----- | --------- | -------------------------------- |
| `s` | Share     | Fraction of 1 (e.g., 0.20 = 20%) |
| `a` | Average   | Local currency (constant prices) |
| `t` | Threshold | Local currency (constant prices) |

### 5.3. Key Concept Codes

| Code      | Concept                                                 |
| --------- | ------------------------------------------------------- |
| `ptinc` | Pre-tax national income                                 |
| `pllin` | Pre-tax labor income (ranked by total pre-tax income)   |
| `pkkin` | Pre-tax capital income (ranked by total pre-tax income) |
| `diinc` | Post-tax national income                                |
| `fiinc` | Factor income                                           |
| `nninc` | Net national income (aggregate)                         |
| `gdpro` | GDP                                                     |

### 5.4. Percentile Codes

WID percentile codes follow the format `pXpY` where X is the lower bound and Y is the upper bound:

| Code          | Group                                 |
| ------------- | ------------------------------------- |
| `p0p50`     | Bottom 50%                            |
| `p50p90`    | Middle 40%                            |
| `p90p100`   | Top 10%                               |
| `p99p100`   | Top 1%                                |
| `p99.9p100` | Top 0.1%                              |
| `p0p100`    | Full population (used for aggregates) |

### 5.5. Accessing Ecuador Data

Data for Ecuador can be accessed via:

1. **Web interface**: [https://wid.world/country/ecuador/](https://wid.world/country/ecuador/)
2. **Direct download**: [https://wid.world/data/](https://wid.world/data/) (filter by country = Ecuador)
3. **Stata package**: `ssc install wid` or via [GitHub](https://github.com/world-inequality-database/wid-stata-tool)
4. **R package**: via [GitHub](https://github.com/world-inequality-database/wid-r-tool)

---

## 6. References & Citations

### Core Methodology Documents

1. **DINA Guidelines (2025, 3rd edition)**: "Distributional National Accounts (DINA) Guidelines: Methods and Concepts Used in the World Inequality Database," World Inequality Lab. Updated January 14, 2026.

   - URL: [https://wid.world/document/distributional-national-accounts-dina-guidelines-2025-methods-and-concepts-used-in-the-world-inequality-database/](https://wid.world/document/distributional-national-accounts-dina-guidelines-2025-methods-and-concepts-used-in-the-world-inequality-database/)
2. **WID Codes Dictionary**: World Inequality Database.

   - URL: [https://wid.world/codes-dictionary/](https://wid.world/codes-dictionary/)
3. **Blanchet, T., Fournier, J., and Piketty, T. (2017)**: "Generalized Pareto Curves: Theory and Applications," *World Inequality Lab Working Paper*.

   - URL: [https://wid.world/document/blanchet-t-fournier-j-piketty-t-generalized-pareto-curves-theory-applications-2017/](https://wid.world/document/blanchet-t-fournier-j-piketty-t-generalized-pareto-curves-theory-applications-2017/)

### Ecuador / Latin America-Specific References

4. **De Rosa, M., Flores, I., and Morgan, M. (2020)**: "Income Inequality Series for Latin America in WID.world," *World Inequality Lab Technical Note N° 2020/02*.

   - Details sources and methods for all Latin American countries, including Ecuador.
5. **De Rosa, M., Flores, I., and Morgan, M. (2020)**: "Inequality in Latin America Revisited: Insights from Distributional National Accounts," *World Inequality Lab Issue Brief 2020/11*.

   - Presents key findings on Ecuador's declining inequality since 2000.
6. **De Rosa, M., Flores, I., and Morgan, M. (2022)**: "More Unequal or Not as Rich? Revisiting the Latin American Exception," *World Inequality Lab Working Paper*.

   - Explores the micro-macro income gap for Latin American countries, including Ecuador.
7. **2023 DINA Update for Latin America**: World Inequality Lab Technical Note.

   - Notes Ecuador's stable or slightly declining top shares.
8. **2024 DINA Update for Latin America**: World Inequality Lab Technical Note.

   - Documents Ecuador's separate reporting of Operating Surplus and Mixed Income since 2018.

### Additional Resources

9. **World Inequality Report 2026**: [https://wir2026.wid.world/](https://wir2026.wid.world/)
10. **WID Methodology Page**: [https://wid.world/methodology/](https://wid.world/methodology/)
11. **Gpinter Tool** (Generalized Pareto Interpolation): [https://github.com/world-inequality-database/gpinter](https://github.com/world-inequality-database/gpinter)
12. **WID.world Ecuador Country Page**: [https://wid.world/country/ecuador/](https://wid.world/country/ecuador/)
13. **Distribuciones** (collaborative visualization with WID for Latin America): Interactive data for Ecuador and other regional countries covering the last decade.

---

> **Note on Ecuador-specific methodology**: WID.world does not publish a standalone "country note" exclusively for Ecuador. The Ecuador-specific methodology is documented within the broader Latin American technical notes (references 4–8 above). The general DINA methodology (reference 1) applies to Ecuador with the country-specific adjustments described in this report. Users requiring additional methodological detail should consult the De Rosa, Flores, and Morgan (2020) technical note and the annual DINA Updates for Latin America.
