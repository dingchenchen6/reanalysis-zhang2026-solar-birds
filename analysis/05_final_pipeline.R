# ============================================================
# Scientific question / 科学问题:
# After applying defensible data cleaning, appropriate diversity
# metrics, explicit observation-effort adjustment, and valid policy
# exposure, what is the estimated effect of solar-policy stringency
# on bird diversity — and how does it distribute across the full
# space of defensible analytical decisions (specification curve)?
# 在采用可辩护的数据清洗、合理指标、显式努力校正与有效政策暴露后,
# 光伏政策强度对鸟类多样性的效应估计是什么?该估计在全部可辩护
# 分析决策组合(规格曲线)中如何分布?
#
# Design / 设计 (fully crossed / 全交叉):
#   sample:   full panel | counties documented in policy source
#   cleaning: as published | drop corrupted county-months | require >=2 birders
#   outcome:  Shannon H | ln(species richness) | Simpson
#   effort:   authors' Duration only | + ln(birders) + ln(total hours)
#   => 2 x 3 x 3 x 2 = 36 core specifications, county-clustered TWFE
#   plus era splits and province clustering as sensitivity.
#
# Output / 输出:
#   output/spec_curve.csv          all specifications / 全部规格
#   output/final_estimate.csv      preferred corrected estimate / 首选校正估计
#   figures/Fig3_specification_curve.(pdf|png)
#
# Main packages / 主要包: data.table, fixest, ggplot2, patchwork
# ============================================================

suppressPackageStartupMessages({
  library(data.table); library(fixest); library(ggplot2); library(patchwork)
})

# 从仓库根目录运行本脚本 / run this script from the repository root:
#   Rscript analysis/<script>.R
base <- "."
out  <- file.path(base, "output"); figd <- file.path(base, "figures")
m    <- readRDS(file.path(out, "panel_master.rds"))

m[, lnRich := log(Richness)]
CTRL <- "Temp + Wind + Pop + Duration + Carbon + Water + Green + Farm + Grass"

# 污染县-月:高丰富度但 H 塌缩(单一天文计数签名)+ 已证实的溢出行
# Corrupted county-months: >=20 species with H<0.2 (single-huge-count
# signature) — includes the verified int32 egret row (Xinhui 2015-03).
# 污染行判定 / corrupted-row rule, two disjuncts:
#   (i)  S >= 20 且 H < 0.2:多物种却近乎零多样性,单一超大计数的签名;
#   (ii) S >= 2 且 H < 1e-3:近零熵,算术上要求单种计数达千万量级
#        (新会 2015-03 属此类,其 S = 4 不满足 (i))。
#   (i)  many species yet near-zero diversity: single-huge-count signature;
#   (ii) near-zero entropy with >= 2 species: arithmetically requires a
#        dominant count in the tens of millions (Xinhui 2015-03, S = 4).
m[, corrupted := !is.na(Richness) &
    ((Richness >= 20 & ShannonBD < 0.2) | (Richness >= 2 & ShannonBD < 1e-3))]
cat(sprintf("Corrupted county-months flagged: %d (rule i: %d, rule ii: %d)\n",
            m[corrupted == TRUE, .N],
            m[!is.na(Richness) & Richness >= 20 & ShannonBD < 0.2, .N],
            m[!is.na(Richness) & Richness >= 2 & ShannonBD < 1e-3, .N]))
cat(sprintf("Corrupted county-months flagged: %d\n", m[corrupted == TRUE, .N]))

grid <- CJ(sample   = c("full", "policy_source"),
           cleaning = c("as_published", "drop_corrupted", "min2_birders"),
           outcome  = c("ShannonBD", "lnRich", "SimpsonBD"),
           effort   = c("authors", "explicit"))

run_spec <- function(sample, cleaning, outcome, effort, clu = "county",
                     era = "all") {
  d <- copy(m)
  if (sample == "policy_source") d <- d[PI_was_imputed == FALSE]
  if (cleaning == "drop_corrupted") d <- d[corrupted == FALSE]
  if (cleaning == "min2_birders")   d <- d[BN >= 2 & corrupted == FALSE]
  if (era == "pre")  d <- d[YEAR <= 2019]
  if (era == "boom") d <- d[YEAR >= 2020]
  rhs <- if (effort == "explicit") paste("PI + logBN + logBT +", CTRL)
         else paste("PI +", CTRL)
  f <- tryCatch(feols(as.formula(paste(outcome, "~", rhs, "| county + ym")),
                      data = d, cluster = as.formula(paste0("~", clu)),
                      fixef.rm = "singletons"),
                error = function(e) NULL)
  if (is.null(f)) return(NULL)
  data.table(sample, cleaning, outcome, effort, cluster = clu, era,
             coef = coef(f)["PI"], se = se(f)["PI"], p = pvalue(f)["PI"],
             N = nobs(f))
}

