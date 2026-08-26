# Technical Comment — submitted to *Science*

**Comment on "China's solar expansion policy reduces bird diversity"**

Chenchen Ding^1\*

^1 School of Life Sciences / Institute of Ecology, Peking University, Beijing 100871, China.
\*Corresponding author. Email: dingchenchen@pku.edu.cn (placeholder — replace with preferred address)

*Target article*: H. Zhang *et al*., *Science* **393**, 831–836 (2026). DOI: 10.1126/science.aee0747

---

## Abstract (49 words)

Zhang *et al*. (Research Articles, 21 August 2026) report that solar-policy stringency reduced county-level bird diversity across China. Reanalyzing their public replication data, we show their outcome variable tracks birdwatching effort rather than bird communities; correcting effort, data contamination, and unvalidated policy zeros eliminates the reported effect entirely.

---

## Main text (999 words)

Zhang *et al*. (*1*) link a photovoltaic policy-stringency index (PSI) to citizen-science bird records aggregated to county-months and conclude that a one-standard-deviation policy increase reduced Shannon diversity by 2.10%. The finding, accompanied by a Perspective (*2*), has been widely reported as evidence that solar expansion harms birds. Using the authors' public replication package, we reproduce their preferred estimate exactly (β = −0.0125, clustered SE = 0.0037, *n* = 46,371). The reproduction, however, exposes problems of measurement, confounding, and inference, each of which independently undermines the conclusion.

**The outcome variable measures the observation process.** Citizen-science records reflect a state process (where species occur, in what numbers) filtered through an observation process (who looks, where, when): taxonomic, temporal, and spatial detection biases mean raw records cannot be read as true occupancy or abundance (*4*, *7*). The dependent variable here is a Shannon index computed from unstructured birdwatching reports within each county-month. In the estimation sample, 38.8% of county-months rest on a single birdwatcher and the median county is observed in 11 of 120 months (Fig. 1C). Observed richness and Shannon diversity are saturating functions of the number of birdwatchers present (Fig. 1B): county-months with one birder average 15 species (H = 1.90); those with >100 birders average 142 species (H = 3.60). This is a species-accumulation curve, not a community property. The authors' own results carry its signature: PSI associates with lower observed richness but higher evenness (their table S19), the mechanical signature of shorter lists; in our reproduction, evenness declines monotonically with effort (0.84 at one birder; 0.73 above 100).

