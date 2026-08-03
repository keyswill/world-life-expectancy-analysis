/*==============================================================================
PROJECT: World Life Expectancy Analysis
SCRIPT: WLE_04_business_analysis.sql
AUTHOR: Kiran Williams
DATABASE: MySQL 8.0+

STAKEHOLDER
-------------------------------------------------------------------------------
A global health program director deciding which countries warrant further
investigation and targeted support.

PRIMARY BUSINESS QUESTION
-------------------------------------------------------------------------------
Which countries demonstrate the greatest health-outcome needs or improvement
opportunities based on life expectancy, mortality, immunization, education,
and economic indicators?

INTERPRETATION GUARDRAIL
-------------------------------------------------------------------------------
The analysis identifies associations and prioritization signals. It does not
prove causation or justify funding decisions without local context, population
data, program-cost data, and current field validation.
==============================================================================*/

USE WLE;


/*------------------------------------------------------------------------------
QUESTION 1: HOW DID AVERAGE LIFE EXPECTANCY CHANGE FROM 2007 TO 2022?

Metric:
Unweighted mean country life expectancy by year. Each country contributes one
observation, preventing countries with larger populations from dominating the
measure. This is a country benchmark, not a population-weighted global estimate.
------------------------------------------------------------------------------*/

SELECT
    year,
    COUNT(life_expectancy) AS countries_with_data,
    ROUND(AVG(life_expectancy), 2) AS average_life_expectancy
FROM WLE_clean
WHERE life_expectancy IS NOT NULL
GROUP BY year
ORDER BY year;

/*
KEY RESULT
----------
2007 average: 66.75 years
2022 average: 71.62 years
Change:        4.87 years, or 7.29%

Business implication:
The country-level benchmark improved, but the average alone can conceal nations
that stagnated or declined. Country-specific trend analysis is required.
*/


/*------------------------------------------------------------------------------
QUESTION 2: WHICH COUNTRIES IMPROVED OR DECLINED THE MOST?

Only countries with valid observations in both 2007 and 2022 are eligible.
This measures true first-to-last change, unlike MAX minus MIN, which measures
range and can mislabel temporary volatility as sustained improvement.
------------------------------------------------------------------------------*/

WITH country_endpoints AS
(
    SELECT
        country,
        MAX(CASE WHEN year = 2007 THEN life_expectancy END) AS life_expectancy_2007,
        MAX(CASE WHEN year = 2022 THEN life_expectancy END) AS life_expectancy_2022
    FROM WLE_clean
    GROUP BY country
),
country_change AS
(
    SELECT
        country,
        life_expectancy_2007,
        life_expectancy_2022,
        life_expectancy_2022 - life_expectancy_2007 AS total_change,
        (life_expectancy_2022 - life_expectancy_2007) / 15 AS annualized_change
    FROM country_endpoints
    WHERE life_expectancy_2007 IS NOT NULL
      AND life_expectancy_2022 IS NOT NULL
)
SELECT
    country,
    life_expectancy_2007,
    life_expectancy_2022,
    ROUND(total_change, 1) AS total_change_years,
    ROUND(annualized_change, 2) AS average_change_per_year
FROM country_change
ORDER BY total_change DESC;

/*
KEY RESULT
----------
Largest gains included Zimbabwe (+21.0), Eritrea (+19.4), Zambia (+18.0),
Botswana (+17.9), and Rwanda (+17.8) years.

Largest declines included Syrian Arab Republic (-8.1), Saint Vincent and the
Grenadines (-5.8), Libya (-5.3), Paraguay (-5.0), and Yemen (-2.3) years.

Business implication:
High-improvement countries warrant investigation for transferable practices,
while declining countries require contextual review of instability, health-
system disruption, and data quality before intervention design.
*/


/*------------------------------------------------------------------------------
QUESTION 3: HOW LARGE IS THE DEVELOPED-DEVELOPING OUTCOME GAP?

Both the full-period and latest-year views are shown. Record counts are included
so decision-makers can see the unequal group sizes rather than interpreting the
averages without sample context.
------------------------------------------------------------------------------*/

SELECT
    development_status,
    COUNT(life_expectancy) AS observations,
    COUNT(DISTINCT country) AS countries,
    ROUND(AVG(life_expectancy), 2) AS average_life_expectancy
FROM WLE_clean
WHERE life_expectancy IS NOT NULL
GROUP BY development_status;

SELECT
    development_status,
    COUNT(*) AS countries,
    ROUND(AVG(life_expectancy), 2) AS average_life_expectancy
FROM WLE_clean
WHERE year = 2022
  AND life_expectancy IS NOT NULL
GROUP BY development_status;

