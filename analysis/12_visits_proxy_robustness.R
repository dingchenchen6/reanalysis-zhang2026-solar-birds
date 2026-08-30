# ============================================================
# Scientific question / 科学问题:
# Is the effort-correction result specific to the CHOICE of effort
# proxy? The authors' panel carries only birdwatcher numbers (BN) and
# total hours (BT). Here we build a third, independent proxy — the
# number of checklists (visits) per county-month, from record-level
# platform data — and rerun the authors' specification with it.
# 努力校正的结果是否依赖于代理变量的选择?作者面板只有观鸟人数与
# 总时长两个总努力量。本脚本用记录级数据构造第三个独立代理——
# 县-月清单数(visit 数)——放回作者规格重估。
#
# Input / 输入: data_raw/birdwatch_event_table_2000_2025.csv.gz,
#               output/panel_master.rds
# Output / 输出: output/visits_robustness.csv
# Main packages / 主要包: data.table, fixest
# ============================================================

suppressPackageStartupMessages({ library(data.table); library(fixest) })
setDTthreads(4)

# 从仓库根目录运行本脚本 / run this script from the repository root:
#   Rscript analysis/<script>.R
base <- "."
out  <- file.path(base, "output")
F <- file.path(base, "data_raw", "birdwatch_event_table_2000_2025.csv.gz")
if (!file.exists(F)) F <- Sys.getenv("BIRDWATCH_EVENT_TABLE", "")
if (!file.exists(F)) stop(
  "Event table not found. Download birdwatch_event_table_2000_2025.csv.gz\n",
  "from the repository release (data-v1) into data_raw/, or set the\n",
  "BIRDWATCH_EVENT_TABLE environment variable to its full path.")

m <- readRDS(file.path(out, "panel_master.rds"))

## ---- 1. 县-月清单数 / checklists (visits) per county-month -----------------
cols <- c("source", "event_id", "year", "month", "address")
d <- fread(cmd = paste("gzcat", shQuote(F)), select = cols, showProgress = FALSE)
d <- d[source == "China_Birdwatch_Platform" & year %between% c(2014, 2023)]
ev <- unique(d, by = "event_id")

# 县名解析:同脚本 10 的分块正则,长县名优先 / county parsing as in script 10
cties <- unique(m$县)
cties <- cties[order(-nchar(cties))]
ua <- unique(ev[, .(address)])
ua[, county := NA_character_]
for (ck in split(cties, ceiling(seq_along(cties) / 300))) {
  idx <- which(is.na(ua$county))
  if (!length(idx)) break
  mm <- regexpr(paste(ck, collapse = "|"), ua$address[idx])
  got <- mm > 0
  ua$county[idx[got]] <- substring(ua$address[idx][got], mm[got],
                                   mm[got] + attr(mm, "match.length")[got] - 1)
}
ev <- merge(ev, ua, by = "address")
vis <- ev[!is.na(county),
          .(visits = .N), by = .(县 = county, ymkey = sprintf("%d-%02d", year, month))]
cat(sprintf("county-months with a visit count: %s\n",
            format(nrow(vis), big.mark = ",")))

## ---- 2. 合并作者面板 / merge onto the authors' panel -----------------------
mm2 <- merge(m, vis, by = c("县", "ymkey"), all.x = TRUE)
cov <- mean(!is.na(mm2$visits))
cat(sprintf("panel rows with visits: %.1f%% (address-parse ceiling; unmatched dropped)\n",
            100 * cov))
mm2 <- mm2[!is.na(visits)][, logVisits := log(visits)]

# 代理间共线性 / how collinear are the three proxies?
cors <- mm2[, .(r_visits_BN = cor(logVisits, logBN),
                r_visits_BT = cor(logVisits, logBT))]
print(cors, digits = 3)

## ---- 3. 作者规格 + 各努力代理 / authors' specification with each proxy ------
CTRL <- "Temp + Wind + Pop + Duration + Carbon + Water + Green + Farm + Grass"
run1 <- function(rhs, dat, label) {
  f <- feols(as.formula(paste("ShannonBD ~", rhs, "| county + ym")),
             dat, cluster = ~county, fixef.rm = "singletons")
  data.table(label, beta_PI = coef(f)["PI"], se = se(f)["PI"],
             p = pvalue(f)["PI"], N = nobs(f))
}
res <- rbind(
  run1(paste("PI +", CTRL), mm2,
       "Authors' spec, visits-covered subsample (baseline)"),
  run1(paste("PI + logVisits +", CTRL), mm2,
       "+ ln(checklists)  [visit-count proxy]"),
  run1(paste("PI + logVisits +", CTRL), mm2[PI_was_imputed == FALSE],
       "+ ln(checklists), policy-documented counties"),
  run1(paste("PI + logBN + logBT + logVisits +", CTRL), mm2,
       "+ ln(birdwatchers) + ln(hours) + ln(checklists)  [all three]"))
res[, pct_per_sd := 100 * beta_PI * sd(m$PI) / mean(m$ShannonBD)]
fwrite(cbind(res, cors), file.path(out, "visits_robustness.csv"))
cat("\n=== Visit-count effort proxy (authors' specification) ===\n")
print(res, digits = 3)
