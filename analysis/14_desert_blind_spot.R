# ============================================================
# Scientific question / 科学问题:
# Zhang et al. (2026) report that the PSI-diversity association is
# "not significant" in sandy/gravel-desert and Three-North counties
# (their Table S17), and this null is now read as support for siting
# gigawatt-scale solar in drylands. Is the desert null an informative
# absence of effect, or an artefact of (i) thin observation coverage,
# (ii) low statistical power, and (iii) the same effort confounding
# that drives the national estimate?
# Zhang et al. (2026) 报告荒漠/三北亚组的 PSI-多样性关联"不显著"(表 S17),
# 该零结果正被解读为"沙戈荒大基地选址安全"的依据。这一零结果是有信息量的
# "无效应",还是 (i) 观测覆盖稀薄、(ii) 检验力不足、(iii) 与全国估计同源的
# 努力混杂共同造成的伪影?
#
# Objective / 分析目标:
# 1. Replicate Table S17 columns (3)-(6) exactly and run the
#    between-group difference test the authors commented out (bdiff).
#    精确复现表 S17 第(3)-(6)列,并补做作者注释掉的组间差异检验。
# 2. Quantify observation coverage in desert vs non-desert counties.
#    量化荒漠与非荒漠县的观测覆盖差异。
# 3. Re-estimate the desert subgroup under explicit effort adjustment,
#    data cleaning and the policy-source restriction (same grid as 05).
#    在显式努力校正、数据清洗、政策源限制下重估荒漠亚组(沿用 05 的网格)。
# 4. Power, minimum detectable effect and equivalence (TOST) bounds for
#    the desert subgroup. 荒漠亚组的检验力、最小可检测效应与等价检验边界。
# 5. Record-level check: what the desert outcome variable is made of,
#    and how thinly desert-specialist birds are recorded.
#    记录级核验:荒漠县的因变量由哪些物种构成,荒漠特化种记录有多稀薄。
#
# Input / 输入:
#   output/panel_master.rds (script 01); output/table1_replication.csv;
#   original_replication/extracted/DATA/{Gebi,north_region}.dta;
#   data_raw/birdwatch_event_table_2000_2025.csv.gz (record-level,
#   optional); county boundary shapefile (optional, env CHINA_COUNTY_SHP).
# Output / 输出: output/desert_*.csv, output/county_effort_map.csv
# Key assumptions / 关键假设:
#   - desert_gobi (county) and north_region (province) flags are taken
#     verbatim from the authors' package. 亚组标识完全沿用作者文件。
#   - % effects use the national conversion (sd(PSI), mean H of the full
#     sample) so they are comparable with the headline -2.10%.
#     百分比效应用全样本换算,与 -2.10% 口径一致。
#   - Record-level checks use the platform source only (as in script 10),
#     matching the authors' data source. 记录级核验仅用观鸟平台来源。
#   - The desert-specialist list is expert-defined and provisional.
#     荒漠特化种名单为专家判定的暂定名单。
# Main packages / 主要包: data.table, fixest, haven, sf
# ============================================================

suppressPackageStartupMessages({
  library(data.table); library(fixest); library(haven)
})

# 从仓库根目录运行本脚本 / run this script from the repository root
base <- "."
out  <- file.path(base, "output")
dta  <- file.path(base, "original_replication/extracted/DATA")

m  <- readRDS(file.path(out, "panel_master.rds"))
gb <- as.data.table(read_dta(file.path(dta, "Gebi.dta")))         # county flag
nr <- as.data.table(read_dta(file.path(dta, "north_region.dta"))) # province flag
m  <- merge(m, gb[, .(id, desert_gobi)], by = "id", all.x = TRUE)
m[is.na(desert_gobi), desert_gobi := 0]
m[, north := as.integer(省 %in% nr$省)]
m[, lnRich := log(Richness)]
# 污染县-月规则与 05 一致 / corrupted-row rule, identical to script 05
m[, corrupted := !is.na(Richness) &
    ((Richness >= 20 & ShannonBD < 0.2) | (Richness >= 2 & ShannonBD < 1e-3))]