specs <- rbindlist(Map(run_spec, grid$sample, grid$cleaning, grid$outcome,
                       grid$effort), fill = TRUE)

# 敏感性扩展:省聚类 + 时段(对首选规格族)/ sensitivity: province cluster & eras
extra <- rbindlist(list(
  run_spec("policy_source", "drop_corrupted", "ShannonBD", "explicit", "省"),
  run_spec("policy_source", "drop_corrupted", "lnRich",    "explicit", "省"),
  run_spec("full",          "drop_corrupted", "ShannonBD", "explicit", "county", era = "pre"),
  run_spec("full",          "drop_corrupted", "ShannonBD", "explicit", "county", era = "boom"),
  run_spec("full",          "drop_corrupted", "lnRich",    "explicit", "county", era = "boom")
), fill = TRUE)
specs_all <- rbind(specs, extra, fill = TRUE)

# 标准化效应(% of outcome mean per 1 SD PSI;lnRich 直接 %)/ standardized effect
sd_pi <- sd(m$PI)
mns <- c(ShannonBD = mean(m$ShannonBD), SimpsonBD = mean(m$SimpsonBD))
specs_all[, est_pct := fifelse(outcome == "lnRich",
                               100 * coef * sd_pi,
                               100 * coef * sd_pi / mns[outcome])]
specs_all[, lo_pct := fifelse(outcome == "lnRich",
                              100 * (coef - 1.96 * se) * sd_pi,
                              100 * (coef - 1.96 * se) * sd_pi / mns[outcome])]
specs_all[, hi_pct := fifelse(outcome == "lnRich",
                              100 * (coef + 1.96 * se) * sd_pi,
                              100 * (coef + 1.96 * se) * sd_pi / mns[outcome])]
fwrite(specs_all, file.path(out, "spec_curve.csv"))

## ---- 汇总 / summarise ------------------------------------------------------
core <- specs_all[era == "all" & cluster == "county"]
cat(sprintf("\nCore specifications: %d\n", nrow(core)))
cat(sprintf("  significant negative (P<0.05): %d\n", core[p < .05 & coef < 0, .N]))
cat(sprintf("  significant positive (P<0.05): %d\n", core[p < .05 & coef > 0, .N]))
cat(sprintf("  null (P>=0.05):                %d\n", core[p >= .05, .N]))
corrected <- core[effort == "explicit"]
cat(sprintf("\nAmong %d effort-corrected specs: %d null, %d sig-neg, %d sig-pos\n",
            nrow(corrected), corrected[p >= .05, .N],
            corrected[p < .05 & coef < 0, .N], corrected[p < .05 & coef > 0, .N]))
cat(sprintf("  median estimate = %.3f%% per 1 SD PSI; range [%.2f%%, %.2f%%]\n",
            median(corrected$est_pct), min(corrected$est_pct),
            max(corrected$est_pct)))

## 首选规格 / preferred estimate:
## 清洗 + 政策源样本 + 显式努力 + Shannon 与 lnRich
pref <- specs_all[sample == "policy_source" & cleaning == "drop_corrupted" &
                    effort == "explicit" & era == "all" & cluster == "county"]
fwrite(pref, file.path(out, "final_estimate.csv"))
cat("\n=== Preferred corrected estimates ===\n"); print(pref, digits = 3)

## ---- Fig 3: specification curve / 规格曲线 --------------------------------
OI <- c(blue = "#0072B2", orange = "#E69F00", red = "#D55E00", grey = "#7F7F7F")
thm <- theme_classic(base_size = 7.2, base_family = "Helvetica") +
  theme(axis.text = element_text(size = 6.2, colour = "black"),
        axis.title = element_text(size = 7.2),
        plot.title = element_text(size = 7.8, face = "bold"),
        plot.subtitle = element_text(size = 6.4, colour = "grey25"),
        plot.tag = element_text(size = 9, face = "bold"),
        axis.line = element_line(linewidth = 0.35),
        axis.ticks = element_line(linewidth = 0.35))

