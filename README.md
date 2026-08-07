# World Life Expectancy Analysis

## Executive summary

This MySQL project evaluates life expectancy, mortality, immunization,
education, and economic indicators across 193 countries from 2007 through 2022
as supplied in the project dataset. The analysis is framed for a global health
program director who needs a transparent way to identify disparities, monitor
country outcomes, and prioritize candidates for deeper investigation.

The project demonstrates an auditable SQL workflow: raw-data preservation,
quality assessment, staging, duplicate removal, missing-value treatment, type
standardization, validation, window functions, longitudinal metrics, Pearson
correlation, peer benchmarking, and a transparent multi-metric priority score.

![World Life Expectancy Analysis executive summary](images/WLE_analysis_summary.png)

## Business problem

A global health organization has limited analytical and program resources. It
needs to determine which countries show the broadest combination of adverse
health and socioeconomic indicators, which countries improved or declined over
time, and which outcomes differ materially from economic peers.

### Primary question

> Which countries demonstrate the greatest health-outcome needs or improvement
> opportunities based on life expectancy, mortality, immunization, education,
> and economic indicators?

See the complete [Phase 2 Business Understanding](docs/02_business_understanding.md) and [Phase 3 Data Understanding](docs/03_data_understanding.md).

## Key findings

- Average country life expectancy increased from **66.75 years in 2007** to
  **71.62 years in 2022**, a gain of **4.87 years (7.29%)**.
- Zimbabwe (+21.0 years), Eritrea (+19.4), Zambia (+18.0), Botswana (+17.9),
  and Rwanda (+17.8) recorded the largest first-to-last gains.
- Syrian Arab Republic (-8.1 years), Saint Vincent and the Grenadines (-5.8),
  Libya (-5.3), Paraguay (-5.0), and Yemen (-2.3) recorded the largest declines.
- The full-period developed/developing life-expectancy gap was **12.09 years**;
  the 2022 gap was **11.02 years**.
- Schooling had the strongest positive linear relationship with life expectancy
  (`r = 0.784`), while adult mortality had the strongest negative relationship
  (`r = -0.696`). These relationships are associative, not causal.

## Recommendations

1. Use the six-indicator priority score to create a second-stage review list,
   not to make automatic funding decisions.
2. Investigate high-improvement countries for potentially transferable health,
   education, or implementation practices.
3. Review declining countries using local political, health-system, and data-
   quality context before recommending interventions.
4. Compare countries with GDP peers to identify outcomes that economic level
   alone does not explain.
5. Add population, current-year health data, intervention cost, local capacity,
   and equity measures before allocating resources.

## Data-quality process

The raw CSV contained 2,941 rows. The SQL workflow:

- Preserved the source in `WLE_raw`.
- Removed three exact duplicate country-year records.
- Restored eight blank development-status values from consistent country data.
- Estimated two internal life-expectancy gaps using adjacent-year midpoints.
- Converted selected implausible zero placeholders to `NULL`.
- Created `WLE_clean` with standardized names, numeric types, constraints, and
  a unique country-year key.
- Reconciled 2,941 raw rows to 2,938 clean rows.

## Repository files

| File | Purpose |
|---|---|
| [`sql/WLE_01_data_audit.sql`](sql/WLE_01_data_audit.sql) | Read-only source audit and baseline results |
| [`sql/WLE_02_data_cleaning.sql`](sql/WLE_02_data_cleaning.sql) | Reproducible staging and cleaning workflow |
| [`sql/WLE_03_data_validation.sql`](sql/WLE_03_data_validation.sql) | Independent quality tests and final gate |
| [`sql/WLE_04_business_analysis.sql`](sql/WLE_04_business_analysis.sql) | Business questions, KPIs, and recommendations |
| [`docs/WLE_data_dictionary.md`](docs/WLE_data_dictionary.md) | Standardized fields and missing-value rules |
| [`docs/02_business_understanding.md`](docs/02_business_understanding.md) | Business decision, stakeholders, success measures, and claim boundaries |
| [`docs/03_data_understanding.md`](docs/03_data_understanding.md) | Dataset grain, field roles, quality treatment, and analytical readiness |
| [`data/README.md`](data/README.md) | Source-file requirements and import notes |

## Tools and SQL skills

- MySQL 8.0 and MySQL Workbench
- Common table expressions
- Window functions
- Conditional aggregation
- Multi-table updates and self-joins
- Data-type standardization and constraints
- Pearson correlation in SQL
- Percentile ranking and priority scoring
- GDP peer-group benchmarking
- Data-quality reconciliation

## How to reproduce

1. Create a MySQL database named `WLE`.
2. Import the supplied CSV as `WLE_raw` with MySQL Workbench's Table Data Import
   Wizard.
3. Run the files in [`sql/`](sql/) in numerical order.
4. Confirm that `WLE_03_data_validation.sql` returns a passing quality gate.
5. Run `WLE_04_business_analysis.sql` to reproduce the reported findings.

## Limitations

- Years are used exactly as supplied in the project CSV.
- Ten countries contain only a 2020 observation and are excluded from trend
  rankings.
- Two life-expectancy observations are estimates rather than measured values.
- Country averages are unweighted because population is unavailable.
- Zero-value meaning is not fully documented for every source field.
- Correlation does not establish causation.
- The priority score uses equal weights and requires further contextual review.
- The dataset should not be treated as current operational health intelligence.

## Author

Kiran Williams  
[Data Analytics Portfolio](https://github.com/keyswill/data-analytics-portfolio) ·
[LinkedIn](https://www.linkedin.com/in/kiranwilliams/)