CTRL  <- "Temp + Wind + Pop + Duration + Carbon + Water + Green + Farm + Grass"
sd_pi <- sd(m$PI); mn_H <- mean(m$ShannonBD)          # national conversion
to_pct <- function(b, outcome = "ShannonBD") {
  if (outcome == "lnRich") 100 * b * sd_pi else
    100 * b * sd_pi / c(ShannonBD = mn_H, SimpsonBD = mean(m$SimpsonBD))[outcome]
}

## ---- 1. Replicate Table S17 (3)-(6) + difference tests / 复现与组间检验 ----
fit_sub <- function(d, rhs = paste("PI +", CTRL), outcome = "ShannonBD") {
  feols(as.formula(paste(outcome, "~", rhs, "| county + ym")), data = d,
        cluster = ~county, fixef.rm = "singletons")
}
tidy_pi <- function(f, ...) data.table(..., coef = unname(coef(f)["PI"]),
                                       se = unname(se(f)["PI"]),
                                       p = unname(pvalue(f)["PI"]), N = nobs(f))

rep17 <- rbind(
  tidy_pi(fit_sub(m[north == 0]),       split = "Three-North", group = "Non-Three-North"),
  tidy_pi(fit_sub(m[north == 1]),       split = "Three-North", group = "Three-North"),
  tidy_pi(fit_sub(m[desert_gobi == 0]), split = "Desert",      group = "Non-desert"),
  tidy_pi(fit_sub(m[desert_gobi == 1]), split = "Desert",      group = "Sandy/gravel desert"))
rep17[, est_pct := to_pct(coef)]
rep17[, published := c(-0.0196, 0.0056, -0.0165, 0.0190)]   # Table S17 / 表 S17

# (a) z-test on separately fitted coefficients (what bdiff would report)
# (b) Wald test from a fully interacted pooled model with county-clustered
#     SEs and group-specific year-month FE. 完全交互的合并模型(组别×年月 FE)
diff_test <- function(flag) {
  s0 <- rep17[split == flag][1]; s1 <- rep17[split == flag][2]
  z  <- (s1$coef - s0$coef) / sqrt(s1$se^2 + s0$se^2)
  gvar <- if (flag == "Desert") "desert_gobi" else "north"
  d  <- copy(m)[, g := get(gvar)]
  ctrl_int <- paste(sprintf("%s * g", strsplit(CTRL, " \\+ ")[[1]]), collapse = " + ")
  fp <- feols(as.formula(paste("ShannonBD ~ PI * g +", ctrl_int, "| county + ym^g")),
              data = d, cluster = ~county, fixef.rm = "singletons")
  data.table(split = flag,
             diff = s1$coef - s0$coef, se_diff_z = sqrt(s1$se^2 + s0$se^2),
             z = z, p_z = 2 * pnorm(-abs(z)),
             diff_pooled = unname(coef(fp)["PI:g"]), se_pooled = unname(se(fp)["PI:g"]),
             p_pooled = unname(pvalue(fp)["PI:g"]), N_pooled = nobs(fp))
}
dtests <- rbind(diff_test("Three-North"), diff_test("Desert"))
fwrite(rep17,  file.path(out, "desert_subgroup_replication.csv"))
fwrite(dtests, file.path(out, "desert_subgroup_difftest.csv"))
cat("=== Table S17 replication (published in last column) ===\n"); print(rep17, digits = 4)
cat("\n=== Between-group difference tests ===\n"); print(dtests, digits = 4)

