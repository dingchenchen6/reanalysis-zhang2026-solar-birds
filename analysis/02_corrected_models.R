# ============================================================
# Scientific question / 科学问题:
# Does the negative PSI-Shannon association survive (a) explicit control
# of total birdwatching effort, (b) restriction to counties actually
# covered by the policy source, (c) alternative diversity outcomes, and
# (d) split-period estimation? What do effort-as-outcome models reveal
# about the data-generating process?
# 在 (a) 显式控制总观鸟努力、(b) 限制到政策文件实际覆盖的县、
# (c) 替换多样性结果变量、(d) 分时段估计后,PSI-Shannon 负关联是否
# 仍然存在?"努力作为因变量"的模型揭示了怎样的数据生成过程?
#
# Objective / 分析目标:
# Produce one tidy CSV of all specifications for figures and the
# Technical Comment. 输出统一规格结果表供图表与评论文章使用。
#
# Input / 输入: output/panel_master.rds (from 01)
# Output / 输出: output/spec_results.csv, output/effort_diag.csv,
#                output/r2_decomposition.csv, output/shannon_vs_effort.csv
#
# Key assumptions / 关键假设:
# - Clustering at county level (as in the paper); province-level shown
#   as sensitivity. 县级聚类为主(与原文一致),省级聚类作敏感性。
# - Effort-as-outcome models drop Duration from controls because it is
#   a deterministic function of BT/BN. 努力作因变量时剔除 Duration。
#
# Main packages / 主要包: data.table, fixest
# ============================================================

suppressPackageStartupMessages({
  library(data.table)
  library(fixest)
})

# 从仓库根目录运行本脚本 / run this script from the repository root:
#   Rscript analysis/<script>.R
base <- "."
out  <- file.path(base, "output")
m    <- readRDS(file.path(out, "panel_master.rds"))

CTRL  <- "Temp + Wind + Pop + Duration + Carbon + Water + Green + Farm + Grass"
CTRLX <- "Temp + Wind + Pop + Carbon + Water + Green + Farm + Grass"  # 无 Duration / no Duration

# 衍生变量 / derived outcomes
m[, ESN      := exp(ShannonBD)]            # 有效物种数 / effective species number (Hill q=1)
m[, lnRich   := log(Richness)]             # 对数丰富度 / log richness
m[, Evenness := ShannonBD / log(Richness)] # Pielou 均匀度(丰富度>1时) / Pielou evenness
m[Richness <= 1, Evenness := NA]
m[, era := fifelse(YEAR <= 2019, "2014-2019", "2020-2023")]  # 观鸟爆发前后 / pre/post boom

run1 <- function(fml, dat, clu = "county", label, series, note = "") {
  f <- tryCatch(
    feols(as.formula(fml), data = dat, cluster = as.formula(paste0("~", clu)),
          fixef.rm = "singletons"),
    error = function(e) NULL)
  if (is.null(f)) return(NULL)
  tv <- setdiff(names(coef(f)), c("(Intercept)"))
  # 关注变量:PI 或首个回归元 / focal regressor: PI if present, else first
  fv <- if ("PI" %in% tv) "PI" else tv[1]
  data.table(series = series, label = label,
             outcome = all.vars(as.formula(fml))[1], focal = fv,
             coef = coef(f)[fv], se = se(f)[fv], p = pvalue(f)[fv],
             N = nobs(f), r2_within = tryCatch(r2(f, "wr2"), error = function(e) NA),
             cluster = clu, note = note)
}

res <- list()

## ---- A. 努力作为控制 / effort as control ---------------------------------
res$a0 <- run1(paste("ShannonBD ~ PI +", CTRL, "| county + ym"), m,
               label = "Authors' specification", series = "A_effort_control",
               note = "exact replication")
res$a1 <- run1(paste("ShannonBD ~ PI + logBN +", CTRL, "| county + ym"), m,
               label = "+ ln(birdwatchers)", series = "A_effort_control")
