/*==============================================================================
PROJECT: World Life Expectancy Analysis
SCRIPT: WLE_02_data_cleaning.sql
AUTHOR: Kiran Williams
DATABASE: MySQL 8.0+

PURPOSE
-------------------------------------------------------------------------------
Create a reproducible analytical table from WLE_raw while preserving the raw
source. The script removes exact duplicates, restores unambiguous statuses,
imputes two internal life-expectancy gaps, standardizes names and data types,
and converts implausible zero placeholders to NULL where appropriate.

CORE PRINCIPLE
-------------------------------------------------------------------------------
WLE_raw is never modified. WLE_staging and WLE_clean can be rebuilt by rerunning
this script, allowing another analyst to reproduce every transformation.
==============================================================================*/

USE WLE;


/*------------------------------------------------------------------------------
SECTION 1: REBUILD THE STAGING TABLE

The staging table is a disposable working copy. Rebuilding it from WLE_raw
prevents previous test runs from contaminating the final process.
------------------------------------------------------------------------------*/

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

/* EXPECTED RESULT: 2,941 raw rows, 2,941 staging rows, PASS. */


/*------------------------------------------------------------------------------
SECTION 2: REMOVE EXACT DUPLICATE COUNTRY-YEAR RECORDS

Business rule:
One row should represent one country in one year. The three duplicate pairs
contain identical analytical values and differ only by Row_ID. The lowest
Row_ID is retained as a deterministic tie-breaker.
------------------------------------------------------------------------------*/

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

/*
EXPECTED RESULT
---------------
Deleted Row_ID values: 1252, 2265, and 2929
Remaining staging rows: 2,938
*/


/*------------------------------------------------------------------------------
SECTION 3: RESTORE MISSING DEVELOPMENT STATUS

Status is stable within every country in the source. A blank value can therefore
be restored from another nonblank record for the same country.

The preliminary consistency check must return zero countries. If a country had
multiple nonblank statuses, an external business rule would be required rather
than automatically selecting one.
------------------------------------------------------------------------------*/

SELECT
    Country,
    COUNT(DISTINCT NULLIF(TRIM(Status), '')) AS distinct_nonblank_statuses
FROM WLE_staging
GROUP BY Country
HAVING COUNT(DISTINCT NULLIF(TRIM(Status), '')) > 1;

/* EXPECTED RESULT: zero rows. */

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

/* EXPECTED RESULT: 8 rows updated. */


/*------------------------------------------------------------------------------
SECTION 4: IMPUTE TWO INTERNAL LIFE-EXPECTANCY GAPS

Only two life-expectancy values are blank. Both occur between valid observations
for the same country. Linear midpoint interpolation is used because it preserves
the local country trend without borrowing information from unrelated countries.

This is an estimate, not an observed measurement. The affected rows are recorded
in the final table through life_expectancy_imputed = 1.
------------------------------------------------------------------------------*/

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

/*
EXPECTED RESULT
---------------
Afghanistan, 2018: 59.2
Albania, 2018:     76.6
*/


/*------------------------------------------------------------------------------
SECTION 5: CREATE THE TYPED ANALYTICAL TABLE

WLE_clean uses concise snake_case names and purpose-appropriate data types.
Constraints enforce the expected grain, year range, and status categories.

Zero-handling rules:
    Converted to NULL: life expectancy, adult mortality, GDP, BMI, Polio,
    Diphtheria, thinness measures, and schooling.

    Retained as zero: infant deaths, under-five deaths, measles cases, HIV/AIDS,
    and percentage expenditure because zero can be meaningful or its meaning is
    too ambiguous to overwrite without additional source documentation.
------------------------------------------------------------------------------*/

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


/*------------------------------------------------------------------------------
SECTION 6: LOAD STANDARDIZED VALUES INTO WLE_clean

The two known source gaps are identified by Row_ID so the imputation flag remains
auditable. NULLIF converts designated zero placeholders to SQL NULL, preventing
them from biasing averages, relationships, and country rankings.
------------------------------------------------------------------------------*/

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


/*------------------------------------------------------------------------------
SECTION 7: CLEANING RECONCILIATION

The final control totals provide immediate evidence that the script produced the
expected analytical layer without modifying the source.
------------------------------------------------------------------------------*/

SELECT
    (SELECT COUNT(*) FROM WLE_raw) AS raw_rows,
    (SELECT COUNT(*) FROM WLE_staging) AS staging_rows,
    (SELECT COUNT(*) FROM WLE_clean) AS clean_rows,
    (SELECT COUNT(*) FROM WLE_clean WHERE life_expectancy_imputed = 1)
        AS imputed_life_expectancy_rows,
    (SELECT COUNT(*) FROM WLE_clean WHERE development_status IS NULL)
        AS missing_status_rows;

/*
EXPECTED RESULT
---------------
Raw rows:                        2,941
Staging rows:                    2,938
Clean rows:                      2,938
Imputed life-expectancy rows:        2
Missing status rows:                 0

The next script, WLE_03_data_validation.sql, performs independent quality and
reconciliation tests before WLE_clean is approved for business analysis.
*/
