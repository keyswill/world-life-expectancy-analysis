/*==============================================================================
WORLD LIFE EXPECTANCY ANALYSIS
SCRIPT 2: DATA CLEANING

Build reproducible staging and analytical tables without changing WLE_raw.
Transformations cover confirmed duplicates, missing statuses, two internal
life-expectancy gaps, data types, naming, and documented zero placeholders.
==============================================================================*/

USE WLE;


/* SECTION 1: Rebuild WLE_staging from the untouched source so previous runs
   cannot affect the current result. */

DROP TABLE IF EXISTS WLE_staging;

CREATE TABLE WLE_staging LIKE WLE_raw;

INSERT INTO WLE_staging
SELECT *
FROM WLE_raw;

SELECT
    (SELECT COUNT(*) FROM WLE_raw) AS raw_rows,
    (SELECT COUNT(*) FROM WLE_staging) AS staging_rows,
    CASE
        WHEN (SELECT COUNT(*) FROM WLE_raw) =
             (SELECT COUNT(*) FROM WLE_staging)
        THEN 'PASS'
        ELSE 'FAIL'
    END AS copy_validation;

/* EXPECTED: 2,941 raw rows, 2,941 staging rows, PASS. */


/* SECTION 2: Remove three exact duplicate country-year records. Retain the
   lowest Row_ID as a consistent tie-breaker. */

SELECT
    Row_ID,
    Country,
    Year,
    ROW_NUMBER() OVER
    (
        PARTITION BY Country, Year
        ORDER BY Row_ID
    ) AS duplicate_rank
FROM WLE_staging
WHERE (Country, Year) IN
(
    SELECT Country, Year
    FROM WLE_staging
    GROUP BY Country, Year
    HAVING COUNT(*) > 1
)
ORDER BY Country, Year, Row_ID;

DELETE FROM WLE_staging
WHERE Row_ID IN
(
    SELECT Row_ID
    FROM
    (
        SELECT
            Row_ID,
            ROW_NUMBER() OVER
            (
                PARTITION BY Country, Year
                ORDER BY Row_ID
            ) AS duplicate_rank
        FROM WLE_staging
    ) AS ranked_records
    WHERE duplicate_rank > 1
);

/* EXPECTED: Delete Row_ID 1252, 2265, and 2929; retain 2,938 staging rows. */


/* SECTION 3: Restore missing Status values only when the same country has one
   consistent nonblank classification elsewhere in the source. */

SELECT
    Country,
    COUNT(DISTINCT NULLIF(TRIM(Status), '')) AS distinct_nonblank_statuses
FROM WLE_staging
GROUP BY Country
HAVING COUNT(DISTINCT NULLIF(TRIM(Status), '')) > 1;

/* EXPECTED: No country has conflicting nonblank status values. */

UPDATE WLE_staging AS target
INNER JOIN
(
    SELECT *
    FROM
    (
        SELECT
            Country,
            MAX(NULLIF(TRIM(Status), '')) AS resolved_status
        FROM WLE_staging
        GROUP BY Country
    ) AS status_lookup
) AS country_status
    ON target.Country = country_status.Country
SET target.Status = country_status.resolved_status
WHERE target.Status IS NULL
   OR TRIM(target.Status) = '';

/* EXPECTED: Eight missing status values restored. */


/* SECTION 4: Estimate the two internal life-expectancy gaps using the midpoint
   of adjacent country years. Flag both estimates in the clean table. */

SELECT
    target.Country,
    target.Year,
    previous_year.Lifeexpectancy AS previous_life_expectancy,
    following_year.Lifeexpectancy AS following_life_expectancy,
    ROUND
    (
        (
            CAST(previous_year.Lifeexpectancy AS DECIMAL(4,1)) +
            CAST(following_year.Lifeexpectancy AS DECIMAL(4,1))
        ) / 2,
        1
    ) AS proposed_life_expectancy
FROM WLE_staging AS target
INNER JOIN WLE_staging AS previous_year
    ON target.Country = previous_year.Country
    AND previous_year.Year = target.Year - 1
INNER JOIN WLE_staging AS following_year
    ON target.Country = following_year.Country
    AND following_year.Year = target.Year + 1
WHERE target.Lifeexpectancy IS NULL
   OR TRIM(target.Lifeexpectancy) = '';

UPDATE WLE_staging AS target
INNER JOIN WLE_staging AS previous_year
    ON target.Country = previous_year.Country
    AND previous_year.Year = target.Year - 1
INNER JOIN WLE_staging AS following_year
    ON target.Country = following_year.Country
    AND following_year.Year = target.Year + 1