res$a2 <- run1(paste("ShannonBD ~ PI + logBT +", CTRL, "| county + ym"), m,
               label = "+ ln(total duration)", series = "A_effort_control")
res$a3 <- run1(paste("ShannonBD ~ PI + logBN + logBT +", CTRL, "| county + ym"), m,
               label = "+ both effort terms", series = "A_effort_control")

## ---- A'. 努力作为结果 / effort as outcome --------------------------------
res$a5 <- run1(paste("logBN ~ PI +", CTRLX, "| county + ym"), m,
               label = "ln(birdwatchers) ~ PSI", series = "A_effort_outcome")
res$a6 <- run1(paste("logBT ~ PI +", CTRLX, "| county + ym"), m,
               label = "ln(total duration) ~ PSI", series = "A_effort_outcome")
res$a7 <- run1(paste("Duration ~ PI +", CTRLX, "| county + ym"), m,
               label = "authors' Duration ~ PSI", series = "A_effort_outcome")

## ---- B. 政策文件覆盖 / policy-source coverage ----------------------------
res$b1 <- run1(paste("ShannonBD ~ PI +", CTRL, "| county + ym"),
               m[PI_was_imputed == FALSE],
               label = "Counties in policy source only", series = "B_policy_zero",
               note = "drops 43.8% of rows imputed as PI=0")
res$b2 <- run1(paste("ShannonBD ~ PI +", CTRL, "| county + ym"),
               m[PI_was_imputed == FALSE], clu = "省",
               label = "Counties in policy source only (province cluster)",
               series = "B_policy_zero")

## ---- C. 替代结果指标 / alternative outcomes ------------------------------
res$c1 <- run1(paste("SimpsonBD ~ PI +", CTRL, "| county + ym"), m,
               label = "Simpson index", series = "C_metric")
res$c2 <- run1(paste("Richness ~ PI +", CTRL, "| county + ym"), m,
               label = "Species richness", series = "C_metric",
               note = "paper Table S19 col2")
res$c3 <- run1(paste("Richness ~ PI + logBN + logBT +", CTRL, "| county + ym"), m,
               label = "Species richness + effort", series = "C_metric")
res$c4 <- run1(paste("Evenness ~ PI +", CTRL, "| county + ym"), m,
               label = "Pielou evenness", series = "C_metric",
               note = "paper Table S19 col3 sign +")
res$c5 <- run1(paste("ESN ~ PI +", CTRL, "| county + ym"), m,
               label = "Effective species number exp(H)", series = "C_metric")
res$c6 <- run1(paste("ShannonBD ~ PI + logBN + logBT +", CTRL, "| county + ym"),
               m, clu = "省",
               label = "+ both effort terms (province cluster)", series = "A_effort_control")

## ---- D. 时段分割 / era split ---------------------------------------------
res$d1 <- run1(paste("ShannonBD ~ PI +", CTRL, "| county + ym"), m[era == "2014-2019"],
               label = "2014-2019 (pre-boom)", series = "D_era")
res$d2 <- run1(paste("ShannonBD ~ PI +", CTRL, "| county + ym"), m[era == "2020-2023"],
               label = "2020-2023 (boom)", series = "D_era")
res$d3 <- run1(paste("ShannonBD ~ PI + logBN + logBT +", CTRL, "| county + ym"),
               m[era == "2020-2023"],
               label = "2020-2023 + effort", series = "D_era")

spec <- rbindlist(res, fill = TRUE)
fwrite(spec, file.path(out, "spec_results.csv"))
print(spec[, .(series, label, outcome, coef = round(coef, 5), se = round(se, 5),
               p = signif(p, 3), N)], nrows = 40)

## ---- E. R² 分解 / R-squared decomposition --------------------------------
f_fe   <- feols(ShannonBD ~ 1 | county + ym, m, fixef.rm = "singletons")
f_pi   <- feols(ShannonBD ~ PI | county + ym, m, cluster = ~county, fixef.rm = "singletons")
f_full <- feols(as.formula(paste("ShannonBD ~ PI +", CTRL, "| county + ym")), m,
                cluster = ~county, fixef.rm = "singletons")