The input data are also unvalidated. In record-level platform data held by our own project, every count equals one in 46,997 of 100,313 checklists from 2014–2023 (46.9%; 43.7% in the platform's raw 2024 delivery, whose count field we verified). These checklist-type records carry no abundance information: treating every species as one individual inflates rare species' weight, suppresses true dominants, and drives the Shannon index toward log richness, so nearly half of the raw material measures list length, not community structure. Corrupted counts also reach the published analysis directly: the Shannon value for Xinhui County in March 2015 is 8 × 10⁻⁷ with four species recorded, against 2.2–2.9 in adjacent months; arithmetically, such a value requires a single species count of at least tens of millions. This entry enters the regression as a dependent-variable observation (Fig. 1D). Eighteen more county-months share this signature (≥20 species, H < 0.2). No data-quality screening is described in (*1*).

**Birdwatching effort is confounded with the treatment.** Summed birdwatcher counts grew 171-fold over 2014–2023 and observed county-months 25-fold, as mean PSI quadrupled (Fig. 1A). The authors control only for `Duration`, the logarithm of birdwatching hours per birder, a ratio that discards the explosive growth in total effort. `Duration` is itself a post-treatment variable, responding to PSI (β = −0.0177, *P* < 10⁻⁴); conditioning on it is a classic "bad control" (*3*). Birdwatcher numbers serve as a negative-control outcome: PSI "reduces" birdwatchers (β = −0.041, *P* = 2 × 10⁻¹¹). The association shrinks by 81% within policy-documented counties (β = −0.008, *P* = 0.17); next-year PSI "affects" current birdwatchers conditional on current PSI (β = −0.045, *P* < 10⁻⁵), a causally impossible direction indicating differential county trends; and PSI does not predict realized PV area within counties (*P* = 0.27), weakening any construction-disturbance pathway. A design in which future policy shifts a non-ecological outcome can generate spurious effects for any outcome, including birds.

The remedy is standard: model the observation process explicitly (*4*–*7*). In the authors' own specification (same data, fixed effects, clustering), adding ln(birdwatchers) flips the PSI coefficient to +0.0032 (*P* = 0.31); ln(total hours) or both terms give the same null (Fig. 2A). The richness decline of −0.98 species per PSI unit (their table S19) shrinks by 92% to −0.07 (*P* = 0.37), and the corrected effect within the 2020–2023 boom is +0.0002 (*P* = 0.96).

**The estimate is fragile and, at face value, negligible.** The policy variable is equally problematic: 703 of 2,344 sample counties (43.9% of observations) never appear in the policy-text source, and their PSI is imputed as zero although the source distinguishes true zeros. Restricting to policy-documented counties yields β = −0.0027 (*P* = 0.49). Even taken at face value, PSI adds 0.0003 to the model's R², or 0.03% of Shannon variance, against 31% absorbed by fixed effects (Fig. 2B); a one-standard-deviation shift (0.052 on H) is 6.5% of the residual standard deviation (0.80). A statistically significant coefficient of this size, estimated from a contaminated, effort-driven outcome, carries little ecological information (*8*, *9*).

To establish what the data support, we estimated all 36 combinations of sample (full or policy-documented), cleaning (as published, corrupted rows removed, or ≥2 birders), metric (Shannon, Simpson, log richness), and effort adjustment (fig. S1). All seven significant negative estimates come from paths without effort terms; all 18 effort-adjusted paths are null (median +0.10%). Our preferred estimate (corrupted records removed, policy-documented counties, explicit effort terms) is +0.14% for Shannon diversity (95% CI, −0.96 to +1.24%), an interval that excludes the published −2.10%. Had that effect been real, this corrected design would have detected it with 96% power.

**Implications.** Our reanalysis does not show that photovoltaic development is harmless; ground-mounted solar can displace habitat and warrants rigorous impact studies. It shows that this dataset, under this design, cannot detect such an effect in either direction. The subgroup results (no significant effect in desert counties) are already being read as support for concentrating gigawatt-scale development in arid lands, yet deserts are where citizen-science coverage is sparsest; absence of evidence is not evidence of absence. Birdwatching records can support diversity inference under explicit conditions: effort-standardized richness, a presence-based quantity, is defensible with coverage-based rarefaction, list-length corrections, or occupancy models (*4*–*7*, *9*, *10*); abundance-weighted indices additionally require complete checklists and validated counts. None of these conditions is met here. The broader caution stands: data defects and fitness for purpose must be established before citizen-science records anchor national-scale causal claims.

---

## Figures

![Figure 1](../figures/Fig1_observation_process.png)

**Fig. 1. The dependent variable of Zhang *et al*. measures the observation process, not bird communities.**
(**A**) Within the authors' estimation sample, summed birdwatcher counts (red) grew 171-fold during 2014–2023 and observed county-months (orange) 25-fold, while mean policy stringency (blue) quadrupled; mean observed Shannon H (green) rose accordingly. All series indexed to 2014 = 1, log scale. (**B**) Observed Shannon H (green, left axis; mean ± s.d.) and species richness (blue, right axis) against the number of birdwatchers per county-month: a species-accumulation curve. 38.8% of county-months derive from a single birder. (**C**) Distribution of the number of months (of 120) in which each county has any birdwatching record; median 11. (**D**) Monthly Shannon H for Xinhui County, Guangdong: a corrupted entry collapses March 2015 to H = 8 × 10⁻⁷ with four species recorded (adjacent months, 2.2–2.9), a value that arithmetically requires a single species count of at least tens of millions; it enters the regression unfiltered. Eighteen further county-months show ≥20 species yet H < 0.2.

![Figure S1](../figures/Fig3_specification_curve.png)

**Fig. S1 (supplementary). Specification curve across 36 defensible analysis paths.**
Estimates of the PSI effect (as % of outcome mean per 1 s.d., 95% CIs) for the full cross of sample (all counties vs. policy-documented counties), cleaning (as published; corrupted county-months removed; ≥2 birders), outcome metric (Shannon, Simpson, log richness), and effort adjustment (authors' `Duration` only vs. explicit total-effort terms), ordered by estimate; the lower panel indicates each path's decisions. All seven significant negative estimates (orange) arise without effort terms; all 18 effort-adjusted paths are null. The open circle marks the published specification.

![Figure 2](../figures/Fig2_effect_fragility.png)

**Fig. 2. The reported policy effect vanishes under correction and is negligible in magnitude.**
(**A**) Effect of a one-standard-deviation PSI increase, expressed as % of the outcome mean with 95% CIs, under the authors' exact specification and minimal corrections (identical data, county and year-month fixed effects, county-clustered SEs). Adding total-effort terms, restricting to counties documented in the policy source, or splitting by period eliminates the effect; the richness outcome (triangles) shrinks 92% under effort control. Red dotted line: the headline −2.10%. (**B**) Variance ledger for county-month Shannon H: county and year-month fixed effects absorb 31.0%, the nine controls 2.7%, and PSI — the headline variable — 0.03%, with 66.3% unexplained.

---

## References

1. H. Zhang, A. Zhang, K. Wu, Y. Cai, S. Li, S. Wang, Y. Qiu, S. Huang, T. T. A. Phan, China's solar expansion policy reduces bird diversity. *Science* **393**, 831–836 (2026). doi:10.1126/science.aee0747
2. Y. Liang, Beyond carbon in renewable energy policy. *Science* **393**, 758–759 (2026).
3. C. Cinelli, A. Forney, J. Pearl, A crash course in good and bad controls. *Sociol. Methods Res.* **53**, 1071–1104 (2024).
4. A. Johnston, W. M. Hochachka, M. E. Strimas-Mackey, V. Ruiz Gutierrez, O. J. Robinson, E. T. Miller, T. Auer, S. T. Kelling, D. Fink, Analytical guidelines to increase the value of community science data. *Divers. Distrib.* **27**, 1265–1277 (2021).
5. S. Kelling, A. Johnston, A. Bonn, D. Fink, V. Ruiz-Gutierrez, R. Bonney, M. Fernandez, W. M. Hochachka, R. Julliard, R. Kraemer, R. Guralnick, Using semistructured surveys to improve citizen science data for monitoring biodiversity. *BioScience* **69**, 170–179 (2019).
6. N. J. B. Isaac, A. J. van Strien, T. A. August, M. P. de Zeeuw, D. B. Roy, Statistics for citizen science: extracting signals of change from noisy ecological data. *Methods Ecol. Evol.* **5**, 1052–1060 (2014).
7. D. I. MacKenzie, J. D. Nichols, G. B. Lachman, S. Droege, J. A. Royle, C. A. Langtimm, Estimating site occupancy rates when detection probabilities are less than one. *Ecology* **83**, 2248–2255 (2002).
8. L. Jost, Entropy and diversity. *Oikos* **113**, 363–375 (2006).
9. A. Chao, N. J. Gotelli, T. C. Hsieh, E. L. Sander, K. H. Ma, R. K. Colwell, A. M. Ellison, Rarefaction and extrapolation with Hill numbers: a framework for sampling and estimation in species diversity studies. *Ecol. Monogr.* **84**, 45–67 (2014).
10. J. K. Szabo, P. A. Vesk, P. W. J. Baxter, H. P. Possingham, Regional avian species declines estimated from volunteer-collected long-term data using List Length Analysis. *Ecol. Appl.* **20**, 2157–2169 (2010).

---

## Data and code availability

All analyses use the authors' public replication package (github.com/jianke22/China-s-solar-expansion-policy-reduces-bird-diversity). R scripts and derived tables reproducing every number and figure in this Comment are available to the editors and reviewers on request and will be archived publicly with a DOI upon acceptance.

## Competing interests

The author declares no competing interests.

---

*Notes for submission (not part of the manuscript):*
- *Word count of main text: ~997 (Science limit ~1,000); abstract 49 (<50).*
- *Publication date of the target article assumed 21 August 2026 (vol. 393, issue 6813) — verify against the journal PDF before submission; the 3-month Technical Comment window runs to ~21 November 2026.*
- *Affiliation and email are placeholders — confirm before submission.*
- *Reference 3 cites the Ornithological Society's public statement; if the Society issues a formal journal version, update accordingly.*
