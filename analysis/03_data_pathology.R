# ============================================================
# Scientific question / 科学问题:
# (1) Do the three impossible count records flagged by the China
#     Ornithological Society (e.g., 2,147,483,647 little egrets) leave
#     detectable signatures in the authors' county-month Shannon panel?
#     鸟类学分会指出的三条不可能计数记录(如 21.47 亿只白鹭)是否在
#     作者的县-月 Shannon 面板中留下可检测的痕迹?
# (2) How badly does the Shannon index misbehave when computed from
#     checklist-style (all-counts-equal-1) citizen records and when a
#     single large waterbird flock dominates a county-month?
#     当香农指数由"清单型"记录(计数全为 1)计算、或单一大群水鸟
#     主导县-月时,指数会失真到什么程度?
#
# Input / 输入: output/panel_master.rds; DATA/Bird.dta
# Output / 输出: output/pathology_cases.csv, output/simulation_shannon.csv
#
# Key assumptions / 关键假设:
# - True community: lognormal abundance, S species. 真群落为对数正态丰度。
# - Detection: species detected with prob increasing in effort.
#   检测概率随努力增加(种-面积/清单长度机制)。
# Main packages / 主要包: data.table
# ============================================================

suppressPackageStartupMessages({library(data.table); library(haven)})
set.seed(42)  # 可复现 / reproducibility

base <- "/Users/dingchenchen/Documents/能源转型与生态保护"
out  <- file.path(base, "output")
m    <- readRDS(file.path(out, "panel_master.rds"))

## ---- 1. 错误记录县-月的痕迹 / signatures of the corrupt records ----------
# 三条记录 / three flagged records:
#  a) 白鹭 2,147,483,647 (int32 max), 江门市新会区, 2015-03
#  b) 白鹭 6,111,141, 广州市荔湾区, 2022-04
#  c) 红嘴蓝鹊 1,333,333,333, 广州市越秀区, 2022-05
cases <- rbind(
  data.table(city = "江门市", county = "新会区", ym = "2015-03", record = "Egretta garzetta n=2,147,483,647 (int32 max)"),
  data.table(city = "广州市", county = "荔湾区", ym = "2022-04", record = "Egretta garzetta n=6,111,141"),
  data.table(city = "广州市", county = "越秀区", ym = "2022-05", record = "Urocissa erythroryncha n=1,333,333,333"))

hits <- m[cases, on = c(市 = "city", 县 = "county", ymkey = "ym"),
          .(市, 县, ymkey, record = i.record, ShannonBD, SimpsonBD, Richness, BN, BT, PI)]
fwrite(hits, file.path(out, "pathology_cases.csv"))
cat("=== County-months containing the flagged records (in regression sample) ===\n")
print(hits, digits = 4)

# 这些县月的 Shannon 若接近 0(p_i -> 1),证明污染进入了因变量
# If Shannon ~ 0 in these rich urban/wetland county-months, corruption
# propagated into the dependent variable.
neigh <- m[市 == "江门市" & 县 == "新会区" & YEAR %in% 2014:2016,
           .(ymkey, ShannonBD, Richness, BN)][order(ymkey)]
cat("\n=== Xinhui (Jiangmen) 2014-2016 context ===\n"); print(neigh, digits = 3)

## ---- 2. 全数据中的"病态低 Shannon"扫描 / pathological low-H scan ---------
# 高丰富度但 Shannon 极低 = 单一天文数字计数压垮指数的签名
# High richness with near-zero Shannon flags a single dominant count.
patho <- m[Richness >= 20 & ShannonBD < 0.2,
           .(省, 市, 县, ymkey, ShannonBD, Richness, BN)][order(ShannonBD)]
cat(sprintf("\nCounty-months with >=20 species but Shannon<0.2: %d\n", nrow(patho)))
print(head(patho, 12), digits = 3)
fwrite(patho, file.path(out, "pathology_scan.csv"))

## ---- 3. 模拟:清单型与大群对 Shannon 的失真 / simulation ------------------
# 真群落 / true community: S = 60 species, lognormal abundance
S <- 60
true_ab <- sort(rlnorm(S, meanlog = 4, sdlog = 1.5), decreasing = TRUE)
p_true  <- true_ab / sum(true_ab)
H_true  <- -sum(p_true * log(p_true))

# 检测模型 / detection: each birder-hour samples individuals;
# species detected if >=1 individual seen. 努力 E 增大,检出种数饱和上升。
sim_one <- function(E, mode = c("counts", "checklist", "flock")) {
  mode <- match.arg(mode)
  # 期望检出:泊松抽样 / expected detections via Poisson sampling
  lam  <- p_true * E * 200          # 200 birds encountered per unit effort
  det  <- rpois(S, lam)
  obs  <- det[det > 0]
  if (length(obs) < 2) return(c(H = NA, S_obs = length(obs)))
  if (mode == "checklist") obs[] <- 1              # 清单型:计数全 1 / all counts = 1
  if (mode == "flock") obs[1] <- obs[1] + 2e4      # 单一 2 万只大群 / one 20k flock
  p <- obs / sum(obs)
  c(H = -sum(p * log(p)), S_obs = length(obs))
}

grid <- CJ(E = c(0.05, 0.1, 0.2, 0.5, 1, 2, 5, 10, 20), rep = 1:400)
sim  <- grid[, {
  a <- sim_one(E, "counts"); b <- sim_one(E, "checklist"); d <- sim_one(E, "flock")
  .(H_counts = a["H"], H_checklist = b["H"], H_flock = d["H"], S_obs = a["S_obs"])
}, by = .(E, rep)]

sim_sum <- sim[, .(H_counts = mean(H_counts, na.rm = TRUE),
                   H_checklist = mean(H_checklist, na.rm = TRUE),
                   H_flock = mean(H_flock, na.rm = TRUE),
                   S_obs = mean(S_obs, na.rm = TRUE)), by = E][order(E)]
sim_sum[, H_true := H_true]
fwrite(sim_sum, file.path(out, "simulation_shannon.csv"))
cat(sprintf("\nTrue Shannon = %.3f (S = %d)\n", H_true, S))
cat("=== Simulated observed Shannon by effort and recording mode ===\n")
print(sim_sum, digits = 3)
