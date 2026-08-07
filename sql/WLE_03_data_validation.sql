/*==============================================================================
WORLD LIFE EXPECTANCY ANALYSIS
SCRIPT 3: DATA VALIDATION

Independently confirm that WLE_clean follows the documented cleaning rules and
is ready for analysis. A passing result validates the workflow, not the accuracy
of every value supplied by the original source.
==============================================================================*/

USE WLE;


/* TEST 1: Confirm WLE_raw remains at 2,941 rows and WLE_clean contains 2,938
   after removal of three excess duplicate records. */

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


/* TEST 2: Confirm one record per country-year. Expected: no rows. */

SELECT
    country,
    year,
    COUNT(*) AS record_count
FROM WLE_clean
GROUP BY country, year
HAVING COUNT(*) > 1;


/* TEST 3: Check required dimensions and the remaining life-expectancy NULLs. */

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

/* EXPECTED: 0 missing countries, years, statuses, or Row_ID values; 10 missing
   life-expectancy values from single-year countries with raw zero placeholders. */


/* TEST 4: Trace the eight raw blank Status records to their restored values. */

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

/* EXPECTED: Eight rows with a nonblank, country-consistent clean Status. */


/* TEST 5: Review the only two estimated life-expectancy records against their
   previous and following country years. */

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

/* EXPECTED: Afghanistan 2018 = 59.2; Albania 2018 = 76.6. */


/* TEST 6: Confirm designated zero placeholders were converted to NULL. */

SELECT
    SUM(CASE WHEN life_expectancy = 0 THEN 1 ELSE 0 END) AS zero_life_expectancy,
    SUM(CASE WHEN adult_mortality = 0 THEN 1 ELSE 0 END) AS zero_adult_mortality,
    SUM(CASE WHEN gdp = 0 THEN 1 ELSE 0 END) AS zero_gdp,
    SUM(CASE WHEN bmi = 0 THEN 1 ELSE 0 END) AS zero_bmi,
    SUM(CASE WHEN polio_coverage = 0 THEN 1 ELSE 0 END) AS zero_polio,
    SUM(CASE WHEN diphtheria_coverage = 0 THEN 1 ELSE 0 END) AS zero_diphtheria,
    SUM(CASE WHEN schooling_years = 0 THEN 1 ELSE 0 END) AS zero_schooling
FROM WLE_clean;

/* EXPECTED: Zero remaining numeric zeros in every audited field. */


/* TEST 7: Flag values outside the documented domains and ranges. Passing this
   check does not prove that every in-range source value is accurate. */

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

/* EXPECTED: Zero violations across every audited field. */


/* TEST 8: Separate complete 16-year histories from single-year observations. */

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

/* EXPECTED: Ten countries with one year and 183 countries with 16 years. */


/* TEST 9: Reconcile yearly totals after duplicate removal. Most years should
   contain 183 rows; 2020 should contain 193. */

SELECT
    year,
    COUNT(*) AS records,
    COUNT(DISTINCT country) AS countries
FROM WLE_clean
GROUP BY year
ORDER BY year;


/* TEST 10: Return one final quality-gate result for the analytical table. */

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

/* EXPECTED: PASS — WLE_clean is approved for business analysis. */
