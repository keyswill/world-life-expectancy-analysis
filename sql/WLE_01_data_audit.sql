/*==============================================================================
PROJECT: World Life Expectancy Analysis
SCRIPT: WLE_01_data_audit.sql
AUTHOR: Kiran Williams
DATABASE: MySQL

PROJECT PURPOSE
-------------------------------------------------------------------------------
This project analyzes country-level health, economic, and education indicators
to help a global health organization identify disparities, monitor changes in
life expectancy, and prioritize countries for additional investigation.

PURPOSE OF THIS SCRIPT
-------------------------------------------------------------------------------
This script performs a read-only audit of the raw World Life Expectancy table
before any cleaning or transformation occurs.

The audit establishes:

    1. The imported table structure and data types
    2. The number of source records
    3. The geographic and time coverage
    4. The intended grain of the dataset
    5. Duplicate country-year records
    6. Countries with incomplete time coverage
    7. Missing values in core analytical fields
    8. Development-status categories
    9. Suspicious zero values requiring further investigation

DATA-HANDLING PRINCIPLE
-------------------------------------------------------------------------------
WLE_raw is the untouched source layer. This script contains only SELECT,
DESCRIBE, and SHOW statements and does not modify the raw data.

Recorded results reflect the supplied CSV and provide a baseline against which
the later cleaning process can be reconciled.
==============================================================================*/


/*------------------------------------------------------------------------------
SECTION 1: SELECT THE PROJECT DATABASE

This statement establishes the database context for every query that follows.
------------------------------------------------------------------------------*/

USE WLE;


/*------------------------------------------------------------------------------
SECTION 2: INSPECT THE RAW TABLE STRUCTURE

DESCRIBE returns each column's name, data type, nullability, key status, and
default value.

Business relevance:
Incorrect data types can produce inaccurate calculations. For example,
Lifeexpectancy was imported as text and must be converted to a numeric type in
the analytical layer before averages, changes, and rankings are calculated.
------------------------------------------------------------------------------*/

DESCRIBE WLE_raw;

/*
AUDIT RESULT
------------
The raw table contains 18 columns. All columns allow NULL values, Row_ID is not
defined as a primary key, and Lifeexpectancy was imported as VARCHAR rather
than a numeric type.

Interpretation:
The Import Wizard preserved the source values, but a properly typed analytical
table will be needed for reliable calculations and enforceable data rules.
*/


/*------------------------------------------------------------------------------
SECTION 3: RETRIEVE THE COMPLETE RAW TABLE DEFINITION

SHOW CREATE TABLE documents the exact imported schema, including the storage
engine, character set, column definitions, and existing constraints.

This creates an auditable record of the source structure before transformations
are applied in a separate staging table.
------------------------------------------------------------------------------*/

SHOW CREATE TABLE WLE_raw;


/*------------------------------------------------------------------------------
SECTION 4: REVIEW A SAMPLE OF THE IMPORTED DATA

A small sample verifies that values aligned with the expected columns during
the CSV import. LIMIT avoids retrieving the entire table for a visual check.
------------------------------------------------------------------------------*/

SELECT *
FROM WLE_raw
LIMIT 10;


/*------------------------------------------------------------------------------
SECTION 5: ESTABLISH THE BASELINE ROW COUNT

The raw row count is the control total for the cleaning process. Any difference
between the raw and cleaned tables must later be explained by a documented
transformation, such as the removal of confirmed duplicate records.
------------------------------------------------------------------------------*/

SELECT
    COUNT(*) AS total_imported_rows
FROM WLE_raw;

/*
AUDIT RESULT
------------
Total imported rows: 2,941

Interpretation:
The raw MySQL table reconciles to the supplied CSV row count.
*/


/*------------------------------------------------------------------------------
SECTION 6: MEASURE GEOGRAPHIC AND TIME COVERAGE

These metrics define the analytical scope of the dataset:

    - Number of represented countries
    - Earliest available year
    - Latest available year
    - Number of distinct years
------------------------------------------------------------------------------*/

SELECT
    COUNT(DISTINCT Country) AS distinct_countries,
    MIN(Year) AS earliest_year,
    MAX(Year) AS latest_year,
    COUNT(DISTINCT Year) AS distinct_years
FROM WLE_raw;

/*
AUDIT RESULT
------------
Distinct countries: 193
Earliest year:       2007
Latest year:         2022
Distinct years:      16

Interpretation:
The dataset provides a 16-year analytical window, but country-level coverage
must be checked before all countries are included in trend comparisons.
*/


/*------------------------------------------------------------------------------
SECTION 7: REVIEW RECORD COUNTS BY YEAR

This query compares total rows with distinct countries for every year.

If total records exceed distinct countries, at least one country-year may be
duplicated. If country coverage changes materially between years, comparisons
of unweighted annual averages may also be affected by the changing sample.
------------------------------------------------------------------------------*/

SELECT
    Year,
    COUNT(*) AS records_per_year,
    COUNT(DISTINCT Country) AS countries_per_year
FROM WLE_raw
GROUP BY Year
ORDER BY Year;

/*
AUDIT RESULT
------------
Most years contain 183 countries and 183 records.

Exceptions:
    - 2009 contains 183 countries and 184 records.
    - 2019 contains 183 countries and 184 records.
    - 2022 contains 183 countries and 184 records.
    - 2020 contains 193 countries and 193 records.

Interpretation:
The three years with more records than countries contain duplicate observations.
Ten additional countries appear only in 2020, creating incomplete histories
that must be excluded from longitudinal rankings.
*/