sc <- copy(core)[order(est_pct)]
sc[, rank := .I]
sc[, sig := fifelse(p < .05, "P < 0.05", "P ≥ 0.05")]
sc[, published := sample == "full" & cleaning == "as_published" &
     outcome == "ShannonBD" & effort == "authors"]

pTop <- ggplot(sc, aes(rank, est_pct)) +
  geom_hline(yintercept = 0, linetype = 2, linewidth = 0.35, colour = "grey50") +
  geom_hline(yintercept = -2.108, linetype = 3, linewidth = 0.35, colour = OI["red"]) +
  annotate("text", x = 35.5, y = -2.7, label = "headline −2.10%", size = 2.1,
           colour = OI["red"], hjust = 1) +
  geom_errorbar(aes(ymin = lo_pct, ymax = hi_pct, colour = sig), width = 0,
                linewidth = 0.4, alpha = 0.85) +
  geom_point(aes(colour = sig), size = 1.15) +
  geom_point(data = sc[published == TRUE], shape = 1, size = 2.6,
             colour = "black", stroke = 0.5) +
  annotate("segment", x = sc[published == TRUE, rank], y = -5.6,
           xend = sc[published == TRUE, rank], yend = -2.9,
           linewidth = 0.3, colour = "grey20",
           arrow = arrow(length = unit(1.4, "mm"))) +
  annotate("text", x = sc[published == TRUE, rank], y = -6.3,
           label = "published specification", size = 2.1, colour = "grey20") +
  scale_colour_manual(values = c("P < 0.05" = unname(OI["red"]),
                                 "P ≥ 0.05" = "grey55"), name = NULL) +
  labs(tag = "A", x = NULL,
       y = "Effect of 1 s.d. PSI\n(% of outcome mean, 95% CI)",
       title = "Thirty-six defensible analysis paths: the published one is the outlier",
       subtitle = "Sample × cleaning × metric × effort adjustment, all with county + year-month FE, county-clustered") +
  thm + theme(legend.position = c(0.985, 0.05), legend.justification = c(1, 0),
              legend.key.size = unit(0.3, "cm"),
              legend.text = element_text(size = 6),
              legend.background = element_blank(),
              axis.text.x = element_blank(), axis.ticks.x = element_blank())

# 决策矩阵 / decision matrix
dm <- melt(sc[, .(rank,
                  `Policy-source counties` = sample == "policy_source",
                  `Corrupted rows dropped` = cleaning != "as_published",
                  `≥ 2 birders` = cleaning == "min2_birders",
                  `Explicit effort terms` = effort == "explicit",
                  `Outcome: Shannon` = outcome == "ShannonBD",
                  `Outcome: log richness` = outcome == "lnRich",
                  `Outcome: Simpson` = outcome == "SimpsonBD")],
           id.vars = "rank")
dm[, variable := factor(variable, levels = rev(levels(variable)))]

pBot <- ggplot(dm[value == TRUE], aes(rank, variable)) +
  geom_point(shape = 15, size = 1.5, colour = "grey25") +
  scale_x_continuous(limits = range(sc$rank), expand = expansion(add = 0.6)) +
  labs(tag = "B", x = "Specifications, ordered by estimate", y = NULL) +
  thm + theme(axis.line.y = element_blank(), axis.ticks.y = element_blank(),
              axis.text.y = element_text(size = 5.8))

fig3 <- pTop / pBot + plot_layout(heights = c(1.9, 0.85))
ggsave(file.path(figd, "Fig3_specification_curve.pdf"), fig3,
       width = 18.3, height = 10.5, units = "cm", device = cairo_pdf)
ggsave(file.path(figd, "Fig3_specification_curve.png"), fig3,
       width = 18.3, height = 10.5, units = "cm", dpi = 600)
cat("\nFig 3 written.\n")


## ---- 投稿版 fig. S1(去叙述性标题)/ submission version --------------------
figS1 <- fig3 & labs(title = NULL, subtitle = NULL)
subfig <- file.path(base, "submission/figures")
ggsave(file.path(subfig, "FigS1.pdf"), figS1, width = 18.3, height = 11.4,
       units = "cm", device = cairo_pdf)
ggsave(file.path(subfig, "FigS1.png"), figS1, width = 18.3, height = 11.4,
       units = "cm", dpi = 600)
cat("submission FigS1 written\n")
