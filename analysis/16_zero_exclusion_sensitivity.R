# ============================================================
# Scientific question / 科学问题:
# Does excluding PSI = 0 and ShannonBD = 0 county-months change the
# conclusion, and is such exclusion statistically defensible?
# 剔除 PSI = 0 与 ShannonBD = 0 的县-月是否改变结论?这种剔除在统计上
# 是否站得住?
#
# Objective / 分析目标:
# The two kinds of "zero" differ in nature. PSI = 0 mixes (a) zeros
# imputed for counties absent from the policy source (missing values,
# not zeros) with (b) true zeros in documented counties (pre-policy
# baselines and never-treated controls). ShannonBD = 0 is almost
# entirely S = 1 (one species recorded), i.e. a minimum-effort county-
# month. We estimate the authors' specification and the effort-adjusted
# specification under each exclusion rule, and test whether dropping
# ShannonBD = 0 is selection on an outcome that the treatment predicts.
# 两种"零"性质不同:PSI = 0 混合了"填补零"(缺失值)与"真零"(处理前
# 基线与从未处理的对照);ShannonBD = 0 几乎全是 S = 1 的最低努力县-月。
# 在每种剔除规则下估计作者规格与努力校正规格,并检验剔除 ShannonBD = 0
# 是否构成"对受处理影响的结果变量进行选择"。
#
# Input / 输入: output/panel_master.rds (rebuilt by script 01)
# Output / 输出: output/zero_exclusion_sensitivity.csv,
#                output/zero_outcome_selection.csv
# Key assumptions / 关键假设: same fixed effects, controls, clustering
#   and singleton handling as the authors (county + year-month FE,
#   county-clustered SE). 与作者一致的固定效应、控制变量与聚类。
# Main packages / 主要包: data.table, fixest
# Output directory / 输出路径: output/
# ============================================================

suppressPackageStartupMessages({ library(data.table); library(fixest) })

# 从仓库根目录运行本脚本 / run this script from the repository root:
#   Rscript analysis/16_zero_exclusion_sensitivity.R
base <- "."
out  <- file.path(base, "output")
m    <- readRDS(file.path(out, "panel_master.rds"))

CTRL <- "Temp + Wind + Pop + Duration + Carbon + Water + Green + Farm + Grass"
sd_pi <- sd(m$PI); mn_h <- mean(m$ShannonBD)      # 与头条换算口径一致 / headline scaling

## ---- 1. 剔除规则 / exclusion rules -------------------------------------
# 每条规则返回一个逻辑向量:TRUE = 保留 / each rule returns rows to KEEP
rules <- list(
  "A. As published (no exclusion)"                     = quote(rep(TRUE, .N)),
  "B. Drop imputed PSI zeros only (policy-source)"     = quote(PI_was_imputed == FALSE),
  "C. Drop all PSI = 0 (imputed + true zeros)"         = quote(PI != 0),
  "D. Drop ShannonBD = 0"                              = quote(ShannonBD != 0),
  "E. Drop all PSI = 0 and ShannonBD = 0"              = quote(PI != 0 & ShannonBD != 0),
  "F. Drop imputed PSI zeros and ShannonBD = 0"        = quote(PI_was_imputed == FALSE & ShannonBD != 0)
)

## ---- 2. 估计 / estimate both specifications under each rule --------------
run1 <- function(dat, rhs) {
  f <- feols(as.formula(paste("ShannonBD ~", rhs, "| county + ym")),
             dat, cluster = ~county, fixef.rm = "singletons")
  list(b = coef(f)["PI"], se = se(f)["PI"], p = pvalue(f)["PI"], n = nobs(f),
       k = length(unique(dat[obs(f), county])))
}

res <- rbindlist(lapply(names(rules), function(r) {
  d <- m[eval(rules[[r]])]
  # 剔除后 PSI 的县内变异是否还够 / remaining within-county PSI variation
  wsd <- d[, .(v = sd(PI)), by = county][, mean(v > 0, na.rm = TRUE)]
  a <- run1(d, paste("PI +", CTRL))                         # 作者规格 / authors
  e <- run1(d, paste("PI + logBN + logBT +", CTRL))         # 努力校正 / effort-adjusted
  data.table(rule = r, N = a$n, counties = a$k,
             share_counties_with_PSI_variation = round(wsd, 3),
             authors_pct = 100 * a$b * sd_pi / mn_h, authors_p = a$p,
             effort_pct  = 100 * e$b * sd_pi / mn_h, effort_p  = e$p,
             # 95% 置信区间(每 SD PSI 的效应,% of mean H)/ 95% CI on the same scale
             effort_lo = 100 * (e$b - 1.96 * e$se) * sd_pi / mn_h,
             effort_hi = 100 * (e$b + 1.96 * e$se) * sd_pi / mn_h,
             # 区间是否排除已发表的 -2.10% / does the CI exclude the published effect?
             excludes_published = (100 * (e$b - 1.96 * e$se) * sd_pi / mn_h) > -2.10)
}))
fwrite(res, file.path(out, "zero_exclusion_sensitivity.csv"))
cat("=== Sensitivity to excluding zeros (effect of 1 s.d. PSI, % of mean H) ===\n")
print(res, digits = 3)

## ---- 3. 按因变量剔除是否构成选择? / is dropping H = 0 outcome selection? --
# 若 PSI 预测"该县-月为 H = 0"的概率,则剔除 H = 0 即对处理影响的结果做选择,
# 会使系数有偏。线性概率模型,同样的固定效应与聚类。
# If PSI predicts Pr(H = 0), dropping those rows selects on a treatment-
# affected outcome and biases the coefficient. Linear probability model.
m[, H0 := as.integer(ShannonBD == 0)]
sel <- rbindlist(list(
  { f <- feols(as.formula(paste("H0 ~ PI +", CTRL, "| county + ym")), m,
               cluster = ~county, fixef.rm = "singletons")
    data.table(model = "Pr(H = 0) ~ PSI, authors' controls",
               beta = coef(f)["PI"], se = se(f)["PI"], p = pvalue(f)["PI"], N = nobs(f)) },
  { f <- feols(H0 ~ logBN | county + ym, m, cluster = ~county, fixef.rm = "singletons")
    data.table(model = "Pr(H = 0) ~ ln(birdwatchers)",
               beta = coef(f)["logBN"], se = se(f)["logBN"], p = pvalue(f)["logBN"], N = nobs(f)) }
))
fwrite(sel, file.path(out, "zero_outcome_selection.csv"))
cat("\n=== Does treatment or effort predict the excluded outcome value? ===\n")
print(sel, digits = 3)