## ---- 2. Coverage and effort contrasts / 覆盖与努力对比 ----------------------
mreg <- m[, if (.N > 1) .SD, by = county]        # estimation-sample basis / 回归样本口径
cover <- function(d, lab, listed = NA_integer_) {
  d[, .(group = lab,
        counties_listed    = listed,
        counties_observed  = uniqueN(id),
        county_months      = .N,
        cm_per_county      = .N / uniqueN(id),
        median_months_obs  = as.numeric(median(table(id))),
        share_counties_le12= mean(table(id) <= 12),
        single_birder_share= mean(BN == 1),
        mean_birders       = mean(BN),
        birders_total      = sum(BN),
        sd_PI = sd(PI), share_PI_pos = mean(PI > 0), share_PI_imputed = mean(PI_was_imputed))]
}
cov <- rbind(cover(mreg[desert_gobi == 0], "Non-desert",          gb[desert_gobi == 0, .N]),
             cover(mreg[desert_gobi == 1], "Sandy/gravel desert", gb[desert_gobi == 1, .N]),
             cover(mreg[north == 0],       "Non-Three-North"),
             cover(mreg[north == 1],       "Three-North"))
cov[, share_of_county_months := county_months / nrow(mreg)]
cov[, share_of_birders := birders_total / sum(mreg$BN)]
fwrite(cov, file.path(out, "desert_coverage.csv"))
cat("\n=== Coverage (estimation sample) ===\n"); print(cov, digits = 3)

# 年度轨迹 / annual trajectories by desert flag
ann <- mreg[, .(county_months = .N, counties = uniqueN(id), birders = sum(BN),
                PI_mean = mean(PI), H_mean = mean(ShannonBD)), by = .(desert_gobi, YEAR)]
setorder(ann, desert_gobi, YEAR)
ann[, `:=`(birders_rel = birders / birders[1], cm_rel = county_months / county_months[1],
           PI_rel = PI_mean / PI_mean[1]), by = desert_gobi]
fwrite(ann, file.path(out, "desert_effort_annual.csv"))

# 县级汇总供制图 / county-level totals for the map (figure script)
cmap <- m[, .(desert_gobi = desert_gobi[1], north = north[1], 省 = 省[1], 县 = 县[1],
              county_months = .N, birders_total = sum(BN), months_observed = uniqueN(ymkey)),
          by = id]
fwrite(cmap, file.path(out, "county_effort_map.csv"))

## ---- 3. Desert subgroup under corrections / 校正后的荒漠亚组 ---------------
grid <- CJ(group = c("Sandy/gravel desert", "Non-desert"),
           sample = c("full", "policy_source"),
           cleaning = c("as_published", "drop_corrupted", "min2_birders"),
           outcome = c("ShannonBD", "lnRich", "SimpsonBD"),
           effort = c("authors", "explicit"))
run_spec <- function(group, sample, cleaning, outcome, effort) {
  d <- m[desert_gobi == as.integer(group == "Sandy/gravel desert")]
  if (sample == "policy_source")   d <- d[PI_was_imputed == FALSE]
  if (cleaning == "drop_corrupted") d <- d[corrupted == FALSE]
  if (cleaning == "min2_birders")   d <- d[BN >= 2 & corrupted == FALSE]
  rhs <- if (effort == "explicit") paste("PI + logBN + logBT +", CTRL) else paste("PI +", CTRL)
  f <- tryCatch(fit_sub(d, rhs, outcome), error = function(e) NULL)
  if (is.null(f)) return(NULL)
  tidy_pi(f, group = group, sample = sample, cleaning = cleaning,
          outcome = outcome, effort = effort)
}
specs <- rbindlist(Map(run_spec, grid$group, grid$sample, grid$cleaning,
                       grid$outcome, grid$effort), fill = TRUE)
specs[, est_pct := mapply(to_pct, coef, outcome)]
specs[, lo_pct  := mapply(to_pct, coef - 1.96 * se, outcome)]
specs[, hi_pct  := mapply(to_pct, coef + 1.96 * se, outcome)]
fwrite(specs, file.path(out, "desert_spec_grid.csv"))
sum_specs <- specs[, .(n = .N, sig_neg = sum(p < .05 & coef < 0),
                       sig_pos = sum(p < .05 & coef > 0), null = sum(p >= .05),
                       median_pct = median(est_pct)), by = .(group, effort)]
cat("\n=== Specification grid by group x effort ===\n"); print(sum_specs, digits = 3)

