# ============================================================
# Scientific question / 科学问题:
# Does the authors' shift-share instrument (ln historical sunshine /
# city climate-policy uncertainty) rescue the causal claim? I replicate
# the first stage and 2SLS myself, then add the total-effort term, so
# every IV number in the audit is first-hand.
# 作者的移动份额工具变量(历史日照对数 / 城市气候政策不确定性)能否
# 挽救因果主张?我自行复现一阶段与 2SLS,并加入总努力项,使审计中
# 全部 IV 数字为第一手结果。
#
# Input / 输入: output/panel_master.rds + DATA/sunshine.dta, CCPU.dta
# Output / 输出: output/iv_replication.csv
# Main packages / 主要包: data.table, fixest, haven
# ============================================================

suppressPackageStartupMessages({
  library(data.table); library(fixest); library(haven)
})

base <- "/Users/dingchenchen/Documents/能源转型与生态保护"
dta  <- file.path(base, "original_replication/extracted/DATA")
out  <- file.path(base, "output")
m    <- readRDS(file.path(out, "panel_master.rds"))

## ---- 构造 IV(照原文管线)/ build instrument as in CODE.do ----------------
sun  <- as.data.table(read_dta(file.path(dta, "sunshine.dta")))[, .(id, YEAR, sun)]
ccpu <- as.data.table(read_dta(file.path(dta, "CCPU.dta")))[, .(市, YEAR, CCPU)]
m <- merge(m, sun,  by = c("id", "YEAR"),  all.x = TRUE)
m <- merge(m, ccpu, by = c("市", "YEAR"), all.x = TRUE)

wins <- function(x) {                       # 1/99 缩尾,同 winsor2 / as winsor2
  q <- quantile(x, c(.01, .99), na.rm = TRUE, type = 2)
  pmin(pmax(x, q[1]), q[2])
}
m[, sun  := wins(sun)]
m[, CCPU := wins(CCPU)]
m[, Sun_ccpu := log(sun) / CCPU]

CTRL <- "Temp + Wind + Pop + Duration + Carbon + Water + Green + Farm + Grass"

## ---- 一阶段 / first stage --------------------------------------------------
fs <- feols(as.formula(paste("PI ~ Sun_ccpu +", CTRL, "| county + ym")),
            m, cluster = ~county, fixef.rm = "singletons")
t_fs <- coef(fs)["Sun_ccpu"] / se(fs)["Sun_ccpu"]

## ---- 2SLS(作者规格)/ 2SLS, authors' specification ------------------------
iv1 <- feols(as.formula(paste("ShannonBD ~", CTRL, "| county + ym | PI ~ Sun_ccpu")),
             m, cluster = ~county, fixef.rm = "singletons")

## ---- 2SLS + 总努力 / 2SLS with total-effort term ---------------------------
iv2 <- feols(as.formula(paste("ShannonBD ~ logBN +", CTRL, "| county + ym | PI ~ Sun_ccpu")),
             m, cluster = ~county, fixef.rm = "singletons")

## ---- 2SLS,政策记录县 / 2SLS, policy-documented counties -------------------
iv3 <- feols(as.formula(paste("ShannonBD ~", CTRL, "| county + ym | PI ~ Sun_ccpu")),
             m[PI_was_imputed == FALSE], cluster = ~county, fixef.rm = "singletons")

res <- data.table(
  model = c("First stage: PI ~ Sun_ccpu (authors' controls)",
            "2SLS: Shannon ~ PI-hat (authors' spec)",
            "2SLS + ln(birdwatchers)",
            "2SLS, policy-documented counties"),
  coef = c(coef(fs)["Sun_ccpu"], coef(iv1)["fit_PI"],
           coef(iv2)["fit_PI"], coef(iv3)["fit_PI"]),
  se   = c(se(fs)["Sun_ccpu"], se(iv1)["fit_PI"],
           se(iv2)["fit_PI"], se(iv3)["fit_PI"]),
  p    = c(pvalue(fs)["Sun_ccpu"], pvalue(iv1)["fit_PI"],
           pvalue(iv2)["fit_PI"], pvalue(iv3)["fit_PI"]),
  N    = c(nobs(fs), nobs(iv1), nobs(iv2), nobs(iv3)))
res[1, note := sprintf("cluster-robust t = %.2f, t^2 (= effective F) = %.2f", t_fs, t_fs^2)]
fwrite(res, file.path(out, "iv_replication.csv"))
cat("=== IV replication (first-hand) ===\n")
print(res[, .(model, coef = round(coef, 4), se = round(se, 4),
              p = signif(p, 3), N, note)], nrows = 10)
