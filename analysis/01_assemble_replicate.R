# ============================================================
# Scientific question / 科学问题:
# Can the headline estimate of Zhang et al. (2026, Science 393:831-836,
# "China's solar expansion policy reduces bird diversity") be reproduced
# exactly from their public replication package, and does it survive
# corrections for (i) unmodeled birdwatching effort, (ii) the
# missing-policy-equals-zero imputation, and (iii) the choice of
# diversity metric?
# Zhang et al. (2026) 的主效应能否从公开复现包精确复现?在校正
# (i) 未建模的观鸟努力、(ii) "政策缺失即为零"的填补假设、
# (iii) 多样性指标选择之后,该效应是否仍然成立?
#
# Objective / 分析目标:
# 1. Rebuild the county-month analysis panel following CODE.do line by line.
#    按 CODE.do 逐行重建县-月分析面板。
# 2. Reproduce Table 1 columns (1)-(3) to 4 decimal places.
#    将 Table 1 第(1)-(3)列复现到小数点后 4 位。
# 3. Save the assembled panel for downstream diagnostic scripts.
#    保存组装面板供后续诊断脚本使用。
#
# Input data / 输入数据:
# original_replication/extracted/DATA/*.dta (authors' public package)
#
# Workflow / 分析流程:
# 1. Load and merge Bird, BTN, PI, Climate, PD, air, TD / 读取并合并
# 2. Construct variables exactly as in CODE.do / 严格按原代码构造变量
# 3. Winsorize 1/99 as in winsor2 / 按 winsor2 逻辑 1%/99% 缩尾
# 4. Fit reghdfe-equivalent TWFE with fixest / 用 fixest 复刻 reghdfe
# 5. Export coefficients and panel / 导出系数与面板
#
# Expected output / 预期输出:
# output/table1_replication.csv, output/panel_master.rds
#
# Key assumptions / 关键假设:
# - Stata 'year' variable in Bird.dta is the monthly date (year-month FE).
#   Bird.dta 中 'year' 为月度日期,即年月固定效应。
# - reghdfe drops singleton groups iteratively; fixest handles via note.
#   reghdfe 迭代剔除单例组;fixest 中显式核对样本量。
#
# Main packages / 主要包: haven, data.table, fixest
# Output directory / 输出路径: output/
# ============================================================

suppressPackageStartupMessages({
  library(haven)
  library(data.table)
  library(fixest)
})

base <- "/Users/dingchenchen/Documents/能源转型与生态保护"
dta  <- file.path(base, "original_replication/extracted/DATA")
out  <- file.path(base, "output")

rd <- function(f) as.data.table(read_dta(file.path(dta, f)))

## ---- 1. Load core tables / 读取核心数据 ----------------------------------
bird <- rd("Bird.dta")          # county-month Shannon & Simpson / 县-月多样性
btn  <- rd("BTN.dta")           # birdwatching duration & birders / 观鸟时长与人数
pi   <- rd("PI.dta")            # county-year policy stringency / 县-年政策强度
clim <- rd("Climate.dta")       # Avt, Wind
pd   <- rd("PD.dta")            # population density
air  <- rd("air.dta")           # CO2, PM
td   <- rd("TD.dta")            # Water Green Farm Grass
rich <- rd("Richeven.dta")      # species richness / 物种丰富度(下游用)

# 统一构造年月键 / build a robust year-month key per table.
# Stata 'year' is %tm in some files (months since 1960m1) and a date in others;
# use each table's own year-month field to avoid silent mis-conversion.
# 部分表的 year 是 Stata %tm 整数(1960 年起的月数),部分是日期——
# 各表用自带年月字段构造键,避免静默错位。
stata_tm_to_ym <- function(x) sprintf("%d-%02d", 1960 + x %/% 12, x %% 12 + 1)

bird[, ymkey := as.character(标准年月)]                        # "2014-01"
btn[,  ymkey := sprintf("%d-%02d", 年月 %/% 100, 年月 %% 100)] # 201401 -> "2014-01"
if (inherits(rich$year, "Date")) {
  rich[, ymkey := format(year, "%Y-%m")]
} else {
  rich[, ymkey := stata_tm_to_ym(as.numeric(year))]
}

## ---- 2. Merge following CODE.do / 按原代码顺序合并 ------------------------
# merge 1:1 id year using BTN (keep BT BN)
m <- merge(bird, btn[, .(id, ymkey, BT, BN)], by = c("id", "ymkey"), all.x = TRUE)
# merge m:1 id YEAR using PI
m <- merge(m, pi[, .(id, YEAR, PI)], by = c("id", "YEAR"), all.x = TRUE)
# Climate: Avt -> Temp
m <- merge(m, clim[, .(id, YEAR, Temp = Avt, Wind)], by = c("id", "YEAR"), all.x = TRUE)
# PD
m <- merge(m, pd[, .(id, YEAR, PD)], by = c("id", "YEAR"), all.x = TRUE)
# air: CO2 PM
m <- merge(m, air[, .(id, YEAR, CO2, PM25 = PM)], by = c("id", "YEAR"), all.x = TRUE)
# TD: land use shares
m <- merge(m, td[, .(id, YEAR, Water, Green, Farm, Grass)], by = c("id", "YEAR"), all.x = TRUE)
# Richness (1:1 id year, monthly) — 下游指标替换用
m <- merge(m, rich[, .(id, ymkey, Richness = 丰富度)], by = c("id", "ymkey"), all.x = TRUE)

