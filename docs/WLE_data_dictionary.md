# World Life Expectancy Data Dictionary

This dictionary describes the standardized fields in `WLE_clean`. Definitions
are based on the labels supplied with the educational dataset; units should be
verified against an authoritative source before policy or funding use.

| Field | Type | Analytical use |
|---|---|---|
| `row_id` | BIGINT | Source-row identifier and primary key |
| `country` | VARCHAR(100) | Country-level comparison dimension |
| `year` | SMALLINT | Annual trend dimension, 2007–2022 as supplied |
| `development_status` | VARCHAR(15) | Developed/developing comparison group |
| `life_expectancy` | DECIMAL(4,1) | Primary health-outcome metric |
| `life_expectancy_imputed` | TINYINT | Flags the two midpoint estimates |
| `adult_mortality` | SMALLINT | Adult mortality indicator |
| `infant_deaths` | INT | Reported infant-death measure |
| `percentage_expenditure` | DECIMAL(12,2) | Supplied expenditure measure |
| `measles_cases` | INT | Reported measles cases |
| `bmi` | DECIMAL(4,1) | Supplied BMI indicator |
| `under_five_deaths` | INT | Reported under-five-death measure |
| `polio_coverage` | DECIMAL(5,1) | Polio immunization indicator |
| `diphtheria_coverage` | DECIMAL(5,1) | Diphtheria immunization indicator |
| `hiv_aids` | DECIMAL(5,1) | Supplied HIV/AIDS mortality indicator |
| `gdp` | DECIMAL(14,2) | Supplied economic indicator |
| `thinness_1_19_years` | DECIMAL(4,1) | Thinness indicator for ages 1–19 |
| `thinness_5_9_years` | DECIMAL(4,1) | Thinness indicator for ages 5–9 |
| `schooling_years` | DECIMAL(4,1) | Supplied schooling indicator |

## Missing-value conventions

Numeric zero was converted to `NULL` for life expectancy, adult mortality, GDP,
BMI, Polio coverage, Diphtheria coverage, both thinness measures, and schooling.
These zeros were treated as unavailable or implausible placeholders.

Zero was retained for infant deaths, under-five deaths, measles cases, HIV/AIDS,
and percentage expenditure because zero may be meaningful or the supplied data
did not support a defensible automatic replacement.

## Analytical limitations

- The dates are analyzed exactly as supplied in the CSV.
- Ten countries contain only a 2020 observation and cannot support trend analysis.
- Two life-expectancy values were estimated using adjacent-year midpoints.
- Country averages are not population-weighted.
- Correlations measure association, not causation.
- The priority score is a screening device, not an allocation formula.