f_ctrl <- feols(as.formula(paste("ShannonBD ~", CTRL, "| county + ym")), m,
                cluster = ~county, fixef.rm = "singletons")

r2dec <- data.table(
  component = c("County + year-month FE only", "FE + PSI", "FE + controls (no PSI)",
                "FE + controls + PSI (full)"),
  r2        = c(r2(f_fe, "r2"), r2(f_pi, "r2"), r2(f_ctrl, "r2"), r2(f_full, "r2")),
  r2_within = c(0, r2(f_pi, "wr2"), r2(f_ctrl, "wr2"), r2(f_full, "wr2"))
)
r2dec[, delta_r2 := r2 - shift(r2, fill = NA)]
# PSI 的独立增量(在全控制之上)/ unique increment of PSI over controls
psi_unique <- r2(f_full, "r2") - r2(f_ctrl, "r2")
r2dec <- rbind(r2dec,
               data.table(component = "PSI unique increment over controls",
                          r2 = psi_unique, r2_within = NA, delta_r2 = NA))
fwrite(r2dec, file.path(out, "r2_decomposition.csv"))
cat("\n=== R2 decomposition ===\n"); print(r2dec, digits = 4)

## 信号噪声比 / signal vs residual noise
sd_pi   <- sd(m$PI)
eff_abs <- abs(coef(f_full)["PI"]) * sd_pi
res_sd  <- sd(resid(f_full))
cat(sprintf("\n1-SD PSI effect on Shannon = %.4f; residual SD = %.3f; ratio = %.3f\n",
            eff_abs, res_sd, eff_abs / res_sd))

## ---- G. 努力诊断表 / effort diagnostics ----------------------------------
# 年度总量 / annual totals
ann <- m[, .(BN_total = sum(BN), BT_total = sum(BT),
             county_months = .N, counties = uniqueN(id),
             PI_mean = mean(PI), PI_pos_share = mean(PI > 0),
             Shannon_mean = mean(ShannonBD), Rich_mean = mean(Richness, na.rm = TRUE)),
         by = YEAR][order(YEAR)]
fwrite(ann, file.path(out, "effort_annual.csv"))
cat("\n=== Annual effort & policy ===\n"); print(ann, digits = 3)

# 县覆盖月数 / county coverage in months (out of 120)
cov <- m[, .(months_observed = .N), by = id]
cat(sprintf("\nCoverage months per county: median = %d, IQR = [%d, %d] of 120\n",
            as.integer(median(cov$months_observed)),
            as.integer(quantile(cov$months_observed, .25)),
            as.integer(quantile(cov$months_observed, .75))))
fwrite(cov, file.path(out, "county_coverage.csv"))

# Shannon/Richness 随努力的饱和曲线(binned)/ observed diversity vs effort bins
m[, BN_bin := cut(BN, breaks = c(0, 1, 2, 3, 5, 10, 20, 50, 100, Inf),
                  labels = c("1", "2", "3", "4-5", "6-10", "11-20", "21-50",
                             "51-100", ">100"))]
sat <- m[, .(Shannon_mean = mean(ShannonBD), Shannon_sd = sd(ShannonBD),
             Rich_mean = mean(Richness, na.rm = TRUE),
             Even_mean = mean(Evenness, na.rm = TRUE),
             Duration_mean = mean(Duration), n = .N), by = BN_bin][order(BN_bin)]
fwrite(sat, file.path(out, "shannon_vs_effort.csv"))
cat("\n=== Observed diversity vs number of birdwatchers (saturation) ===\n")
print(sat, digits = 3)

# 作者的 Duration 与总努力的相关 / correlation of Duration with total effort
cat("\nCor(Duration, logBN) =", round(cor(m$Duration, m$logBN), 3),
    "; Cor(Duration, logBT) =", round(cor(m$Duration, m$logBT), 3),
    "; Cor(logBN, logBT) =", round(cor(m$logBN, m$logBT), 3), "\n")
