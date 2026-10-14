# ============================================================
# Scientific question / 科学问题:
# Can other analysts reproduce every estimate in the Comment directly
# from a single, documented county-month panel, without rebuilding it?
# 其他研究者能否不经重建、直接从一份有说明的县-月面板复现评论中的
# 每一个估计?
#
# Objective / 分析目标:
# Export the analysis panel rebuilt from the authors' public replication
# package, with flags that encode the Comment's cleaning scheme, and
# verify by reading the exported file back that it reproduces (a) the
# authors' headline estimate and (b) our preferred corrected estimate.
# 导出由作者公开复现包重建的分析面板,附上体现评论清洗方案的标记;
# 并回读导出文件,验证其能复现 (a) 作者头条估计与 (b) 我们的首选校正估计。
#
# Input / 输入: output/panel_master.rds (rebuilt by script 01)
# Output / 输出: data/panel_county_month_cleaned.csv.gz
# Workflow / 主要流程:
#   1. Flag the cleaning scheme / 标记清洗方案
#   2. Mark the exact rows each specification uses / 标记各规格实际使用的行
#   3. Export / 导出
#   4. Read back and verify / 回读并验证
# Key assumptions / 关键假设: corrupted-row rule as in script 05;
#   fixed effects, controls, clustering, and singleton handling as the
#   authors. 污染行规则同脚本 05;固定效应、控制变量、聚类与单例处理同作者。
# Main packages / 主要包: data.table, fixest
# Output directory / 输出路径: data/
# ============================================================

suppressPackageStartupMessages({ library(data.table); library(fixest) })

# 从仓库根目录运行本脚本 / run this script from the repository root:
#   Rscript analysis/17_export_cleaned_panel.R
base <- "."
dir.create(file.path(base, "data"), showWarnings = FALSE)
out_file <- file.path(base, "data", "panel_county_month_cleaned.csv.gz")
m <- readRDS(file.path(base, "output", "panel_master.rds"))

CTRL  <- "Temp + Wind + Pop + Duration + Carbon + Water + Green + Farm + Grass"
sd_pi <- sd(m$PI); mn_h <- mean(m$ShannonBD)

## ---- 1. 清洗方案标记 / cleaning-scheme flags ----------------------------
m[, row_id := .I]
# 污染县-月:两分支规则,与脚本 05 完全一致 / corrupted rule, identical to script 05
m[, flag_corrupted := !is.na(Richness) &
    ((Richness >= 20 & ShannonBD < 0.2) | (Richness >= 2 & ShannonBD < 1e-3))]
m[, flag_H0 := ShannonBD == 0]                    # 只记到一个物种 / one species recorded
m[, PSI_zero_type := fifelse(PI > 0, "positive",
                     fifelse(PI_was_imputed, "imputed_zero", "true_zero"))]

## ---- 2. 各规格实际使用的行 / rows used by each specification -------------
# 用 fixest 的 obs() 取回实际进入回归的行,保证标记子集的 N 与正文一致。
# obs() returns the rows that actually enter each regression, so subsetting
# on these flags reproduces the reported sample sizes exactly.
fit <- function(dat, rhs) {
  feols(as.formula(paste("ShannonBD ~", rhs, "| county + ym")), dat,
        cluster = ~county, fixef.rm = "singletons")
}
f_auth <- fit(m, paste("PI +", CTRL))
m[, in_estimation_sample := row_id %in% m$row_id[obs(f_auth)]]

d_pref <- m[PI_was_imputed == FALSE & flag_corrupted == FALSE]
f_pref <- fit(d_pref, paste("PI + logBN + logBT +", CTRL))
m[, in_preferred_sample := row_id %in% d_pref$row_id[obs(f_pref)]]

## ---- 3. 导出 / export ------------------------------------------------------
setcolorder(m, c("row_id", "id", "county", "省", "市", "县", "YEAR", "month",
                 "ymkey", "ym", "in_estimation_sample", "in_preferred_sample",
                 "PI_was_imputed", "PSI_zero_type", "flag_corrupted", "flag_H0"))
fwrite(m, out_file)
cat(sprintf("Exported %d rows x %d columns to %s\n", nrow(m), ncol(m), out_file))

## ---- 4. 回读验证 / read back and verify ------------------------------------
# 从导出文件重新估计,而非沿用内存对象,检验 CSV 往返不损失精度。
# Re-estimate from the exported file itself to rule out round-trip loss.
x <- fread(out_file)
x[, `:=`(county = as.character(county), ym = as.character(ym))]

v_auth <- fit(x[in_estimation_sample == TRUE], paste("PI +", CTRL))
v_pref <- fit(x[in_preferred_sample == TRUE], paste("PI + logBN + logBT +", CTRL))

pct <- function(b) 100 * b * sd_pi / mn_h
ver <- data.table(
  check    = c("Authors' specification (Table 1, col. 3)",
               "Preferred corrected estimate"),
  expected = c("beta = -0.0125, N = 46,371",
               "+0.14% (95% CI -0.96 to +1.24), N = 25,996"),
  obtained = c(sprintf("beta = %.4f, N = %s", coef(v_auth)["PI"],
                       format(nobs(v_auth), big.mark = ",")),
               sprintf("%+.2f%% (95%% CI %.2f to %+.2f), N = %s",
                       pct(coef(v_pref)["PI"]),
                       pct(coef(v_pref)["PI"] - 1.96 * se(v_pref)["PI"]),
                       pct(coef(v_pref)["PI"] + 1.96 * se(v_pref)["PI"]),
                       format(nobs(v_pref), big.mark = ","))))
print(ver)
stopifnot(abs(coef(v_auth)["PI"] + 0.0125) < 5e-5, nobs(v_auth) == 46371,
          abs(pct(coef(v_pref)["PI"]) - 0.14) < 0.005, nobs(v_pref) == 25996)
cat("Verification passed: the exported panel reproduces both estimates.\n")
