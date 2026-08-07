# Business Understanding

**Status: Complete**

This document defines the resource-prioritization problem, intended users, success measures, and boundaries for interpreting the country-level health data.

## Business Context

A global health organization has limited analytical and program resources. It needs a transparent way to identify countries that may warrant deeper review, distinguish improvement from decline, and compare health outcomes with socioeconomic context.

## Main Business Question

> Which countries demonstrate the greatest health-outcome needs or improvement opportunities based on life expectancy, mortality, immunization, education, and economic indicators?

## Business Problem

Ranking countries on life expectancy alone can hide the factors associated with an outcome and can penalize countries without considering their economic peers. The organization needs a reproducible screening process that combines multiple indicators while keeping the final funding decision in human hands.

## Stakeholders

| Stakeholder | Decision supported |
|---|---|
| Global health program director | Prioritize countries for second-stage investigation |
| Monitoring and evaluation team | Track improvement, decline, and indicator gaps |
| Program and policy analysts | Compare outcomes with health, education, and economic context |
| Executive leadership | Allocate analytical attention and request further evidence |
| Country partners | Add local context before an intervention is designed |

## Business Objectives

1. Measure change in life expectancy across the available period.
2. Identify countries with the largest gains and declines.
3. Compare developed and developing country outcomes.
4. Quantify associations between life expectancy and mortality, immunization, education, and GDP indicators.
5. Compare countries with GDP peers.
6. Build a transparent multi-indicator priority list for deeper review.

## Success Metrics

| Metric | Definition | Decision supported |
|---|---|---|
| Life-expectancy change | Last observed value minus first observed value | Identify improvement and decline |
| Development-status gap | Difference in average life expectancy by status | Monitor broad disparity |
| Indicator correlation | Pearson relationship with life expectancy | Identify variables associated with outcomes |
| GDP peer difference | Country result compared with its economic peer group | Find outcomes GDP alone may not explain |
| Priority score | Equal-weight percentile screening across six indicators | Create a review queue |

## Business Questions

1. How did average country life expectancy change over time?
2. Which countries improved or declined the most?
3. How large is the developed/developing gap?
4. Which available indicators have the strongest relationships with life expectancy?
5. Which countries perform above or below GDP peers?
6. Which countries combine several adverse indicators and should be reviewed first?

## Assumptions

- Country-year labels and indicator definitions are used as supplied by the educational dataset.
- Country averages are unweighted because population is unavailable.
- The priority score is a screening device rather than an allocation formula.
- Two internal missing life-expectancy values may be estimated using adjacent years and must remain flagged.

## Risks and Limitations

| Limitation | Effect on the analysis | Treatment |
|---|---|---|
| Population unavailable | Large and small countries receive equal weight | Disclose unweighted averages |
| Dataset is not current operational intelligence | Results may not reflect present conditions | Limit claims to the supplied period |
| Indicator definitions are not fully sourced | Units may be uncertain | Require authoritative verification before policy use |
| Correlation is observational | Relationships do not prove causes | Avoid causal recommendations |
| Equal-weight priority score | Weight choices affect rankings | Use only for second-stage review |
| Local capacity and intervention cost unavailable | Feasibility cannot be assessed | Add local evidence before allocation |

## Main Limitation

> The analysis can prioritize where to investigate, but it cannot determine what intervention should be funded without current, population-weighted, locally validated evidence.

## Related Documentation

- [Data dictionary](WLE_data_dictionary.md)
- [Data Understanding](data_understanding.md)
