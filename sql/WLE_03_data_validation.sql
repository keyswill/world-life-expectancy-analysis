/*==============================================================================
PROJECT: World Life Expectancy Analysis
SCRIPT: WLE_03_data_validation.sql
AUTHOR: Kiran Williams
DATABASE: MySQL 8.0+

PURPOSE
-------------------------------------------------------------------------------
Validate that WLE_clean is complete, internally consistent, correctly typed,
and reconciled to WLE_raw before the table is used for business decisions.

Validation is deliberately separated from cleaning so the quality checks serve
as independent evidence rather than assumptions embedded in transformations.
==============================================================================*/

USE WLE;


/*------------------------------------------------------------------------------
TEST 1: RAW TABLE PRESERVATION AND ROW RECONCILIATION

The source must remain at 2,941 rows. The clean table should contain 2,938 rows
after exactly three excess duplicate records are removed.
------------------------------------------------------------------------------*/

SELECT
    (SELECT COUNT(*) FROM WLE_raw) AS raw_rows,
    (SELECT COUNT(*) FROM WLE_clean) AS clean_rows,
    (SELECT COUNT(*) FROM WLE_raw) -
    (SELECT COUNT(*) FROM WLE_clean) AS explained_row_difference,
    CASE
        WHEN (SELECT COUNT(*) FROM WLE_raw) = 2941
         AND (SELECT COUNT(*) FROM WLE_clean) = 2938
        THEN 'PASS'
        ELSE 'FAIL'
    END AS row_reconciliation_test;


/*------------------------------------------------------------------------------
TEST 2: COUNTRY-YEAR UNIQUENESS

An empty result confirms that the analytical grain is enforced.
------------------------------------------------------------------------------*/

SELECT
    country,
    year,
    COUNT(*) AS record_count
FROM WLE_clean
GROUP BY country, year
HAVING COUNT(*) > 1;


/*------------------------------------------------------------------------------
TEST 3: REQUIRED FIELD COMPLETENESS

Country, year, development status, and Row_ID are required dimensions. Life
expectancy may be NULL only for the ten countries with a single 2020 record and
zero placeholder in the raw dataset.
------------------------------------------------------------------------------*/

SELECT
    SUM(CASE WHEN row_id IS NULL THEN 1 ELSE 0 END) AS missing_row_id,
    SUM(CASE WHEN country IS NULL OR TRIM(country) = '' THEN 1 ELSE 0 END)
        AS missing_country,
    SUM(CASE WHEN year IS NULL THEN 1 ELSE 0 END) AS missing_year,
    SUM(CASE WHEN development_status IS NULL THEN 1 ELSE 0 END)
        AS missing_status,
    SUM(CASE WHEN life_expectancy IS NULL THEN 1 ELSE 0 END)
        AS unavailable_life_expectancy
FROM WLE_clean;

/* EXPECTED: 0, 0, 0, 0, and 10 respectively. */


/*------------------------------------------------------------------------------
TEST 4: STATUS RESTORATION AUDIT

This comparison identifies raw blank statuses and displays the corresponding
standardized status in WLE_clean.
------------------------------------------------------------------------------*/

SELECT
    raw.Row_ID AS row_id,
    raw.Country AS country,
    raw.Year AS year,
    raw.Status AS raw_status,
    clean.development_status AS cleaned_status
FROM WLE_raw AS raw
INNER JOIN WLE_clean AS clean
    ON raw.Row_ID = clean.row_id
WHERE raw.Status IS NULL
   OR TRIM(raw.Status) = ''
ORDER BY raw.Country, raw.Year;

/* EXPECTED: 8 rows, each resolved to a nonblank country-consistent status. */


/*------------------------------------------------------------------------------
TEST 5: LIFE-EXPECTANCY IMPUTATION AUDIT

Only Afghanistan 2018 and Albania 2018 should carry an imputation flag. This
query displays the final estimate alongside the previous and following years.
------------------------------------------------------------------------------*/

SELECT
    current_year.country,
    current_year.year,
    previous_year.life_expectancy AS previous_value,
    current_year.life_expectancy AS imputed_value,
    following_year.life_expectancy AS following_value,
    current_year.life_expectancy_imputed
FROM WLE_clean AS current_year
INNER JOIN WLE_clean AS previous_year
    ON current_year.country = previous_year.country
    AND previous_year.year = current_year.year - 1
INNER JOIN WLE_clean AS following_year
    ON current_year.country = following_year.country
    AND following_year.year = current_year.year + 1
WHERE current_year.life_expectancy_imputed = 1
ORDER BY current_year.country;

/* EXPECTED: Afghanistan 59.2 and Albania 76.6. */


