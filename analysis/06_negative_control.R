# ============================================================
# Scientific question / 科学问题:
# Why would solar-policy stringency "reduce" birdwatcher numbers?
# Is PSI -> effort a genuine behavioural effect, or the signature of
# differential trends that contaminates ANY outcome under this TWFE
# design? We treat birdwatcher count as a NEGATIVE-CONTROL OUTCOME
# and test four competing explanations.
# 光伏政策强度为何会"减少"观鸟者?PSI->努力是真实行为效应,还是
# 差异趋势在该 TWFE 设计下污染任何结果变量的签名?我们把观鸟人数
# 作为阴性对照结果变量,检验四个竞争解释。
#
# Competing explanations / 竞争解释:
#  H1 施工排斥: PSI -> 实际光伏建设 -> 观鸟点受扰 -> 观鸟者减少
#     (requires PSI to predict realized PV area within county)
#  H2 差异趋势: PSI 增长集中在观鸟增长慢于全国平均的县;
#     year-month FE 只吸收全国共同趋势 -> 系统性负偏
#     (predicts: county linear trends kill BOTH effort & Shannon effects;
#      future PSI "affects" today's effort — pre-trend)
#  H3 填零伪影: 43.9% 填零观测制造相关
#     (predicts: effect gone in policy-source subsample)
#  H4 发展阶段共因: 政策文书密度与城市化阶段相关,观鸟人口增长
#     亦随城市化 — nightlight 作为第二个阴性对照
#
# Input / 输入: output/panel_master.rds + DATA/IC.dta (installed capacity)
# Output / 输出: output/negative_control.csv, output/pretrend_effort.csv,
#                output/hotspot_trajectories.csv
# Main packages / 主要包: data.table, fixest, haven
# ============================================================

suppressPackageStartupMessages({
  library(data.table); library(fixest); library(haven)
})

base <- "/Users/dingchenchen/Documents/能源转型与生态保护"
out  <- file.path(base, "output")
dta  <- file.path(base, "original_replication/extracted/DATA")
m    <- readRDS(file.path(out, "panel_master.rds"))

CTRLX <- "Temp + Wind + Pop + Carbon + Water + Green + Farm + Grass"  # 无 Duration

## ---- 补充变量 / add realized PV area, nightlight, PSI lead -----------------
ic <- as.data.table(read_dta(file.path(dta, "IC.dta")))[, .(id, YEAR, ICtotal)]
nl <- as.data.table(read_dta(file.path(dta, "NL.dta")))[, .(id, YEAR, Nightlight)]
m <- merge(m, ic, by = c("id", "YEAR"), all.x = TRUE)
m <- merge(m, nl, by = c("id", "YEAR"), all.x = TRUE)
m[is.na(ICtotal), ICtotal := 0]
m[, Area := ICtotal * 1000 / 0.15 / 1e6]         # 同原文换算 / authors' conversion
m[, lnNL := log(Nightlight + 1)]

# PSI 的未来值(lead)/ next-year PSI, from the county-year policy panel
py <- unique(m[, .(id, YEAR, PI)])
py[, PI_lead1 := shift(PI, -1), by = id]
m <- merge(m, py[, .(id, YEAR, PI_lead1)], by = c("id", "YEAR"), all.x = TRUE)

run1 <- function(fml, dat, label, clu = "county", note = "") {
  f <- tryCatch(feols(as.formula(fml), dat, cluster = as.formula(paste0("~", clu)),
                      fixef.rm = "singletons"), error = function(e) NULL)
  if (is.null(f)) return(NULL)
  tv <- names(coef(f)); fv <- intersect(c("PI", "PI_lead1", "Area"), tv)[1]
  data.table(label, focal = fv, coef = coef(f)[fv], se = se(f)[fv],
             p = pvalue(f)[fv], N = nobs(f), note)
}

res <- list()

## ---- H3 填零伪影?/ imputation artifact? ----------------------------------
res$a <- run1(paste("logBN ~ PI +", CTRLX, "| county + ym"), m,
              "Effort ~ PSI, full sample (baseline)")
res$b <- run1(paste("logBN ~ PI +", CTRLX, "| county + ym"),
              m[PI_was_imputed == FALSE],
              "Effort ~ PSI, policy-source counties only",
              note = "if survives, not an imputation artifact")

## ---- H1 施工排斥?/ construction displacement? ----------------------------
res$c <- run1(paste("Area ~ PI +", CTRLX, "| county + ym"), m,
              "Realized PV area ~ PSI (within county)",
              note = "H1 requires strong positive")
res$d <- run1(paste("logBN ~ Area +", CTRLX, "| county + ym"), m,
              "Effort ~ realized PV area",
              note = "direct displacement test")

## ---- H2 差异趋势:县级线性趋势 / county-specific linear trends -------------
m[, tnum := as.integer(factor(ym))]
res$e <- run1(paste("logBN ~ PI +", CTRLX, "| county + ym + county[tnum]"), m,
              "Effort ~ PSI + county linear trends",
              note = "H2 predicts collapse")
res$f <- run1(paste("ShannonBD ~ PI + Temp + Wind + Pop + Duration + Carbon +",
                    "Water + Green + Farm + Grass | county + ym + county[tnum]"), m,
              "Shannon ~ PSI + county linear trends",
              note = "same trends should kill headline too")

## ---- H2 预趋势:未来政策"影响"今天的努力 / pre-trend via future PSI --------
res$g <- run1(paste("logBN ~ PI_lead1 + PI +", CTRLX, "| county + ym"), m,
              "Effort ~ NEXT-year PSI (conditional on current)",
              note = "significant lead = differential trend, not causation")

## ---- H4 发展阶段:夜光阴性对照 / nightlight as second negative control -----
res$h <- run1(paste("lnNL ~ PI +", CTRLX, "| county + ym"), m,
              "ln(nightlight) ~ PSI",
              note = "policy should not dim city lights")

nc <- rbindlist(res, fill = TRUE)
fwrite(nc, file.path(out, "negative_control.csv"))
cat("=== Negative-control & mechanism tests ===\n")
print(nc[, .(label, coef = round(coef, 5), se = round(se, 5),
             p = signif(p, 3), N, note)], nrows = 30)

## ---- 描述性:选择效应轨迹 / descriptive selection trajectories -------------
# 县按 2014-2016 观鸟基数分组;比较两组 2014-2023 的 BN 与 PSI 轨迹
base_bn <- m[YEAR <= 2016, .(bn0 = sum(BN)), by = id]
m <- merge(m, base_bn, by = "id", all.x = TRUE)
m[is.na(bn0), bn0 := 0]
m[, hotspot := fifelse(bn0 >= quantile(base_bn$bn0, .75), "hotspot", "non-hotspot")]
traj <- m[, .(BN_total = sum(BN), PI_mean = mean(PI),
              counties = uniqueN(id)), by = .(hotspot, YEAR)][order(hotspot, YEAR)]
traj[, BN_rel := BN_total / BN_total[1], by = hotspot]
traj[, PI_rel := PI_mean / PI_mean[1], by = hotspot]
fwrite(traj, file.path(out, "hotspot_trajectories.csv"))
cat("\n=== Effort vs policy growth by baseline birding intensity ===\n")
print(dcast(traj, YEAR ~ hotspot, value.var = c("BN_rel", "PI_rel")), digits = 3)