/*
KEY RESULT
----------
Full period: Developed 79.20 years; Developing 67.11 years; gap 12.09 years.
2022:        Developed 80.71 years; Developing 69.69 years; gap 11.02 years.

Business implication:
The 2022 gap was smaller than the full-period gap but remained material. Status
is a broad classification, so country-level drivers must guide prioritization.
*/


/*------------------------------------------------------------------------------
QUESTION 4: WHICH METRICS HAVE THE STRONGEST ASSOCIATIONS WITH LIFE EXPECTANCY?

Pearson correlation is calculated from complete pairs for each metric. Pairwise
sample size is shown because missingness differs by field.

Correlation ranges from -1 to +1. A large absolute value indicates a stronger
linear relationship, not a causal effect.
------------------------------------------------------------------------------*/

WITH metric_pairs AS
(
    SELECT 'GDP' AS metric, life_expectancy AS x, gdp AS y
    FROM WLE_clean WHERE life_expectancy IS NOT NULL AND gdp IS NOT NULL
    UNION ALL
    SELECT 'Schooling', life_expectancy, schooling_years
    FROM WLE_clean WHERE life_expectancy IS NOT NULL AND schooling_years IS NOT NULL
    UNION ALL
    SELECT 'Adult Mortality', life_expectancy, adult_mortality
    FROM WLE_clean WHERE life_expectancy IS NOT NULL AND adult_mortality IS NOT NULL
    UNION ALL
    SELECT 'Polio Coverage', life_expectancy, polio_coverage
    FROM WLE_clean WHERE life_expectancy IS NOT NULL AND polio_coverage IS NOT NULL
    UNION ALL
    SELECT 'Diphtheria Coverage', life_expectancy, diphtheria_coverage
    FROM WLE_clean WHERE life_expectancy IS NOT NULL AND diphtheria_coverage IS NOT NULL
    UNION ALL
    SELECT 'HIV/AIDS', life_expectancy, hiv_aids
    FROM WLE_clean WHERE life_expectancy IS NOT NULL AND hiv_aids IS NOT NULL
    UNION ALL
    SELECT 'BMI', life_expectancy, bmi
    FROM WLE_clean WHERE life_expectancy IS NOT NULL AND bmi IS NOT NULL
),
correlation_components AS
(
    SELECT
        metric,
        COUNT(*) AS pair_count,
        SUM(x) AS sum_x,
        SUM(y) AS sum_y,
        SUM(x * y) AS sum_xy,
        SUM(x * x) AS sum_x_squared,
        SUM(y * y) AS sum_y_squared
    FROM metric_pairs
    GROUP BY metric
)
SELECT
    metric,
    pair_count,
    ROUND
    (
        (pair_count * sum_xy - sum_x * sum_y) /
        SQRT
        (
            (pair_count * sum_x_squared - POWER(sum_x, 2)) *
            (pair_count * sum_y_squared - POWER(sum_y, 2))
        ),
        3
    ) AS pearson_correlation
FROM correlation_components
ORDER BY ABS(pearson_correlation) DESC;

/*
KEY RESULT
----------
Schooling:            +0.784
Adult mortality:      -0.696
BMI:                  +0.568
HIV/AIDS:             -0.557
Diphtheria coverage:  +0.479
Polio coverage:       +0.466
GDP:                  +0.461

Business implication:
Education and mortality measures provide the strongest screening signals in
this dataset. Program leaders should combine them with immunization and economic
context rather than relying on GDP alone.
*/


/*------------------------------------------------------------------------------
QUESTION 5: WHICH 2022 COUNTRIES SHOW THE BROADEST COMBINATION OF NEED SIGNALS?

Priority score:
One point is assigned for each metric falling on the higher-need side of the
2022 median among countries with complete values for all six indicators.

    - Below-median life expectancy
    - Above-median adult mortality
    - Below-median Polio coverage
    - Below-median Diphtheria coverage
    - Below-median schooling
    - Below-median GDP

The score is a transparent screening tool, not a funding formula. Equal weights
avoid implying unsupported precision about the relative value of each metric.
------------------------------------------------------------------------------*/