## ---- 3. Variable construction / 变量构造(严格复刻)-----------------------
m[, BTN_ratio := BT / BN]                       # 人均观鸟时长 / per-birder duration
m[is.na(PI), PI := 0]                           # 缺失政策填 0 / missing policy -> 0 (authors' assumption)
m[, PI_was_imputed := !(id %in% pi$id)]         # 标记:县从未出现在政策文件 / county absent from policy file

# complete-case drop 与原代码一致 / drop rows with missing controls
m <- m[!is.na(Temp) & !is.na(Wind) & !is.na(PD) & !is.na(BTN_ratio) &
         !is.na(CO2) & !is.na(Water) & !is.na(Green) & !is.na(Farm) & !is.na(Grass)]

m[, Pop      := log(PD)]
m[, Duration := log(BTN_ratio + 1)]             # 作者的努力控制:ln(人均时长+1)
m[, Carbon   := log(CO2)]

# 追加的努力度量(作者未用)/ additional effort measures (not used by authors)
m[, logBN := log(BN)]                            # ln 观鸟人数 / ln birder count
m[, logBT := log(BT + 1)]                        # ln 总观鸟时长 / ln total duration

## ---- 4. Winsorize 1/99 (winsor2 replace) / 缩尾 ---------------------------
# winsor2 uses Stata percentiles on the estimation sample after the drop.
# Stata 的 percentile 与 R type=2 定义一致性足够(46k 样本差异可忽略)。
wvars <- c("ShannonBD", "SimpsonBD", "PI", "Temp", "Wind", "Pop", "Duration",
           "Carbon", "Water", "Green", "Farm", "Grass", "Richness")
for (v in wvars) {
  q <- quantile(m[[v]], c(.01, .99), na.rm = TRUE, type = 2)
  m[, (v) := pmin(pmax(get(v), q[1]), q[2])]
}

m[, county := .GRP, by = id]
m[, ym := ymkey]

saveRDS(m, file.path(out, "panel_master.rds"))

## ---- 5. Replicate Table 1 / 复现 Table 1 ---------------------------------
ctrl2 <- "Temp + Wind + Pop + Duration + Carbon"
ctrl3 <- paste(ctrl2, "+ Water + Green + Farm + Grass")

f1 <- feols(ShannonBD ~ PI                     | county + ym, data = m,
            cluster = ~county, fixef.rm = "singletons")
f2 <- feols(as.formula(paste("ShannonBD ~ PI +", ctrl2, "| county + ym")),
            data = m, cluster = ~county, fixef.rm = "singletons")
f3 <- feols(as.formula(paste("ShannonBD ~ PI +", ctrl3, "| county + ym")),
            data = m, cluster = ~county, fixef.rm = "singletons")

rep_tab <- data.table(
  column   = c("(1) PI only", "(2) + climate/socio", "(3) full controls"),
  beta_PI  = sapply(list(f1, f2, f3), \(x) coef(x)["PI"]),
  se_PI    = sapply(list(f1, f2, f3), \(x) se(x)["PI"]),
  p_PI     = sapply(list(f1, f2, f3), \(x) pvalue(x)["PI"]),
  N        = sapply(list(f1, f2, f3), nobs),
  r2       = sapply(list(f1, f2, f3), \(x) r2(x, type = "r2")),
  r2_within= sapply(list(f1, f2, f3), \(x) r2(x, type = "wr2"))
)
fwrite(rep_tab, file.path(out, "table1_replication.csv"))

cat("=== Table 1 replication (paper: -0.0157/-0.0127/-0.0125, SE 0.0037/0.0036/0.0037) ===\n")
print(rep_tab, digits = 4)

## 效应量换算 / headline effect conversion
sd_pi <- sd(m$PI); mn_sh <- mean(m$ShannonBD)
cat(sprintf("\nSD(PI)=%.4f mean(Shannon)=%.4f  headline %% = %.3f%%\n",
            sd_pi, mn_sh, 100 * coef(f3)["PI"] * sd_pi / mn_sh))
cat(sprintf("Counties never in policy file: %d of %d (%.1f%% of rows)\n",
            uniqueN(m[PI_was_imputed == TRUE, id]), uniqueN(m$id),
            100 * mean(m$PI_was_imputed)))
