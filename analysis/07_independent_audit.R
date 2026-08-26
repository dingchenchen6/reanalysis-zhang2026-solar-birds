# ============================================================
# Scientific question / 科学问题:
# An independent quality-control audit of the county-month diversity
# panel: (1) do the published Shannon/Simpson/richness values satisfy
# the mathematical constraints any real community must satisfy?
# (2) What does a properly specified richness model (Poisson FE with a
# birdwatcher offset — the ecologist's catch-per-unit-effort logic)
# estimate? (3) What effect sizes could the corrected design actually
# detect (MDE / power), so that "null" has quantitative meaning?
# 对县-月多样性面板的独立质控审计:(1) 已发表的 Shannon/Simpson/
# 丰富度值是否满足任何真实群落必须满足的数学约束?(2) 正确设定的
# 丰富度模型(泊松固定效应 + 观鸟人数 offset,即生态学的单位努力
# 渔获量逻辑)给出什么估计?(3) 校正后设计的最小可检测效应(MDE)
# 是多少,使"零结果"具有定量含义?
#
# QC rule set / 质控规则(逐条触发计数 = audit trail):
#   R1  H > ln(S) + tol            (数学上不可能 / mathematically impossible)
#   R2  Gini-Simpson D > 1 - exp(-H) + tol   (违反 Hill 数递减 ²D ≤ ¹D)
#   R3  S >= 2 且 H == 0           (两种以上但零熵 / >=2 species, zero entropy)
#   R4  S >= 20 且 H < 0.2         (单一天文计数签名 / single-huge-count)
#   R5  D > 1 - 1/S + tol          (超过均匀群落上限 / exceeds even-community cap)
#
# Input / 输入: DATA/Bird.dta, DATA/Richeven.dta (raw, pre-winsorize),
#               output/panel_master.rds
# Output / 输出: output/qc_audit_trail.csv, output/consistency_violations.csv,
#               output/poisson_offset.csv, output/mde_power.csv
# Main packages / 主要包: data.table, haven, fixest
# ============================================================

suppressPackageStartupMessages({
  library(data.table); library(haven); library(fixest)
})

base <- "/Users/dingchenchen/Documents/能源转型与生态保护"
dta  <- file.path(base, "original_replication/extracted/DATA")
out  <- file.path(base, "output")

## ---- 1. 原始值一致性审计 / consistency audit on RAW values ----------------
bird <- as.data.table(read_dta(file.path(dta, "Bird.dta")))
rich <- as.data.table(read_dta(file.path(dta, "Richeven.dta")))
bird[, ymkey := as.character(标准年月)]
rich[, ymkey := if (inherits(year, "Date")) format(year, "%Y-%m") else
                 sprintf("%d-%02d", 1960 + as.numeric(year) %/% 12,
                         as.numeric(year) %% 12 + 1)]
raw <- merge(bird[, .(id, ymkey, 省, 市, 县, H = ShannonBD, D = SimpsonBD)],
             rich[, .(id, ymkey, S = 丰富度)], by = c("id", "ymkey"))
tol <- 1e-6

raw[, r1 := S >= 1 & H > log(pmax(S, 1)) + tol]          # H 超丰富度上限
raw[, r2 := D > 1 - exp(-H) + tol]                        # ²D > ¹D(不可能)
raw[, r3 := S >= 2 & H <= tol]                            # 多种但零熵
raw[, r4 := S >= 20 & H < 0.2 & H > tol]                  # 超大计数签名
raw[, r5 := S >= 1 & D > 1 - 1/S + tol]                   # 超均匀上限

trail <- data.table(
  rule = c("R1: H > ln(S)  (impossible)",
           "R2: Gini-Simpson > 1 - exp(-H)  (violates 2D<=1D)",
           "R3: S>=2 with H = 0  (multi-species, zero entropy)",
           "R4: S>=20 with H < 0.2  (single-huge-count signature)",
           "R5: D > 1 - 1/S  (exceeds even-community cap)"),
  n_flagged = c(raw[r1 == TRUE, .N], raw[r2 == TRUE, .N], raw[r3 == TRUE, .N],
                raw[r4 == TRUE, .N], raw[r5 == TRUE, .N]),
  n_total = nrow(raw))
