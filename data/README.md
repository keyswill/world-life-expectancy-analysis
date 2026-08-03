# Data notes

The source CSV is not republished in this repository because its original
provenance and redistribution terms were not supplied with the educational
project file.

To reproduce the analysis, import the supplied CSV into MySQL Workbench as
`WLE_raw`. The expected raw-data controls are:

| Control | Expected value |
|---|---:|
| Rows | 2,941 |
| Countries | 193 |
| Year range | 2007–2022 |
| Distinct years | 16 |
| Excess duplicate rows | 3 |
| Blank development statuses | 8 |
| Blank life-expectancy values | 2 |

The three duplicate country-year groups are Ireland 2022, Senegal 2009, and
Zimbabwe 2019. The SQL audit and validation scripts confirm these controls
before and after cleaning.

The years are analyzed exactly as supplied in the project CSV. They were not
independently corrected or relabeled.