# 合并模型:努力校正后组间差异是否仍在 / pooled: does the gap survive effort terms?
ctrl_int <- paste(sprintf("%s * g", c(strsplit(CTRL, " \\+ ")[[1]], "logBN", "logBT")),
                  collapse = " + ")
dp <- copy(m)[, g := desert_gobi]
fp_eff <- feols(as.formula(paste("ShannonBD ~ PI * g +", ctrl_int, "| county + ym^g")),
                data = dp, cluster = ~county, fixef.rm = "singletons")
gap_eff <- data.table(model = "Desert x PSI gap, effort terms added (pooled, fully interacted)",
                      diff = unname(coef(fp_eff)["PI:g"]), se = unname(se(fp_eff)["PI:g"]),
                      p = unname(pvalue(fp_eff)["PI:g"]), N = nobs(fp_eff))
fwrite(gap_eff, file.path(out, "desert_gap_effort.csv"))
cat("\n=== Desert gap after effort terms ===\n"); print(gap_eff, digits = 4)

## ---- 4. Power, MDE, equivalence / 检验力、MDE、等价检验 --------------------
beta_pub <- -0.0125                                  # headline / 主效应
t1 <- fread(file.path(out, "table1_replication.csv"))[3]   # Table 1 col. (3)
pick <- function(g, s, cl, ef, lab)
  specs[group == g & sample == s & cleaning == cl & outcome == "ShannonBD" & effort == ef][
    , design := lab]
# 作者"沙戈荒"标识的省份构成,以及规划基地所在的西北五省子集
# provincial makeup of the authors' desert indicator, and the subset in the five
# north-western provinces where the desert bases are planned
NW <- c("新疆维吾尔自治区", "内蒙古自治区", "甘肃省", "青海省", "宁夏回族自治区")
dcomp <- mreg[desert_gobi == 1, .(counties = uniqueN(id), county_months = .N,
                                  birders = sum(BN)), by = 省][order(-county_months)]
# 名单口径(作者县表)与回归样本口径并列 / list basis alongside estimation-sample basis
listed <- gb[desert_gobi == 1, .(counties_listed = .N), by = 省]
dcomp <- merge(listed, dcomp, by = "省", all = TRUE)[order(-county_months)]
for (v in c("counties", "county_months", "birders")) set(dcomp, which(is.na(dcomp[[v]])), v, 0)
dcomp[, `:=`(share_county_months = county_months / sum(county_months),
             share_birders = birders / sum(birders),
             zone = fifelse(省 %chin% NW, "north-western arid belt",
                            fifelse(省 == "西藏自治区", "Tibetan Plateau", "other")))]
fwrite(dcomp, file.path(out, "desert_province_composition.csv"))
cat("\n=== Desert indicator by zone ===\n")
print(dcomp[, .(counties = sum(counties), county_months = sum(county_months),
                share_cm = sum(share_county_months), share_birders = sum(share_birders)), by = zone])
nw_a <- tidy_pi(fit_sub(m[desert_gobi == 1 & 省 %chin% NW]),
                design = "Desert, north-western arid belt, authors' specification")
nw_e <- tidy_pi(fit_sub(m[desert_gobi == 1 & 省 %chin% NW], paste("PI + logBN + logBT +", CTRL)),
                design = "Desert, north-western arid belt, + effort terms")
nw <- rbind(nw_a, nw_e)[, est_pct := to_pct(coef)][, .(design, coef, se, p, N, est_pct)]

pw <- rbind(
  data.table(design = "National, authors' specification", coef = t1$beta_PI, se = t1$se_PI,
             p = t1$p_PI, N = t1$N, est_pct = to_pct(t1$beta_PI)),
  pick("Non-desert", "full", "as_published", "authors",  "Non-desert, authors' specification"),
  pick("Non-desert", "full", "as_published", "explicit", "Non-desert, + effort terms"),
  pick("Sandy/gravel desert", "full", "as_published", "authors",  "Desert, authors' specification"),
  pick("Sandy/gravel desert", "full", "as_published", "explicit", "Desert, + effort terms"),
  pick("Sandy/gravel desert", "policy_source", "drop_corrupted", "explicit",
       "Desert, preferred corrected"),
  rep17[group == "Three-North"][, design := "Three-North, authors' specification"],
  fill = TRUE)[, .(design, coef, se, p, N, est_pct)]
