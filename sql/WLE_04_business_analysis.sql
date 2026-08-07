/*==============================================================================
WORLD LIFE EXPECTANCY ANALYSIS
SCRIPT 4: BUSINESS ANALYSIS

Audience: a global health program director deciding where deeper investigation
may be warranted.

Main question: Which countries show the strongest health-outcome needs or
improvement opportunities across mortality, immunization, education, and
economic indicators?

The results are prioritization signals, not causal findings or automatic funding
decisions. Local context, current data, population, cost, and capacity are not
included in this dataset.
==============================================================================*/

USE WLE;


/* QUESTION 1: How did the unweighted country average for life expectancy
   change from 2007 to 2022? This is not a population-weighted global estimate. */

SELECT
    year,
    COUNT(life_expectancy) AS countries_with_data,
    ROUND(AVG(life_expectancy), 2) AS average_life_expectancy
FROM WLE_clean
WHERE life_expectancy IS NOT NULL
GROUP BY year
ORDER BY year;

/* RESULT: The average increased from 66.75 to 71.62 years, a gain of 4.87
   years (7.29%). The average can still conceal countries that declined. */


/* QUESTION 2: Which countries changed the most between valid 2007 and 2022
   observations? First-to-last change avoids treating temporary range as trend. */

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

/* RESULT: The largest gains include Zimbabwe (+21.0), Eritrea (+19.4), and
   Zambia (+18.0). The largest declines include Syrian Arab Republic (-8.1),
   Saint Vincent and the Grenadines (-5.8), and Libya (-5.3).

   Use these results to select countries for contextual review, not to assign
   causes or design interventions from this dataset alone. */


/* QUESTION 3: How large is the life-expectancy gap between developed and
   developing groups? Include record counts because group sizes differ. */

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

/* RESULT: The full-period gap is 12.09 years; the 2022 gap is 11.02 years.
   The broad Status category does not explain the country-level drivers. */


/* QUESTION 4: Which metrics have the strongest linear relationships with life
   expectancy? Pairwise sample sizes are shown because missingness varies.
   Correlation measures association, not causation. */

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

/* RESULT: Schooling has the strongest positive relationship (r = 0.784), and
   adult mortality has the strongest negative relationship (r = -0.696).
   These are screening signals that should be considered with health-system,
   immunization, and economic context. */


/* QUESTION 5: Which 2022 countries fall on the higher-need side of all six
   median benchmarks? One point is assigned for each signal.

   The equal-weight score is transparent but intentionally simple. It creates a
   review list; it is not a funding formula. */

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

/* DECISION USE: Countries with several need signals should move to a second
   review using population, current conditions, capacity, cost, and local context. */


/* QUESTION 6: Which countries outperform or underperform the average of their
   2022 GDP quartile? This helps identify outcomes that GDP alone does not explain. */

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

/* DECISION USE: Positive and negative outliers can guide follow-up questions,
   but neither result proves program effectiveness or causation. */


/* EXECUTIVE KPI SUMMARY: Return a compact 2022 snapshot for reporting or a
   future dashboard. */

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
RECOMMENDED DECISION PROCESS
1. Use the priority score to create an investigation list.
2. Review each candidate's trend and GDP-peer performance.
3. Validate the signal with current and population-aware data.
4. Add cost, local capacity, equity, and implementation risk.
5. Make funding decisions with stakeholder and subject-matter review.
==============================================================================*/