WITH latest_complete AS
(
    SELECT *
    FROM WLE_clean
    WHERE year = 2022
      AND life_expectancy IS NOT NULL
      AND adult_mortality IS NOT NULL
      AND polio_coverage IS NOT NULL
      AND diphtheria_coverage IS NOT NULL
      AND schooling_years IS NOT NULL
      AND gdp IS NOT NULL
),
ranked_metrics AS
(
    SELECT
        *,
        PERCENT_RANK() OVER (ORDER BY life_expectancy) AS life_expectancy_rank,
        PERCENT_RANK() OVER (ORDER BY adult_mortality) AS mortality_rank,
        PERCENT_RANK() OVER (ORDER BY polio_coverage) AS polio_rank,
        PERCENT_RANK() OVER (ORDER BY diphtheria_coverage) AS diphtheria_rank,
        PERCENT_RANK() OVER (ORDER BY schooling_years) AS schooling_rank,
        PERCENT_RANK() OVER (ORDER BY gdp) AS gdp_rank
    FROM latest_complete
),
priority_flags AS
(
    SELECT
        country,
        life_expectancy,
        adult_mortality,
        polio_coverage,
        diphtheria_coverage,
        schooling_years,
        gdp,
        CASE WHEN life_expectancy_rank < 0.50 THEN 1 ELSE 0 END AS low_life_expectancy,
        CASE WHEN mortality_rank >= 0.50 THEN 1 ELSE 0 END AS high_adult_mortality,
        CASE WHEN polio_rank < 0.50 THEN 1 ELSE 0 END AS low_polio_coverage,
        CASE WHEN diphtheria_rank < 0.50 THEN 1 ELSE 0 END AS low_diphtheria_coverage,
        CASE WHEN schooling_rank < 0.50 THEN 1 ELSE 0 END AS low_schooling,
        CASE WHEN gdp_rank < 0.50 THEN 1 ELSE 0 END AS low_gdp
    FROM ranked_metrics
)
SELECT
    country,
    low_life_expectancy + high_adult_mortality + low_polio_coverage +
    low_diphtheria_coverage + low_schooling + low_gdp AS priority_score,
    life_expectancy,
    adult_mortality,
    polio_coverage,
    diphtheria_coverage,
    schooling_years,
    gdp
FROM priority_flags
ORDER BY priority_score DESC, life_expectancy ASC, country;

/*
Business implication:
Countries scoring across all six need signals should move to a second-stage
assessment incorporating population affected, local program capacity, current
data, intervention costs, and country-specific context.
*/


/*------------------------------------------------------------------------------
QUESTION 6: WHICH COUNTRIES OUTPERFORM OR UNDERPERFORM ECONOMIC PEERS?

Countries are divided into 2022 GDP quartiles. Life expectancy is compared with
the average of the relevant GDP peer group. This identifies outcomes that GDP
alone does not explain and supports peer-learning or diagnostic follow-up.
------------------------------------------------------------------------------*/

WITH latest_gdp AS
(
    SELECT
        country,
        life_expectancy,
        gdp,
        NTILE(4) OVER (ORDER BY gdp) AS gdp_quartile
    FROM WLE_clean
    WHERE year = 2022
      AND life_expectancy IS NOT NULL
      AND gdp IS NOT NULL
),
peer_benchmarks AS
(
    SELECT
        gdp_quartile,
        AVG(life_expectancy) AS peer_average_life_expectancy
    FROM latest_gdp
    GROUP BY gdp_quartile
)
SELECT
    latest.country,
    latest.gdp_quartile,
    latest.gdp,
    latest.life_expectancy,
    ROUND(peer.peer_average_life_expectancy, 2) AS peer_average_life_expectancy,
    ROUND
    (
        latest.life_expectancy - peer.peer_average_life_expectancy,
        2
    ) AS performance_vs_peer_average
FROM latest_gdp AS latest
INNER JOIN peer_benchmarks AS peer
    ON latest.gdp_quartile = peer.gdp_quartile
ORDER BY performance_vs_peer_average DESC;

/*
Business implication:
Positive outliers may reveal practices worth investigating. Negative outliers
may indicate barriers not captured by GDP, but the result should not be treated
as causal or as proof of program effectiveness.
*/


/*------------------------------------------------------------------------------
EXECUTIVE KPI SUMMARY

This final query returns a compact latest-year snapshot suitable for an
executive summary or future dashboard.
------------------------------------------------------------------------------*/

SELECT
    year,
    COUNT(life_expectancy) AS countries_with_life_expectancy,
    ROUND(AVG(life_expectancy), 2) AS average_life_expectancy,
    ROUND(AVG(adult_mortality), 2) AS average_adult_mortality,
    ROUND(AVG(polio_coverage), 2) AS average_polio_coverage,
    ROUND(AVG(diphtheria_coverage), 2) AS average_diphtheria_coverage,
    ROUND(AVG(schooling_years), 2) AS average_schooling_years
FROM WLE_clean
WHERE year = 2022
GROUP BY year;

/*==============================================================================
RECOMMENDED DECISION SEQUENCE
-------------------------------------------------------------------------------
1. Use the priority score to identify candidates for further investigation.
2. Review outcome trends and GDP-peer performance for each candidate.
3. Validate signals with current country-level and population-weighted data.
4. Add intervention costs, local capacity, equity, and implementation risk.
5. Make funding decisions only after stakeholder and subject-matter review.
==============================================================================*/
