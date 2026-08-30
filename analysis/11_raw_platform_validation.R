# ============================================================
# Scientific question / 科学问题:
# Final species-level verification against the RAW provincial xlsx
# delivery of the China Birdwatch platform (2025-05): (1) is the
# taxon_count column genuine per-species abundance? (2) what share of
# 2014-2023 checklists are true all-ones? (3) what is the count ceiling
# of this delivery, and are the astronomical records present?
# 对平台原始省级 xlsx 交付(2025-05)的最终物种级核验:(1) taxon_count
# 是否为真实的物种个体数?(2) 2014-2023 清单中真实"全1"占比多少?
# (3) 该交付版的计数上限是多少,天文数字记录是否存在?
# Input: /tmp/birdxlsx/*.xlsx (33 provincial files, sheets 1-3)
# Output: output/raw_platform_validation.csv (+ per-year table)
# ============================================================
suppressPackageStartupMessages({library(readxl); library(data.table)})
# 平台原始省级交付的"鸟种数据"目录 / species-data folder of the raw delivery:
#   默认路径为 data_raw/ 下解压 china_birdwatch_dataset_2024_delivery.rar 所得;
#   或通过环境变量 BIRDWATCH_XLSX_DIR 指定。
#   Default: unpack china_birdwatch_dataset_2024_delivery.rar (release data-v1)
#   under data_raw/; alternatively set BIRDWATCH_XLSX_DIR.
xdir <- file.path("data_raw", "china_birdwatch_dataset_2024_delivery",
                  "中国观鸟数据集", "鸟种数据")
if (!dir.exists(xdir)) xdir <- Sys.getenv("BIRDWATCH_XLSX_DIR", "")
if (!dir.exists(xdir)) stop(
  "Species-data folder not found. Download china_birdwatch_dataset_2024_delivery.rar\n",
  "from the repository release (data-v1), unpack it under data_raw/, or set the\n",
  "BIRDWATCH_XLSX_DIR environment variable to the 鸟种数据 folder.")
files <- list.files(xdir, full.names = TRUE, pattern = "xlsx$")
res <- list()
for (f in files) {
  pv <- gsub("\\.xlsx$", "", basename(f))
  shs <- tryCatch(excel_sheets(f), error = function(e) character(0))
  sp <- rbindlist(lapply(shs, function(s)
    tryCatch(as.data.table(read_xlsx(f, sheet = s,
      col_types = c("numeric","numeric","numeric","text","numeric","text","text","text")))[
      , .(serial_id, taxon_count)],
      error = function(e) NULL)), fill = TRUE)
  if (!nrow(sp)) next
  sp <- sp[!is.na(serial_id)]
  sp[, yr := as.integer(serial_id %/% 1e9)]
  ev <- sp[, .(n_sp = .N, all_one = all(taxon_count == 1, na.rm = TRUE),
               n_uniq = uniqueN(taxon_count),
               const_eq_nsp = uniqueN(taxon_count) == 1L && taxon_count[1] == .N,
               yr = yr[1]), by = serial_id]
  res[[pv]] <- data.table(province = pv, rows = nrow(sp), checklists = nrow(ev),
    na_share = mean(is.na(sp$taxon_count)), max_count = max(sp$taxon_count, na.rm = TRUE),
    n_ge_1e5 = sp[taxon_count >= 1e5, .N],
    allone = mean(ev$all_one),
    semleak = ev[n_sp >= 5, mean(const_eq_nsp)],
    yr_min = min(ev$yr), yr_max = max(ev$yr))
  cat(pv, nrow(sp), "rows |", nrow(ev), "lists | max", max(sp$taxon_count, na.rm=TRUE),
      "| all-one:", round(res[[pv]]$allone, 3), "| yrs", res[[pv]]$yr_min, "-", res[[pv]]$yr_max, "\n")
}
tab <- rbindlist(res, fill = TRUE)
fwrite(tab, "output/raw_platform_validation.csv")
cat("\n=== NATIONAL SUMMARY (raw 2024 delivery) ===\n")
cat("provinces:", nrow(tab), "| total rows:", sum(tab$rows),
    "| checklists:", sum(tab$checklists), "\n")
cat("weighted all-ones share:", round(sum(tab$allone * tab$checklists) / sum(tab$checklists), 4), "\n")
cat("max count anywhere:", max(tab$max_count), "| records >=1e5:", sum(tab$n_ge_1e5), "\n")
cat("NA share overall:", round(sum(tab$na_share * tab$rows) / sum(tab$rows), 6), "\n")
cat("semantic-leak share (const==n_sp), national max:", round(max(tab$semleak, na.rm=TRUE), 5), "\n")