SET target.Lifeexpectancy = ROUND
(
    (
        CAST(previous_year.Lifeexpectancy AS DECIMAL(4,1)) +
        CAST(following_year.Lifeexpectancy AS DECIMAL(4,1))
    ) / 2,
    1
)
WHERE target.Lifeexpectancy IS NULL
   OR TRIM(target.Lifeexpectancy) = '';

/* EXPECTED: Afghanistan 2018 = 59.2; Albania 2018 = 76.6. */


/* SECTION 5: Create WLE_clean with analytical data types, standardized names,
   a unique country-year key, and basic domain constraints.

   Convert implausible zero placeholders to NULL for life expectancy, adult
   mortality, GDP, BMI, vaccination, thinness, and schooling. Retain zeros where
   they may be meaningful or the source definition is unclear. */

DROP TABLE IF EXISTS WLE_clean;

CREATE TABLE WLE_clean
(
    row_id                       BIGINT       NOT NULL,
    country                      VARCHAR(100) NOT NULL,
    year                         SMALLINT     NOT NULL,
    development_status           VARCHAR(15)  NOT NULL,
    life_expectancy              DECIMAL(4,1) NULL,
    life_expectancy_imputed      TINYINT(1)   NOT NULL DEFAULT 0,
    adult_mortality              SMALLINT UNSIGNED NULL,
    infant_deaths                INT UNSIGNED NULL,
    percentage_expenditure       DECIMAL(12,2) NULL,
    measles_cases                INT UNSIGNED NULL,
    bmi                          DECIMAL(4,1) NULL,
    under_five_deaths            INT UNSIGNED NULL,
    polio_coverage               DECIMAL(5,1) NULL,
    diphtheria_coverage          DECIMAL(5,1) NULL,
    hiv_aids                     DECIMAL(5,1) NULL,
    gdp                          DECIMAL(14,2) NULL,
    thinness_1_19_years          DECIMAL(4,1) NULL,
    thinness_5_9_years           DECIMAL(4,1) NULL,
    schooling_years              DECIMAL(4,1) NULL,

    CONSTRAINT pk_wle_clean PRIMARY KEY (row_id),
    CONSTRAINT uq_wle_country_year UNIQUE (country, year),
    CONSTRAINT chk_wle_year CHECK (year BETWEEN 2007 AND 2022),
    CONSTRAINT chk_wle_status CHECK
        (development_status IN ('Developed', 'Developing')),
    CONSTRAINT chk_wle_imputation CHECK
        (life_expectancy_imputed IN (0, 1))
);


/* SECTION 6: Load standardized values and preserve an auditable flag for the
   two estimated life-expectancy records. */

INSERT INTO WLE_clean
(
    row_id,
    country,
    year,
    development_status,
    life_expectancy,
    life_expectancy_imputed,
    adult_mortality,
    infant_deaths,
    percentage_expenditure,
    measles_cases,
    bmi,
    under_five_deaths,
    polio_coverage,
    diphtheria_coverage,
    hiv_aids,
    gdp,
    thinness_1_19_years,
    thinness_5_9_years,
    schooling_years
)
SELECT
    Row_ID,
    TRIM(Country),
    CAST(Year AS UNSIGNED),
    TRIM(Status),
    NULLIF(CAST(Lifeexpectancy AS DECIMAL(4,1)), 0),
    CASE WHEN Row_ID IN (5, 21) THEN 1 ELSE 0 END,
    NULLIF(AdultMortality, 0),
    infantdeaths,
    percentageexpenditure,
    Measles,
    NULLIF(BMI, 0),
    `under-fivedeaths`,
    NULLIF(Polio, 0),
    NULLIF(Diphtheria, 0),
    HIVAIDS,
    NULLIF(GDP, 0),
    NULLIF(`thinness1-19years`, 0),
    NULLIF(`thinness5-9years`, 0),
    NULLIF(Schooling, 0)
FROM WLE_staging;


/* SECTION 7: Reconcile the raw, staging, and clean layers. */

SELECT
    (SELECT COUNT(*) FROM WLE_raw) AS raw_rows,
    (SELECT COUNT(*) FROM WLE_staging) AS staging_rows,
    (SELECT COUNT(*) FROM WLE_clean) AS clean_rows,
    (SELECT COUNT(*) FROM WLE_clean WHERE life_expectancy_imputed = 1)
        AS imputed_life_expectancy_rows,
    (SELECT COUNT(*) FROM WLE_clean WHERE development_status IS NULL)
        AS missing_status_rows;

/* EXPECTED: 2,941 raw rows; 2,938 staging and clean rows; two imputed
   life-expectancy records; no missing Status values.

   Next: run WLE_03_data_validation.sql before business analysis. */
