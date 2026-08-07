# Data Understanding

**Status: Complete**

This document explains the dataset grain, field roles, quality findings, and analytical limits established before business analysis.

## Dataset Grain

> One clean row represents one country-year observation in the project dataset.

The raw file contained 2,941 rows. Three exact duplicate country-year records were removed, producing 2,938 validated observations across 193 countries. Most countries contain annual observations from 2007 through 2022 as supplied; ten countries contain only a 2020 observation.

## Keys and Lineage

| Field | Role | Interpretation |
|---|---|---|
| `row_id` | Source-row identifier | Supports auditability back to the imported data |
| `country` + `year` | Natural analytical key | Uniquely identifies a clean country-year observation |
| `life_expectancy_imputed` | Quality flag | Identifies the two midpoint estimates |

The source is preserved in `WLE_raw`; cleaning occurs through staging before `WLE_clean` is created.

## Field Roles

### Outcome and comparison fields

- `life_expectancy`
- `country`
- `year`
- `development_status`

### Health and socioeconomic indicators

- Adult mortality, infant deaths, and under-five deaths
- Measles cases, polio coverage, and diphtheria coverage
- HIV/AIDS and BMI indicators
- GDP and percentage expenditure
- Schooling and thinness indicators

### Technical quality field

- `life_expectancy_imputed`

## Connection to Business Questions

| Business question | Required fields | Measure | Interpretation limit |
|---|---|---|---|
| Which countries improved or declined? | Country, year, life expectancy | First-to-last change | Ten single-year countries cannot be ranked |
| How large is the status gap? | Development status, life expectancy | Group average difference | Status is a broad category |
| Which indicators move with life expectancy? | Life expectancy and numeric indicators | Pearson correlation | Correlation is not causation |
| How does a country compare with economic peers? | GDP and life expectancy | Peer benchmark difference | GDP is incomplete economic context |
| Which countries need review? | Six selected indicators | Equal-weight percentile score | Score depends on chosen fields and weights |

## Data-Quality Treatment

- Removed three exact duplicate country-year records.
- Restored eight blank development-status values from internally consistent country records.
- Estimated two internal life-expectancy gaps using adjacent-year midpoints and flagged them.
- Converted selected implausible zero placeholders to `NULL`.
- Standardized field names and numeric types.
- Added constraints and a unique country-year key.
- Reconciled 2,941 raw rows to 2,938 clean rows.

## Missing-Value Logic

Zero was converted to `NULL` for life expectancy, adult mortality, GDP, BMI, polio coverage, diphtheria coverage, both thinness measures, and schooling. Zero was retained for infant deaths, under-five deaths, measles cases, HIV/AIDS, and percentage expenditure because it may be meaningful or the data did not justify automatic replacement.

## Analytical Readiness

The clean table is suitable for descriptive country comparison, longitudinal change, correlations, peer benchmarking, and transparent screening. It is not sufficient for current funding allocation, causal policy evaluation, or population-weighted global estimates.

## Related Documentation

- [Data dictionary](WLE_data_dictionary.md)
- [SQL audit](../sql/WLE_01_data_audit.sql)
- [SQL validation](../sql/WLE_03_data_validation.sql)
- [Business Understanding](business_understanding.md)
