# Observation effort, not birds

**Live report / 在线报告**: https://dingchenchen6.github.io/reanalysis-zhang2026-solar-birds/

**观测努力,而非鸟类:对《中国光伏扩张政策降低鸟类多样性》的独立审计与重分析**

Supporting archive for a Technical Comment submitted to *Science* in response to:

> H. Zhang *et al.*, "China's solar expansion policy reduces bird diversity," *Science* **393**, 831–836 (2026). DOI: [10.1126/science.aee0747](https://doi.org/10.1126/science.aee0747)

Chenchen Ding (Peking University) · August 2026

---

## Summary

I started from the authors' public replication package, reproduced their headline estimate to the fourth decimal place (β = −0.0125, clustered SE = 0.0037, N = 46,371; the advertised −2.10% per s.d. of policy stringency), and then ran the checks I would apply to any citizen-science dataset before regression: record-level quality control, measurement-validity tests, metric justification, and effort standardization. Three findings emerged.

1. **Measurement.** The county-month Shannon index reflects the observation process more than bird communities. In the estimation sample, 38.8% of county-months rest on a single birdwatcher and the median county is observed in 11 of 120 months; observed diversity is a steep saturating function of birdwatcher numbers. A physically impossible record of 2,147,483,647 little egrets (the int32 maximum) enters the dependent variable unfiltered — my consistency rules flagged it as the only mathematically impossible county-month among 46,283 before I knew which record caused it. Species-level checks on record-level platform data I hold through a separate project show that counts equal one in 46.9% of 2014–2023 checklists (43.7% in the platform's raw 2024 delivery; the Ornithological Society reports 40.5% platform-wide).
2. **Confounding.** Birdwatcher counts grew 171-fold over 2014–2023, in step with policy stringency, while the authors' only effort control is hours per birder — a ratio that discards total effort and itself responds to policy. Adding ln(birdwatchers) to their own specification moves the coefficient to +0.0032 (P = 0.31). Treating birdwatcher numbers as a negative-control outcome, I find the association shrinks by 81% in policy-documented counties and that next-year policy "affects" current birdwatchers — a pre-trend, not a causal effect.
3. **Inference.** PSI is imputed as zero for 703 of 2,344 counties (43.9% of observations) that never appear in the policy source; restricting to documented counties gives β = −0.0027 (P = 0.49). PSI uniquely explains 0.03% of outcome variance. Across all 36 defensible specifications, every significant negative estimate arises without effort terms, and all 18 effort-adjusted paths are null. My preferred corrected estimate is +0.14% per s.d. (95% CI −0.96 to +1.24), an interval that excludes the published −2.10%; the corrected design would have detected that effect with 96% power.

None of this shows that solar development is harmless to birds. It shows that this dataset, under this design, cannot detect such an effect in either direction.

## Repository contents

```
analysis/01_assemble_replicate.R        panel assembly; exact Table 1 replication
analysis/02_corrected_models.R          effort, imputation, metric, and period corrections; R² decomposition
analysis/03_data_pathology.R            corrupted-record verification; recording-protocol simulations
analysis/04_figures.R                   Figures 1–2
analysis/05_final_pipeline.R            36-specification curve; preferred estimates; specification figure
analysis/06_negative_control.R          negative-control and mechanism tests (imputation, trends, pre-trend, nightlight)
analysis/07_independent_audit.R         consistency rules R1–R5; Poisson-offset richness models; power and MDE
analysis/08_iv_replication.R            first-stage and 2SLS replication of the instrument
analysis/09_fig4_birding_anatomy.R      structure of the birdwatching data (four-panel figure)
analysis/10_species_level_validation.R  record-level verification: all-ones share, extreme counts, test-retest
analysis/11_raw_platform_validation.R   semantic and share checks on the platform's raw provincial delivery
output/                                 derived tables; the direct source of every number quoted
figures/                                figures as PDF and 600-dpi PNG
comment/                                Technical Comment, English and Chinese versions
submission/                             submission package: manuscript, supplementary materials, cover letter (DOCX and PDF)
独立审计报告_*.md                        full audit report (Chinese)
附录_*.md                               appendix: adjudication of public critiques and submission notes
index.html                              self-contained interactive summary (figures embedded)
```

## Reproducing

Original inputs are not redistributed here. Obtain the authors' replication package first:

```bash
git clone https://github.com/jianke22/China-s-solar-expansion-policy-reduces-bird-diversity original_replication
cd original_replication && unar -o extracted DATA.rar
```

Then run the scripts in order (R ≥ 4.5; fixest, data.table, haven, ggplot2, patchwork, scales, readxl). Scripts 01–09 use only the public package; scripts 10–11 additionally require record-level platform data held under a data agreement and report aggregated outputs only. Every number in the Comment, the report, and the web page is written to `output/*.csv` by these scripts.

## Related public critiques

I checked my results against, and in several places quantified, the public critiques by the China Ornithological Society ([statement](https://mp.weixin.qq.com/s/cDlMUCQXkIHZZ_sBBRdDTw)), Jiangshan Lai ([R² decomposition](https://mp.weixin.qq.com/s/Ojlk0ZzHmNv6CXf5Sm-gdQ)), Jiachao Peng ([causal-inference standards](https://mp.weixin.qq.com/s/CQ0Wv8xXrYpAnW9TwvLqsw)), and "Ersha" ([R² presentation](https://mp.weixin.qq.com/s/ibJI08lYmrj1dLDeiaameQ)). My own additions are the measurement-validity layer (consistency rules, saturation curves, the evenness signature, recording-protocol simulations), the species-level verification on record-level data, the negative-control and pre-trend tests, the 36-specification synthesis, and the power analysis.

## License

Code: MIT. Text and figures: CC BY 4.0. Original data remain under the terms of their sources.
