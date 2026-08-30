# ============================================================
# Scientific question / 科学问题:
# Species-level verification using the record-level China Birdwatch
# platform data that I hold through the new-records-mechanism project:
# (1) what share of checklists are "all-ones" (no abundance info),
#     platform-wide and within the paper's 2014-2023 window?
# (2) can the three impossible records reported by the Ornithological
#     Society be located directly, and how many extreme counts exist?
# (3) when county-month Shannon is recomputed from records under a
#     minimal QC protocol, how far does it move from the paper's
#     dependent variable?
# 用我在新纪录机制项目中持有的记录级观鸟平台数据做物种级核验:
# (1) "全1清单"占比(平台层面与论文时间窗内);
# (2) 分会披露的三条不可能记录能否直接定位,极端计数共有多少;
# (3) 按最低限度质控协议从记录重算县-月 Shannon,与论文因变量差多远。
#
# Input / 输入: table_combined_occurrence_events_2000_2025.csv.gz
#               original_replication DATA/Bird.dta (作者县-月指数)
# Output / 输出: output/species_validation_summary.csv,
#               output/extreme_counts.csv, output/checklist_type_share.csv,
#               output/recomputed_vs_published.csv
# Main packages / 主要包: data.table, haven
# ============================================================

suppressPackageStartupMessages({ library(data.table); library(haven) })
setDTthreads(4)

# 从仓库根目录运行本脚本 / run this script from the repository root:
#   Rscript analysis/<script>.R
base <- "."
out  <- file.path(base, "output")
# 记录级事件表 / record-level event table:
#   默认读 data_raw/(从仓库 Release data-v1 下载后放置);
#   或通过环境变量 BIRDWATCH_EVENT_TABLE 指定其他位置。
#   Default: data_raw/ (download from the repository release data-v1);
#   alternatively set the BIRDWATCH_EVENT_TABLE environment variable.
F <- file.path(base, "data_raw", "birdwatch_event_table_2000_2025.csv.gz")
if (!file.exists(F)) F <- Sys.getenv("BIRDWATCH_EVENT_TABLE", "")
if (!file.exists(F)) stop(
  "Event table not found. Download birdwatch_event_table_2000_2025.csv.gz\n",
  "from the repository release (data-v1) into data_raw/, or set the\n",
  "BIRDWATCH_EVENT_TABLE environment variable to its full path.")

## ---- 1. 读取记录级数据(仅观鸟平台源)/ load record-level platform data ----
cols <- c("source","event_id","species","species_cn","year","month",
          "duration_min","taxon_count_event","individual_count",
          "username","address")
d <- fread(cmd = paste("gzcat", shQuote(F)), select = cols, showProgress = FALSE)
d <- d[source == "China_Birdwatch_Platform"]
cat(sprintf("platform rows: %s | events: %s | years %d-%d\n",
            format(nrow(d), big.mark=","), format(uniqueN(d$event_id), big.mark=","),
            min(d$year), max(d$year)))

## ---- 2. 极端计数扫描 / extreme-count scan ----------------------------------
ext <- d[individual_count >= 1e5,
         .(species, species_cn, individual_count, year, month, address = substr(address,1,40))][
         order(-individual_count)]
fwrite(ext, file.path(out, "extreme_counts.csv"))
cat(sprintf("\ncounts >=1e5: %d rows; >=1e6: %d; int32-max hits: %d\n",
            nrow(ext), d[individual_count >= 1e6, .N],
            d[individual_count == 2147483647, .N]))
cat("top extreme counts:\n")
print(head(ext, 8))

## ---- 3. 清单型占比 / all-ones checklist share ------------------------------
ev <- d[, .(n_sp = .N, all_ones = all(individual_count == 1),
            year = year[1], month = month[1]), by = event_id]
share_all   <- ev[, mean(all_ones)]
share_paper <- ev[year %between% c(2014, 2023), mean(all_ones)]
by_year <- ev[, .(events = .N, all_ones_share = mean(all_ones)), by = year][order(year)]
fwrite(by_year, file.path(out, "checklist_type_share.csv"))
cat(sprintf("\nall-ones checklists: %.1f%% platform-wide; %.1f%% within 2014-2023\n",
            100*share_all, 100*share_paper))
print(by_year[year %between% c(2014, 2023)])

## ---- 4. 县解析与县-月指数重算 / parse county, recompute county-month H -----
bird <- as.data.table(read_dta(file.path(base,
        "original_replication/extracted/DATA/Bird.dta")))
bird[, ymkey := as.character(标准年月)]
cties <- unique(bird[, .(县)])$县
cties <- cties[order(-nchar(cties))]                 # 长名优先防误配
ua <- unique(d[, .(address)])
ua[, county := NA_character_]
# 分块匹配:长县名优先,首个命中即取 / chunked regex match, longest names first
for (ck in split(cties, ceiling(seq_along(cties)/400))) {
  idx <- which(is.na(ua$county))
  if (!length(idx)) break
  mm <- regexpr(paste(ck, collapse = "|"), ua$address[idx])
  got <- mm > 0
  ua$county[idx[got]] <- substring(ua$address[idx][got], mm[got],
                                   mm[got] + attr(mm, "match.length")[got] - 1)
}
cat(sprintf("\naddress strings: %d; matched to a county: %.1f%%\n",
            nrow(ua), 100*mean(!is.na(ua$county))))
d <- merge(d, ua, by = "address", all.x = TRUE)

dd <- d[!is.na(county) & year %between% c(2014, 2023)]
dd[, ymkey := sprintf("%d-%02d", year, month)]
# 原样重算(含清单型与极端值)/ recompute as-is
h_all <- dd[, .(n = sum(individual_count)), by = .(county, ymkey, species)][
  , .(S_rec = .N, H_rec = { p <- n/sum(n); -sum(p*log(p)) }), by = .(county, ymkey)]
# 质控协议:剔清单型清单 + 计数上限 1e5 / minimal QC: drop all-ones lists, cap 1e5
ev_ok <- ev[all_ones == FALSE, event_id]
dq <- dd[event_id %in% ev_ok & individual_count < 1e5]
h_qc <- dq[, .(n = sum(individual_count)), by = .(county, ymkey, species)][
  , .(H_qc = { p <- n/sum(n); -sum(p*log(p)) }), by = .(county, ymkey)]

cmpr <- merge(bird[, .(county = 县, ymkey, H_pub = ShannonBD)],
              h_all, by = c("county", "ymkey"))
cmpr <- merge(cmpr, h_qc, by = c("county", "ymkey"), all.x = TRUE)
fwrite(cmpr, file.path(out, "recomputed_vs_published.csv"))
sm <- data.table(
  metric = c("platform rows (2014-2023, county-matched)",
             "county-months matched to published panel",
             "cor(H recomputed as-is, H published)",
             "cor(H after minimal QC, H published)",
             "median |H_qc - H_pub|",
             "share all-ones checklists 2014-2023",
             "records with count >= 1e6",
             "records at int32 maximum"),
  value = c(nrow(dd), nrow(cmpr),
            round(cor(cmpr$H_rec, cmpr$H_pub, use = "complete.obs"), 3),
            round(cor(cmpr$H_qc,  cmpr$H_pub, use = "complete.obs"), 3),
            round(cmpr[, median(abs(H_qc - H_pub), na.rm = TRUE)], 3),
            round(100*share_paper, 1),
            d[individual_count >= 1e6, .N],
            d[individual_count == 2147483647, .N]))
fwrite(sm, file.path(out, "species_validation_summary.csv"))
cat("\n=== summary ===\n"); print(sm)
