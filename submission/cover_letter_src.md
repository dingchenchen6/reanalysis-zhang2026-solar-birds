# Cover Letter

Dr. Chenchen Ding
School of Life Sciences and Institute of Ecology
Peking University, Beijing 100871, China
dingchenchen@pku.edu.cn

26 August 2026

Dear Editors,

Please consider the enclosed Technical Comment on "China's solar expansion policy reduces bird diversity" by H. Zhang *et al*. (*Science* **393**, 831–836, 21 August 2026).

Working entirely from the authors' public replication package, I first reproduce their preferred estimate exactly and then show that the finding does not withstand scrutiny on three independent grounds:

1. **Measurement.** The county-month Shannon index tracks the observation process rather than bird communities: observed diversity is a steep species-accumulation function of birdwatcher numbers, 38.8% of county-months rest on a single observer, and a physically impossible record of 2,147,483,647 egrets (the 32-bit integer maximum) enters the published outcome variable unfiltered. In record-level platform data held by my group, nearly half of all checklists carry no abundance information.

2. **Confounding.** Birdwatcher numbers grew 171-fold over the study period, in step with policy stringency. The authors' only effort control is hours per birder, itself a post-treatment variable. Adding a standard total-effort term to their own specification eliminates the effect; treating birdwatcher numbers as a negative-control outcome reveals that even next-year policy "affects" current birdwatchers, a causally impossible pattern indicating differential county trends.

3. **Inference.** PSI is imputed as zero for 43.9% of observations absent from the policy source; restricting to documented counties nullifies the estimate. Across all 36 defensible specifications, every significant negative estimate arises without effort terms, and the corrected design would have detected the published effect with 96% power, yet detects nothing.

Beyond this single article, the concern I wish to flag is methodological. Citizen-science records reflect a state process filtered through an observation process, with taxonomic, temporal, and spatial detection biases; when that observation process is left unmodelled, and when record-level defects (counts without abundance information, physically impossible entries) pass unscreened into a national-scale dependent variable, panel regressions will keep producing statistically significant but spurious "policy effects". That the headline estimate here reverses under one standard effort term, and that even future policy "affects" current birdwatcher numbers in the same design, illustrates how far such biases can carry a conclusion. A prompt correction also matters in practice: the article's desert-subgroup null is already being cited as support for concentrating gigawatt-scale development in arid lands, precisely where citizen-science coverage is thinnest.

All analysis scripts, derived tables, and the record-level birdwatching dataset used for species-level verification are openly available at github.com/dingchenchen6/reanalysis-zhang2026-solar-birds (data in the repository's releases); the remaining inputs are the authors' own public replication package. I have no competing interests and no prior collaboration or dispute with the authors. Suggested reviewers with relevant expertise include specialists in citizen-science methodology, biodiversity metrics, and panel econometrics; I am happy to provide names on request.

Thank you for your consideration.

Sincerely,

Chenchen Ding
