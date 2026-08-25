# Birdwatchers, not birds — reanalysis of Zhang et al. (2026), *Science* 393:831–836

**观鸟者,而非鸟:对《中国光伏扩张政策降低鸟类多样性》的精确复现、三层批判与 36 规格重分析**

Supporting archive for a Technical Comment submitted to *Science* in response to:

> H. Zhang *et al.*, "China's solar expansion policy reduces bird diversity," *Science* **393**, 831–836 (2026). DOI: [10.1126/science.aee0747](https://doi.org/10.1126/science.aee0747)

Author: Chenchen Ding (Peking University) · 2026-08

---

## TL;DR

Starting from the authors' own public replication package, we reproduce their headline estimate **exactly** (β = −0.0125, clustered SE = 0.0037, N = 46,371; the advertised −2.10% per s.d. of policy stringency) — and then show it does not survive scrutiny at any of three levels:

1. **Measurement.** The county-month Shannon index measures the observation process, not bird communities: 38.8% of county-months come from a single birdwatcher; median county coverage is 11 of 120 months; observed diversity is a steep saturating function of birdwatcher numbers; and a physically impossible record of **2,147,483,647 little egrets** (the int32 maximum) enters the regression's dependent variable unfiltered (Xinhui County, 2015-03, H = 8×10⁻⁷), with 18 further county-months showing the same corruption signature.
2. **Confounding.** Birdwatcher counts grew **171-fold** over 2014–2023, in step with policy stringency. The authors' only effort control (hours *per birder*) discards total effort and is itself a post-treatment variable. PSI strongly predicts birdwatcher numbers (P = 2×10⁻¹¹). Adding ln(birdwatchers) to the authors' own specification flips the coefficient to **+0.0032 (P = 0.31)**.
3. **Inference.** 703 of 2,344 counties (43.9% of observations) never appear in the policy source and are imputed PSI = 0; restricting to documented counties gives β = −0.0027 (P = 0.49). PSI uniquely explains **0.03%** of outcome variance.

**Final corrected estimate** (corrupted rows removed, policy-documented counties, explicit effort terms): Shannon **+0.14% per s.d.** (95% CI −0.96 to +1.24) — an interval that **excludes the published −2.10%**. Across a fully crossed grid of 36 defensible specifications, all 7 significant negatives lack effort terms; **all 18 effort-adjusted paths are null**.

This does **not** show solar development is harmless to birds. It shows this dataset, under this design, cannot detect such an effect in either direction.

## Repository contents

```
analysis/01_assemble_replicate.R   panel assembly + exact Table 1 replication
analysis/02_corrected_models.R     effort / imputation / metric / era corrections; R² decomposition
analysis/03_data_pathology.R       corrupted-record verification + checklist/flock simulations
analysis/04_figures.R              Figures 1–2 (publication grade)
analysis/05_final_pipeline.R       36-specification curve + preferred estimates + Figure 3
output/                            derived tables — the direct source of every number quoted
figures/                           Fig1–Fig3 (PDF + 600-dpi PNG)
comment/Technical_Comment_EN.md    submission text (≈969 words, 2 figures + fig. S1, 12 refs)
comment/Technical_Comment_CN.md    Chinese parallel version + number-audit table
深度评估报告_*.md                   full Chinese assessment report (expert + editor perspective)
index.html                         self-contained interactive summary (figures embedded)
```

## Reproducing

Inputs are **not redistributed** here. Obtain the original replication package:

```bash
git clone https://github.com/jianke22/China-s-solar-expansion-policy-reduces-bird-diversity original_replication
cd original_replication && unar -o extracted DATA.rar
```

Then run the scripts in order (R ≥ 4.5, packages: `fixest`, `data.table`, `haven`, `ggplot2`, `patchwork`, `scales`):

```bash
Rscript analysis/01_assemble_replicate.R
Rscript analysis/02_corrected_models.R
Rscript analysis/03_data_pathology.R
Rscript analysis/04_figures.R
Rscript analysis/05_final_pipeline.R
```

Every number in the Comment and the report is written to `output/*.csv` by these scripts.

## Related public critiques

- China Ornithological Society statement on data characteristics and applicability (2026) — [WeChat](https://mp.weixin.qq.com/s/cDlMUCQXkIHZZ_sBBRdDTw)
- Jiangshan Lai on R² decomposition and effect size — [WeChat](https://mp.weixin.qq.com/s/Ojlk0ZzHmNv6CXf5Sm-gdQ)
- Jiachao Peng on causal-inference standards — [WeChat](https://mp.weixin.qq.com/s/CQ0Wv8xXrYpAnW9TwvLqsw)
- "Ersha" on the misleading R² presentation — [WeChat](https://mp.weixin.qq.com/s/ibJI08lYmrj1dLDeiaameQ)
- H. Song, independent econometric audit — [figshare 10.6084/m9.figshare.33328569](https://doi.org/10.6084/m9.figshare.33328569)

Our contribution is complementary: the **measurement-validity layer** (saturation curves, evenness signature, corruption entering the dependent variable, checklist-type simulations), the ecological interpretation, and the systematic 36-specification "what do the data actually support" answer.

## License

Code: MIT. Text and figures: CC BY 4.0. Original data remain under the terms of the source repository.