pw <- rbind(pw[1:6], nw, pw[7])
pw[, MDE80_beta := 2.80 * se]                                  # (1.96 + 0.84) * SE
pw[, MDE80_pct  := to_pct(MDE80_beta)]
pw[, MDE80_vs_headline := MDE80_pct / 2.108]
pw[, power_headline := pnorm(abs(beta_pub) / se - 1.96)]      # power if true effect = -2.10%
# TOST: smallest symmetric margin for which equivalence to zero is supported
# 等价检验:能支持"等价于零"的最小对称边界 = 90% CI 的最大绝对端点
pw[, lo90 := coef - 1.645 * se][, hi90 := coef + 1.645 * se]
pw[, equiv_margin_pct := to_pct(pmax(abs(lo90), abs(hi90)))]
pw[, excludes_headline_95 := (coef - 1.96 * se) > beta_pub]
fwrite(pw, file.path(out, "desert_power.csv"))
cat("\n=== Power / MDE / equivalence ===\n"); print(pw, digits = 3)

# 检验力曲线数据 / power curves over true effect sizes (figure panel)
grid_eff <- seq(-8, 0, by = 0.05)                               # % per 1 s.d. PSI
pcurve <- pw[, .(true_pct = grid_eff,
                 power = pnorm(abs(grid_eff / 100 * mn_H / sd_pi) / se - 1.96)), by = design]
fwrite(pcurve, file.path(out, "desert_power_curve.csv"))

## ---- 5. Record-level composition / 记录级:荒漠因变量由什么构成 -------------
ev_file <- Sys.getenv("BIRDWATCH_EVENT_TABLE",
                      file.path(base, "data_raw/birdwatch_event_table_2000_2025.csv.gz"))
shp     <- Sys.getenv("CHINA_COUNTY_SHP",
                      "/Users/dingchenchen/Downloads/2019中国地图-审图号GS(2019)1822号/县（等积投影）.shp")
# 荒漠与戈壁特化种(暂定名单;拉丁名为主键,含同物异名)
# desert & gobi specialists (provisional; Latin name is the key, synonyms included)
specialists <- data.table(
  species    = c("Chlamydotis macqueenii", "Podoces biddulphi", "Podoces hendersoni",
                 "Bucanetes mongolicus", "Rhodospiza obsoleta", "Carpodacus stoliczkae",
                 "Syrrhaptes paradoxus", "Pterocles orientalis", "Oenanthe isabellina",
                 "Oenanthe deserti", "Curruca minula", "Lanius isabellinus",
                 "Alauda leucoptera", "Melanocorypha yeltoniensis",
                 "Calandrella acutirostris", "Emberiza buchanani"),
  species_cn = c("波斑鸨", "白尾地鸦", "黑尾地鸦", "蒙古沙雀", "巨嘴沙雀", "沙色朱雀",
                 "毛腿沙鸡", "黑腹沙鸡", "沙䳭", "漠䳭", "漠白喉林莺", "荒漠伯劳",
                 "白翅百灵", "黑百灵", "细嘴短趾百灵", "灰颈鹀"))
synonyms <- c("Rhodopechys obsoleta", "Carpodacus synoicus", "Sylvia minula",
              "Melanocorypha leucoptera")
spec_names <- c(specialists$species, synonyms)
fwrite(specialists, file.path(out, "desert_specialist_list.csv"))

