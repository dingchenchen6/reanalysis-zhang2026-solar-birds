# Analysis-ready county-month panel / 分析用县-月面板

`panel_county_month_cleaned.csv.gz` is the county-month panel used throughout the Comment, with the cleaning scheme of the Comment encoded as flags. It has 46,528 rows and 39 columns, UTF-8 encoded.

## Provenance

The panel is rebuilt from the public replication package of Zhang *et al*. (2026, *Science* 393:831–836; github.com/jianke22/China-s-solar-expansion-policy-reduces-bird-diversity) by `analysis/01_assemble_replicate.R`, which follows the authors' merge order, variable construction, complete-case rule, and 1%/99% winsorization. It is exported by `analysis/17_export_cleaned_panel.R`. It contains only county-month aggregates already present in the authors' package and variables derived from them. It contains no record-level birdwatching data, observer identities, or coordinates.

## Verification

Script 17 reads the exported file back and re-estimates both headline numbers from it:

| Specification | Rows used | Result |
|---|---|---|
| Authors' Table 1, column 3 | `in_estimation_sample == TRUE` | β = −0.0125, *n* = 46,371 |
| Preferred corrected estimate | `in_preferred_sample == TRUE` | +0.14% per s.d. of PSI (95% CI −0.96 to +1.24), *n* = 25,996 |

```r
library(data.table); library(fixest)
d <- fread("data/panel_county_month_cleaned.csv.gz")
ctrl <- "Temp + Wind + Pop + Duration + Carbon + Water + Green + Farm + Grass"

# Authors' specification
feols(as.formula(paste("ShannonBD ~ PI +", ctrl, "| county + ym")),
      d[in_estimation_sample == TRUE], cluster = ~county)

# Preferred corrected specification: policy-documented counties,
# 19 corrupted county-months removed, explicit total-effort terms
feols(as.formula(paste("ShannonBD ~ PI + logBN + logBT +", ctrl, "| county + ym")),
      d[in_preferred_sample == TRUE], cluster = ~county)
```

Effects in the Comment are expressed per standard deviation of PSI as a percentage of mean Shannon diversity: 100 × β × 4.116 / 2.446, where 4.116 and 2.446 are sd(`PI`) and mean(`ShannonBD`) over all 46,528 rows.

## Cleaning flags

| Column | Meaning |
|---|---|
| `in_estimation_sample` | Rows entering the authors' specification after singleton removal (46,371) |
| `in_preferred_sample` | Rows entering the preferred corrected specification (25,996) |
| `PI_was_imputed` | `TRUE` if the county never appears in the policy-text source; the authors set its PSI to zero |
| `PSI_zero_type` | `imputed_zero` (missing policy data set to zero), `true_zero` (county documented, no policy that year), or `positive`. In the estimation sample: 20,364, 7,098, and 18,909 rows |
| `flag_corrupted` | 19 county-months with S ≥ 20 and H < 0.2, or S ≥ 2 and H < 10⁻³; includes Xinhui County, March 2015 |
| `flag_H0` | `ShannonBD == 0`, almost always a county-month with a single species recorded |

Imputed zeros are missing values and are excluded from the preferred sample. True zeros are kept. They come from 196 counties that never have a policy year in the sample and from 526 counties that have both policy and no-policy years (393 switch from none to some; 133 alternate). These rows supply the within-county contrasts that two-way fixed effects rely on. `analysis/16_zero_exclusion_sensitivity.R` reports the estimates under six alternative exclusion rules.

## Variables

| Group | Columns | Notes |
|---|---|---|
| Identifiers | `row_id`, `id`, `county`, `省`, `市`, `县`, `YEAR`, `month`, `ymkey`, `ym`, `year`, `标准年月` | `id` is the county code; `county` and `ym` are the fixed-effect groups; `year` is the Stata monthly date |
| Outcomes | `ShannonBD`, `SimpsonBD`, `Richness` | Winsorized at 1%/99% |
| Treatment | `PI` | The policy-stringency index (PSI); winsorized at 1%/99% |
| Effort | `BN`, `BT`, `BTN_ratio`, `Duration`, `logBN`, `logBT` | `BN` birdwatchers, `BT` total hours, `BTN_ratio` = BT/BN, `Duration` = ln(BT/BN + 1) and winsorized, `logBN` = ln(BN), `logBT` = ln(BT + 1) |
| Controls | `Temp`, `Wind`, `Pop`, `Carbon`, `Water`, `Green`, `Farm`, `Grass` | `Pop` = ln(`PD`), `Carbon` = ln(`CO2`); all winsorized at 1%/99% |
| Raw covariates | `PD`, `CO2`, `PM25` | Not winsorized; not used in the models |

## Terms of use

The values derive from the replication package of Zhang *et al*. (2026) and remain under the terms of that source. If you use this panel, please cite Zhang *et al*. (2026) and this repository (see `CITATION.cff`).

## 中文说明

本文件是评论全文所用的县-月面板,由 Zhang 等(2026)公开复现包重建,清洗方案以标记列给出,不含任何记录级观鸟数据。按 `in_estimation_sample` 取子集可复现作者原估计,按 `in_preferred_sample` 取子集可复现首选校正估计,两者均已由脚本 17 从导出文件回读验证。PSI 的填补零是缺失值,已从首选样本中剔除;真零保留:它们来自 196 个样本期内始终无政策的县,以及 526 个有政策年份与无政策年份并存的县(393 个由无到有,133 个有无交替),是双向固定效应识别所依赖的县内对比。结局变量、PSI 与控制变量按作者流程做了 1%/99% 缩尾,观鸟人数与时长为原值。