/*------------------------------------------------------------------------------
TEST 6: ZERO-PLACEHOLDER CONVERSION

These fields should contain no numeric zeros after conversion to NULL. This
protects averages and association metrics from invalid placeholder values.
------------------------------------------------------------------------------*/

SELECT
    SUM(CASE WHEN life_expectancy = 0 THEN 1 ELSE 0 END) AS zero_life_expectancy,
    SUM(CASE WHEN adult_mortality = 0 THEN 1 ELSE 0 END) AS zero_adult_mortality,
    SUM(CASE WHEN gdp = 0 THEN 1 ELSE 0 END) AS zero_gdp,
    SUM(CASE WHEN bmi = 0 THEN 1 ELSE 0 END) AS zero_bmi,
    SUM(CASE WHEN polio_coverage = 0 THEN 1 ELSE 0 END) AS zero_polio,
    SUM(CASE WHEN diphtheria_coverage = 0 THEN 1 ELSE 0 END) AS zero_diphtheria,
    SUM(CASE WHEN schooling_years = 0 THEN 1 ELSE 0 END) AS zero_schooling
FROM WLE_clean;

/* EXPECTED: zero across every field. */


/*------------------------------------------------------------------------------
TEST 7: DOMAIN AND RANGE CHECKS

Flags identify values that violate logical or dataset-specific boundaries. This
test does not claim every in-range value is accurate; it catches clear defects.
------------------------------------------------------------------------------*/

SELECT
    SUM(CASE WHEN year NOT BETWEEN 2007 AND 2022 THEN 1 ELSE 0 END)
        AS invalid_year,
    SUM(CASE WHEN development_status NOT IN ('Developed', 'Developing')
             THEN 1 ELSE 0 END) AS invalid_status,
    SUM(CASE WHEN life_expectancy IS NOT NULL
                  AND life_expectancy NOT BETWEEN 30 AND 100
             THEN 1 ELSE 0 END) AS invalid_life_expectancy,
    SUM(CASE WHEN polio_coverage IS NOT NULL
                  AND polio_coverage NOT BETWEEN 1 AND 100
             THEN 1 ELSE 0 END) AS invalid_polio,
    SUM(CASE WHEN diphtheria_coverage IS NOT NULL
                  AND diphtheria_coverage NOT BETWEEN 1 AND 100
             THEN 1 ELSE 0 END) AS invalid_diphtheria,
    SUM(CASE WHEN schooling_years IS NOT NULL
                  AND schooling_years NOT BETWEEN 0.1 AND 30
             THEN 1 ELSE 0 END) AS invalid_schooling
FROM WLE_clean;

/* EXPECTED: zero across every field. */


/*------------------------------------------------------------------------------
TEST 8: COUNTRY COVERAGE AND TREND ELIGIBILITY

Countries with all 16 years are eligible for first-to-last longitudinal
comparisons. Ten countries contain only a 2020 observation and remain eligible
only for analyses where that observation is relevant and its metric is present.
------------------------------------------------------------------------------*/

SELECT
    years_available,
    COUNT(*) AS countries
FROM
(
    SELECT
        country,
        COUNT(DISTINCT year) AS years_available
    FROM WLE_clean
    GROUP BY country
) AS country_coverage
GROUP BY years_available
ORDER BY years_available;

/* EXPECTED: 10 countries with 1 year and 183 countries with 16 years. */


/*------------------------------------------------------------------------------
TEST 9: YEAR-LEVEL CONTROL TOTALS

Following duplicate removal, most years should contain 183 records. The year
2020 contains ten additional single-year countries and therefore 193 records.
------------------------------------------------------------------------------*/

SELECT
    year,
    COUNT(*) AS records,
    COUNT(DISTINCT country) AS countries
FROM WLE_clean
GROUP BY year
ORDER BY year;


/*------------------------------------------------------------------------------
TEST 10: FINAL QUALITY GATE

This single result summarizes the minimum conditions required before business
analysis begins. PASS does not certify source accuracy; it confirms that the
documented structural and transformation rules were applied successfully.
------------------------------------------------------------------------------*/

SELECT
    CASE
        WHEN (SELECT COUNT(*) FROM WLE_raw) = 2941
         AND (SELECT COUNT(*) FROM WLE_clean) = 2938
         AND (SELECT COUNT(*) FROM WLE_clean) =
             (SELECT COUNT(DISTINCT country, year) FROM WLE_clean)
         AND (SELECT COUNT(*) FROM WLE_clean
              WHERE development_status IS NULL) = 0
         AND (SELECT COUNT(*) FROM WLE_clean
              WHERE life_expectancy_imputed = 1) = 2
        THEN 'PASS: WLE_clean is approved for business analysis'
        ELSE 'FAIL: investigate validation results before analysis'
    END AS final_quality_gate;

/*
EXPECTED RESULT
---------------
PASS: WLE_clean is approved for business analysis
*/
