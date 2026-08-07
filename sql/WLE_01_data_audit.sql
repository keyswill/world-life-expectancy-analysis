/*==============================================================================
WORLD LIFE EXPECTANCY ANALYSIS
SCRIPT 1: RAW DATA AUDIT

This read-only audit establishes the source structure, record count, coverage,
expected country-year grain, missing values, duplicates, and suspicious zeros
before cleaning begins. WLE_raw is never modified.
==============================================================================*/


/* SECTION 1: Select the project database. */

USE WLE;


/* SECTION 2: Inspect the imported structure and identify fields that need
   stronger data types in the analytical table. */

DESCRIBE WLE_raw;

/* RESULT: WLE_raw has 18 nullable columns. Row_ID is not a primary key, and
   Lifeexpectancy was imported as text. */


/* SECTION 3: Record the complete source-table definition before transformation. */

SHOW CREATE TABLE WLE_raw;


/* SECTION 4: Review a small sample to confirm that the CSV values aligned with
   the expected columns during import. */

SELECT *
FROM WLE_raw
LIMIT 10;


/* SECTION 5: Establish the raw control total for later reconciliation. */

SELECT
    COUNT(*) AS total_imported_rows
FROM WLE_raw;

/* RESULT: 2,941 imported rows, matching the supplied CSV. */


/* SECTION 6: Confirm the geographic and time coverage of the dataset. */

SELECT
    COUNT(DISTINCT Country) AS distinct_countries,
    MIN(Year) AS earliest_year,
    MAX(Year) AS latest_year,
    COUNT(DISTINCT Year) AS distinct_years
FROM WLE_raw;

/* RESULT: 193 countries across 2007-2022, a 16-year reporting window. */


/* SECTION 7: Compare yearly record counts with distinct-country counts.
   Differences can reveal duplicates or changes in country coverage. */

SELECT
    Year,
    COUNT(*) AS records_per_year,
    COUNT(DISTINCT Country) AS countries_per_year
FROM WLE_raw
GROUP BY Year
ORDER BY Year;

/* RESULT: Most years contain 183 countries. The 2009, 2019, and 2022 totals
   each contain one duplicate; 2020 includes ten additional single-year countries. */


/* SECTION 8: Find duplicate country-year keys. One row should represent one
   country in one year; duplicates would distort aggregated results. */

SELECT
    Country,
    Year,
    COUNT(*) AS record_count
FROM WLE_raw
GROUP BY
    Country,
    Year
HAVING COUNT(*) > 1
ORDER BY
    record_count DESC,
    Country,
    Year;

/* RESULT: Ireland 2022, Senegal 2009, and Zimbabwe 2019 are duplicated.
   Each pair has identical analytical values and differs only by Row_ID. */


/* SECTION 9: Count records beyond the expected one row per country-year. */

SELECT
    COALESCE(SUM(record_count - 1), 0) AS excess_duplicate_rows
FROM
(
    SELECT
        Country,
        Year,
        COUNT(*) AS record_count
    FROM WLE_raw
    GROUP BY
        Country,
        Year
    HAVING COUNT(*) > 1
) AS duplicate_summary;

/* RESULT: Three excess duplicate rows. Removing one confirmed copy from each
   pair should reconcile 2,941 raw rows to 2,938 clean rows. */


/* SECTION 10: Identify countries without all 16 years of history. These
   countries cannot support first-to-last trend comparisons. */

SELECT
    Country,
    COUNT(*) AS total_records,
    COUNT(DISTINCT Year) AS years_available,
    MIN(Year) AS first_available_year,
    MAX(Year) AS last_available_year
FROM WLE_raw
GROUP BY Country
HAVING COUNT(DISTINCT Year) < 16
ORDER BY
    years_available ASC,
    Country;

/* RESULT: Ten countries appear only in 2020. They may support eligible
   cross-sectional analysis but must be excluded from longitudinal rankings. */


/* SECTION 11: Count NULL and blank values in fields required for analysis.
   Zero values are reviewed separately because their meaning varies by metric. */

SELECT
    SUM(
        CASE
            WHEN Country IS NULL OR TRIM(Country) = '' THEN 1
            ELSE 0
        END
    ) AS missing_country,

    SUM(
        CASE
            WHEN Year IS NULL OR TRIM(CAST(Year AS CHAR)) = '' THEN 1
            ELSE 0
        END
    ) AS missing_year,

    SUM(
        CASE
            WHEN Status IS NULL OR TRIM(Status) = '' THEN 1
            ELSE 0
        END
    ) AS missing_status,

    SUM(
        CASE
            WHEN Lifeexpectancy IS NULL OR TRIM(Lifeexpectancy) = '' THEN 1
            ELSE 0
        END
    ) AS missing_life_expectancy
FROM WLE_raw;

/* RESULT: Country and Year are complete. Eight Status values and two
   Lifeexpectancy values are missing and require documented treatment. */


/* SECTION 12: Review the development-status domain for unexpected categories. */

SELECT
    CASE
        WHEN Status IS NULL THEN '[NULL]'
        WHEN TRIM(Status) = '' THEN '[BLANK]'
        ELSE TRIM(Status)
    END AS status_value,
    COUNT(*) AS record_count
FROM WLE_raw
GROUP BY
    CASE
        WHEN Status IS NULL THEN '[NULL]'
        WHEN TRIM(Status) = '' THEN '[BLANK]'
        ELSE TRIM(Status)
    END
ORDER BY record_count DESC;

/* RESULT: 2,421 Developing, 512 Developed, and 8 blank records. No spelling or
   capitalization problems were found. */


/* SECTION 13: Count suspicious zeros without changing them. Some zeros may be
   valid; others may represent missing data and require field-specific rules. */

SELECT
    SUM(
        CASE
            WHEN Lifeexpectancy IS NOT NULL
                 AND TRIM(Lifeexpectancy) <> ''
                 AND CAST(Lifeexpectancy AS DECIMAL(5,2)) = 0
            THEN 1
            ELSE 0
        END
    )
        AS zero_life_expectancy,

    SUM(CASE WHEN AdultMortality = 0 THEN 1 ELSE 0 END)
        AS zero_adult_mortality,

    SUM(CASE WHEN GDP = 0 THEN 1 ELSE 0 END)
        AS zero_gdp,

    SUM(CASE WHEN BMI = 0 THEN 1 ELSE 0 END)
        AS zero_bmi,

    SUM(CASE WHEN Polio = 0 THEN 1 ELSE 0 END)
        AS zero_polio,

    SUM(CASE WHEN Diphtheria = 0 THEN 1 ELSE 0 END)
        AS zero_diphtheria,

    SUM(CASE WHEN Schooling = 0 THEN 1 ELSE 0 END)
        AS zero_schooling
FROM WLE_raw;

/* RESULT: Several analytical fields contain zeros that could bias averages and
   correlations. Their treatment will be documented during cleaning. */


/*==============================================================================
AUDIT SUMMARY
2,941 raw rows | 193 countries | 2007-2022 | 3 excess duplicates
8 missing status values | 2 missing life-expectancy values
10 countries with incomplete histories

Next: rebuild a working staging layer while preserving WLE_raw.
==============================================================================*/
