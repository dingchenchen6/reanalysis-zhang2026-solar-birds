# ============================================================
# 13_effort_accessibility.R
# 科学问题 / question: 观鸟努力(观鸟人数)是否集中于经济发达、
#   可达性高的县? / Does birdwatching effort concentrate in
#   economically developed, accessible counties?
# 分析目标 / goal: 县-月尺度上检验 ln(观鸟人数) 与夜间灯光、
#   人口密度的横截面关联(年-月固定效应, 县聚类SE),并给出
#   跨县集中度描述统计。
# 输入 / input : output/panel_master.rds (脚本01生成),
#                original_replication/extracted/DATA/NL.dta
# 主要流程 / workflow: 合并夜光 -> 三个 feols 回归 -> 集中度统计
# 预期输出 / output: output/effort_accessibility.csv
# 关键假设 / assumptions: 夜光与人口密度是城市化/经济活动(从而
#   可达性)的代理;年-月FE吸收共同季节与增长趋势,系数反映
#   同一日历月内的县间差异。
# 主要包 / packages: data.table, haven, fixest
# ============================================================

suppressPackageStartupMessages({
  library(data.table); library(haven); library(fixest)
})

out <- "output"
dta <- file.path("original_replication", "extracted", "DATA")

m  <- as.data.table(readRDS(file.path(out, "panel_master.rds")))
nl <- as.data.table(read_dta(file.path(dta, "NL.dta")))[, .(id, YEAR, Nightlight)]
m[, id := as.integer(id)][, YEAR := as.integer(YEAR)]
nl[, id := as.integer(id)][, YEAR := as.integer(YEAR)]
d  <- merge(m, nl, by = c("id", "YEAR"), all.x = TRUE)
stopifnot(sum(is.na(d$Nightlight)) == 0)

d[, lnNL := log(Nightlight + 1)]
d[, lnBN := log(BN)]
d[, lnPD := log(PD)]

## ---- 县-月回归: 年-月FE, 县聚类 / county-month regressions ----------------
f_nl    <- feols(lnBN ~ lnNL        | ym, data = d, cluster = ~county)
f_pd    <- feols(lnBN ~ lnPD        | ym, data = d, cluster = ~county)
f_joint <- feols(lnBN ~ lnNL + lnPD | ym, data = d, cluster = ~county)

row <- function(model, fit, term) {
  ct <- coeftable(fit)[term, ]
  data.table(model = model, term = term,
             estimate = round(ct[1], 4), se = round(ct[2], 4),
             p = signif(ct[4], 3), n = nobs(fit))
}
res <- rbind(row("lnBN ~ lnNL | ym",        f_nl,    "lnNL"),
             row("lnBN ~ lnPD | ym",        f_pd,    "lnPD"),
             row("lnBN ~ lnNL + lnPD | ym", f_joint, "lnNL"),
             row("lnBN ~ lnNL + lnPD | ym", f_joint, "lnPD"))

## ---- 跨县集中度 / between-county concentration ----------------------------
cty <- d[, .(BN_tot = sum(BN), NL_mean = mean(Nightlight),
             mlnBN = mean(lnBN), mlnNL = mean(lnNL), mlnPD = mean(lnPD)),
         by = county]
cty[, NL_decile := cut(NL_mean, quantile(NL_mean, 0:10/10),
                       labels = FALSE, include.lowest = TRUE)]
share_top10  <- cty[NL_decile == 10, sum(BN_tot)] / cty[, sum(BN_tot)]
share_bot50  <- cty[NL_decile <= 5,  sum(BN_tot)] / cty[, sum(BN_tot)]
desc <- data.table(
  model = c("share of birdwatchers, top nightlight decile",
            "share of birdwatchers, bottom nightlight half",
            "between-county cor(mean lnBN, mean lnNL)",
            "between-county cor(mean lnBN, mean lnPD)"),
  term = "descriptive",
  estimate = round(c(share_top10, share_bot50,
                     cty[, cor(mlnBN, mlnNL)], cty[, cor(mlnBN, mlnPD)]), 3),
  se = NA_real_, p = NA_real_, n = nrow(cty))

fwrite(rbind(res, desc), file.path(out, "effort_accessibility.csv"))
print(rbind(res, desc))
cat("done: output/effort_accessibility.csv\n")