/*------------------------------------------------------------------------------
SECTION 8: IDENTIFY DUPLICATE COUNTRY-YEAR COMBINATIONS

DATA GRAIN
One row is intended to represent one country during one year. Country and Year
therefore form the expected natural key.

Any combination appearing more than once can improperly increase that
country-year's influence on averages and other aggregated metrics.
------------------------------------------------------------------------------*/

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

/*
AUDIT RESULT
------------
Ireland, 2022:  2 records
Senegal, 2009:  2 records
Zimbabwe, 2019: 2 records

Interpretation:
The raw dataset contains three duplicated country-year groups. The paired
records contain identical analytical values and differ only in Row_ID.
*/


/*------------------------------------------------------------------------------
SECTION 9: COUNT EXCESS DUPLICATE ROWS

This query counts rows beyond the expected one record per country-year group.
For example, a group appearing three times contains two excess rows.

COALESCE converts the NULL returned by SUM when no duplicate groups exist into
an interpretable value of zero, making the validation reusable after cleaning.
------------------------------------------------------------------------------*/

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

/*
AUDIT RESULT
------------
Excess duplicate rows: 3

Interpretation:
Removing one confirmed copy from each duplicated group should reduce the row
count from 2,941 to 2,938 without eliminating a unique country-year observation.
*/


/*------------------------------------------------------------------------------
SECTION 10: IDENTIFY COUNTRIES WITH INCOMPLETE TIME COVERAGE

The supplied dataset spans 16 years. A country requires 16 distinct years to
have a complete history for this dataset.

COUNT(DISTINCT Year), rather than COUNT(*), prevents duplicate rows from making
a country's history appear more complete than it is.

Countries with fewer than 16 years should not be included in first-to-last
trend rankings because a single observation cannot establish change over time.
------------------------------------------------------------------------------*/

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

/*
AUDIT RESULT
------------
Ten countries contain only a 2020 observation:

    - Cook Islands
    - Dominica
    - Marshall Islands
    - Monaco
    - Nauru
    - Niue
    - Palau
    - Saint Kitts and Nevis
    - San Marino
    - Tuvalu

Interpretation:
These countries may be included in eligible cross-sectional analyses for 2020,
but they must be excluded from multi-year trend calculations.
*/


/*------------------------------------------------------------------------------
SECTION 11: AUDIT MISSING VALUES IN CORE FIELDS

This query counts both SQL NULL values and blank strings because CSV imports
can represent missing data in different ways.

Zero values are evaluated separately. A zero may be valid for some measures,
such as reported measles cases, but implausible or unavailable for others.
------------------------------------------------------------------------------*/

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

/*
AUDIT RESULT
------------
Missing country values:         0
Missing year values:            0
Missing status values:          8
Missing life-expectancy values: 2

Interpretation:
Country and Year are complete. Status can be restored only when another row for
the same country provides an unambiguous classification. The two missing life-
expectancy observations require a documented imputation or exclusion rule.
*/


/*------------------------------------------------------------------------------
SECTION 12: REVIEW DEVELOPMENT-STATUS CATEGORIES

Status should contain a controlled set of categories. This frequency table
exposes missing values, inconsistent capitalization, spelling differences, and
unexpected classifications before standardization.
------------------------------------------------------------------------------*/

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

/*
AUDIT RESULT
------------
Developing: 2,421 records
Developed:    512 records
[BLANK]:        8 records

Control total: 2,941 records

Interpretation:
No misspelled or inconsistently capitalized categories were identified. Eight
records require status restoration during cleaning.
*/


/*------------------------------------------------------------------------------
SECTION 13: IDENTIFY SUSPICIOUS ZERO VALUES

Zero does not have the same meaning across every metric.

Examples:
    - Zero infant deaths or measles cases may be possible.
    - Zero GDP is unlikely to represent a valid economic measurement.
    - Zero life expectancy is not a plausible country-level outcome.
    - Zero vaccination coverage, BMI, or schooling may represent unavailable
      data rather than a measured value.

This query documents zero frequency without automatically changing values.
Each metric will receive a field-specific rule during cleaning and analysis.
------------------------------------------------------------------------------*/

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

/*
AUDIT RESULT
------------
Zero life-expectancy values: 10
Zero adult-mortality values: 10
Zero GDP values:             448
Zero BMI values:              34
Zero Polio values:            19
Zero Diphtheria values:       19
Zero Schooling values:       191

Interpretation:
Zero-frequency patterns suggest that several variables use zero as a missing-
data placeholder. These values must not be included automatically in averages,
correlations, or country comparisons. Field-specific analytical rules will be
documented before the business analysis begins.
*/


/*==============================================================================
FINAL AUDIT SUMMARY
-------------------------------------------------------------------------------
Raw records:                         2,941
Countries:                             193
Years:                           2007-2022
Duplicate country-year groups:           3
Excess duplicate records:                 3
Missing status values:                    8
Missing life-expectancy values:           2
Countries with incomplete histories:     10

NEXT STEP
-------------------------------------------------------------------------------
Create WLE_staging as a reproducible working copy of WLE_raw. All cleaning will
occur in the staging or analytical layers while WLE_raw remains unchanged.
==============================================================================*/