if (file.exists(ev_file) && file.exists(shp)) {
  suppressPackageStartupMessages(library(sf))
  ev <- fread(cmd = paste("gzcat", shQuote(ev_file)),
              select = c("source", "event_id", "species", "species_cn", "longitude",
                         "latitude", "year"), showProgress = FALSE)
  # 仅平台来源、研究期 / platform source only (authors' data source), study years
  ev <- ev[source == "China_Birdwatch_Platform" & year >= 2014 & year <= 2023]
  pts <- unique(ev[!is.na(longitude) & !is.na(latitude), .(event_id, longitude, latitude)],
                by = "event_id")
  cty <- st_read(shp, quiet = TRUE)[, c("PAC")]
  sfp <- st_transform(st_as_sf(pts, coords = c("longitude", "latitude"), crs = 4326), st_crs(cty))
  j   <- st_join(sfp, cty, join = st_intersects, left = TRUE)
  pts[, id := as.integer(j$PAC)]
  pts <- merge(pts, gb[, .(id, desert_gobi)], by = "id", all.x = TRUE)
  ev  <- merge(ev, pts[, .(event_id, id, desert_gobi)], by = "event_id", all.x = TRUE)
  ev[, is_spec := species %chin% spec_names]
  cat(sprintf("\nRecord-level (platform): %s checklists 2014-2023; %.1f%% located in a county; %.1f%% of located fall in desert counties\n",
              format(uniqueN(ev$event_id), big.mark = ","), 100 * mean(!is.na(pts$id)),
              100 * mean(pts$desert_gobi == 1, na.rm = TRUE)))
  des <- ev[desert_gobi == 1]
  # (a) composition / 组成:荒漠县记录按物种(拉丁名主键)
  comp <- des[, .(species_cn = species_cn[1], records = .N, checklists = uniqueN(event_id)),
              by = species][order(-records)]
  comp[, share := records / sum(records)][, rank := .I]
  comp[, specialist := species %chin% spec_names]
  fwrite(comp, file.path(out, "desert_species_composition.csv"))
  # (b) specialist thinness / 特化种稀薄程度
  sp_year <- des[is_spec == TRUE, .(species_cn = species_cn[1], records = .N,
                                    checklists = uniqueN(event_id)), by = .(species, year)]
  fwrite(sp_year[order(species, year)], file.path(out, "desert_specialists_by_year.csv"))
  yr <- des[, .(checklists = uniqueN(event_id), counties = uniqueN(id),
                checklists_with_specialist = uniqueN(event_id[is_spec == TRUE])), by = year][order(year)]
  yr[, share_specialist_checklists := checklists_with_specialist / checklists]
  fwrite(yr, file.path(out, "desert_checklists_by_year.csv"))
  # (c) checklists per county-year, desert vs non-desert / 县-年清单密度对比
  dens <- ev[!is.na(desert_gobi), .(checklists = uniqueN(event_id)), by = .(desert_gobi, id, year)]
  dens_s <- dens[, .(mean_checklists_per_county_year = mean(checklists),
                     median_checklists_per_county_year = as.numeric(median(checklists)),
                     county_years = .N), by = desert_gobi]
  fwrite(dens_s, file.path(out, "desert_checklist_density.csv"))
  summ <- data.table(
    metric = c("desert checklists 2014-2023", "desert counties with >=1 checklist (of 329)",
               "share of desert records from specialists",
               "share of desert checklists with >=1 specialist",
               "specialist species recorded in desert counties (of 16)",
               "top-10 species share of desert records",
               "mean checklists per county-year, desert", "mean checklists per county-year, non-desert"),
    value = c(uniqueN(des$event_id), uniqueN(des$id), comp[specialist == TRUE, sum(share)],
              sum(yr$checklists_with_specialist) / sum(yr$checklists),
              comp[specialist == TRUE, .N], comp[1:10, sum(share)],
              dens_s[desert_gobi == 1, mean_checklists_per_county_year],
              dens_s[desert_gobi == 0, mean_checklists_per_county_year]))
  fwrite(summ, file.path(out, "desert_record_summary.csv"))
  cat("\n=== Desert record-level summary ===\n"); print(summ, digits = 3)
  cat("\nTop 12 species in desert-county records:\n"); print(comp[1:12], digits = 3)
  cat("\nSpecialists recorded in desert counties:\n")
  print(comp[specialist == TRUE, .(species, species_cn, records, checklists)])
} else {
  cat("\nRecord-level data or county shapefile not found; section 5 skipped.\n")
}
cat("\nScript 14 done.\n")