fwrite(trail, file.path(out, "qc_audit_trail.csv"))
cat("=== QC audit trail (raw county-month values, n =", nrow(raw), ") ===\n")
print(trail)

viol <- raw[r1 | r2 | r3 | r5,
            .(省, 市, 县, ymkey, S, H = round(H, 4), D = round(D, 4),
              lnS = round(log(S), 4),
              rules = paste0(fifelse(r1, "R1 ", ""), fifelse(r2, "R2 ", ""),
                             fifelse(r3, "R3 ", ""), fifelse(r5, "R5", "")))]
fwrite(viol, file.path(out, "consistency_violations.csv"))
cat(sprintf("\nHard mathematical violations (R1/R2/R3/R5): %d county-months\n",
            nrow(viol)))
print(head(viol[order(-S)], 12))

## ---- 2. 泊松 offset 丰富度模型 / Poisson FE richness with effort offset ----
m <- readRDS(file.path(out, "panel_master.rds"))
# 用原始(未缩尾)丰富度作计数因变量 / raw richness as the count outcome
m <- merge(m, raw[, .(id, ymkey, S_raw = S)], by = c("id", "ymkey"), all.x = TRUE)
CTRL <- "Temp + Wind + Pop + Carbon + Water + Green + Farm + Grass"  # 不含 Duration

pois <- list()
pois$a <- fepois(as.formula(paste("S_raw ~ PI +", CTRL, "| county + ym")),
                 m, cluster = ~county, fixef.rm = "singletons")
pois$b <- fepois(as.formula(paste("S_raw ~ PI +", CTRL, "| county + ym")),
                 m, offset = ~log(BN), cluster = ~county, fixef.rm = "singletons")
pois$c <- fepois(as.formula(paste("S_raw ~ PI +", CTRL, "| county + ym")),
                 m[PI_was_imputed == FALSE], offset = ~log(BN),
                 cluster = ~county, fixef.rm = "singletons")
pois$d <- fepois(as.formula(paste("S_raw ~ PI + logBT +", CTRL, "| county + ym")),
                 m[PI_was_imputed == FALSE], offset = ~log(BN),
                 cluster = ~county, fixef.rm = "singletons")

ptab <- data.table(
  model = c("Poisson FE, no effort (authors' logic)",
            "+ offset log(birdwatchers)  [CPUE]",
            "offset + policy-documented counties",
            "offset + ln(hours) + policy-documented"),
  beta_PI = sapply(pois, \(f) coef(f)["PI"]),
  se      = sapply(pois, \(f) se(f)["PI"]),
  p       = sapply(pois, \(f) pvalue(f)["PI"]),
  N       = sapply(pois, nobs))
sd_pi <- sd(m$PI)
ptab[, pct_per_sd := 100 * (exp(beta_PI * sd_pi) - 1)]  # 丰富度百分比效应
fwrite(ptab, file.path(out, "poisson_offset.csv"))
cat("\n=== Poisson FE richness models (CPUE logic) ===\n")
print(ptab, digits = 3)

## ---- 3. 检验力与最小可检测效应 / power & minimum detectable effect --------
# 对首选校正规格:MDE(80% power, alpha=.05) = (1.96 + 0.84) * SE
fin <- fread(file.path(out, "final_estimate.csv"))
mn_sh <- mean(m$ShannonBD)
mde <- fin[, .(outcome, se, est_pct,
               MDE_pct = fifelse(outcome == "lnRich",
                                 100 * 2.80 * se * sd_pi,
                                 100 * 2.80 * se * sd_pi /
                                   fifelse(outcome == "ShannonBD", mn_sh,
                                           mean(m$SimpsonBD))))]
# 若发表效应(-2.10% Shannon)为真,校正设计检出它的功效
beta_pub <- 0.0125
se_corr  <- fin[outcome == "ShannonBD", se]
power_pub <- pnorm(beta_pub / se_corr - 1.96)
mde[, note := ""]
mde[outcome == "ShannonBD",
    note := sprintf("power to detect the published -2.10%% if true: %.0f%%",
                    100 * power_pub)]
fwrite(mde, file.path(out, "mde_power.csv"))
cat("\n=== Minimum detectable effects of the corrected design ===\n")
print(mde, digits = 3)
