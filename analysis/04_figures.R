# ============================================================
# Scientific question / 科学问题:
# Communicate, at Science Technical Comment standard, that (Fig 1) the
# county-month Shannon panel measures the observation process rather
# than bird communities, and (Fig 2) the headline policy effect
# vanishes under effort correction and is negligible in magnitude.
# 用两张顶刊级组图呈现:(图1) 县-月香农面板度量的是观测过程而非
# 鸟类群落;(图2) 主效应在努力校正后消失且量级可忽略。
#
# Input / 输入: output/*.csv, output/panel_master.rds
# Output / 输出: figures/Fig1_observation_process.(pdf|png),
#                figures/Fig2_effect_fragility.(pdf|png)
#
# Design / 设计: Okabe-Ito colour-blind-safe palette, Arial 6-8 pt,
# Science double-column width 18.3 cm. 色盲友好配色,双栏宽 18.3 cm。
# Main packages / 主要包: ggplot2, patchwork, data.table, scales
# ============================================================

suppressPackageStartupMessages({
  library(data.table); library(ggplot2); library(patchwork); library(scales)
})

# 从仓库根目录运行本脚本 / run this script from the repository root:
#   Rscript analysis/<script>.R
base <- "."
out  <- file.path(base, "output"); figd <- file.path(base, "figures")
m    <- readRDS(file.path(out, "panel_master.rds"))

# Okabe-Ito / 色盲安全色
OI <- c(blue = "#0072B2", orange = "#E69F00", green = "#009E73",
        red = "#D55E00", purple = "#CC79A7", sky = "#56B4E9", grey = "#7F7F7F")

thm <- theme_classic(base_size = 7.2, base_family = "Helvetica") +
  theme(axis.text = element_text(size = 6.2, colour = "black"),
        axis.title = element_text(size = 7.2),
        plot.title = element_text(size = 7.8, face = "bold", hjust = 0),
        plot.subtitle = element_text(size = 6.4, colour = "grey25"),
        legend.text = element_text(size = 6.2), legend.title = element_blank(),
        legend.key.size = unit(0.32, "cm"),
        plot.tag = element_text(size = 9, face = "bold"),
        axis.line = element_line(linewidth = 0.35),
        axis.ticks = element_line(linewidth = 0.35))

## ================= FIGURE 1 =================================================

## ---- Panel A: effort explosion vs policy / 努力爆发与政策同步 -------------
ann <- fread(file.path(out, "effort_annual.csv"))
annL <- melt(ann[, .(YEAR,
                     `Birdwatchers (sum of county-month counts)` = BN_total / BN_total[1],
                     `County-months observed` = county_months / county_months[1],
                     `Mean policy-stringency index (PSI)` = PI_mean / PI_mean[1],
                     `Mean observed Shannon H` = Shannon_mean / Shannon_mean[1])],
             id.vars = "YEAR")
pA <- ggplot(annL, aes(YEAR, value, colour = variable)) +
  geom_hline(yintercept = 1, linetype = 3, linewidth = 0.3, colour = "grey60") +
  geom_line(linewidth = 0.55) + geom_point(size = 0.9) +
  scale_y_log10(breaks = c(1, 3, 10, 30, 100),
                labels = c("×1", "×3", "×10", "×30", "×100")) +
  scale_x_continuous(breaks = seq(2014, 2023, 3)) +
  scale_colour_manual(values = unname(OI[c("red", "orange", "blue", "green")])) +
  annotate("text", x = 2021.8, y = 60, label = "×171", size = 2.4,
           colour = OI["red"], fontface = "bold") +
  labs(tag = "D", x = NULL, y = "Change since 2014 (log scale)",
       title = "Birdwatching effort exploded in step with policy",
       subtitle = "Sample used by Zhang et al.; all series indexed to 2014 = 1") +
  thm + theme(legend.position = c(0.02, 0.99), legend.justification = c(0, 1),
              legend.background = element_blank())

## ---- Panel B: diversity is an effort curve / 观测多样性是努力的函数 --------
# 与回归口径一致:剔除单观测县(reghdfe singleton)/ align with regression sample
mreg <- m[, if (.N > 1) .SD, by = county]
mreg[, BN_bin := cut(BN, c(0, 1, 2, 3, 5, 10, 20, 50, 100, Inf),
                  labels = c("1", "2", "3", "4–5", "6–10", "11–20",
                             "21–50", "51–100", ">100"))]
sat <- mreg[, .(H = mean(ShannonBD), Hlo = mean(ShannonBD) - sd(ShannonBD),
             Hhi = mean(ShannonBD) + sd(ShannonBD),
             S = mean(Richness, na.rm = TRUE), n = .N), by = BN_bin][order(BN_bin)]
sat[, x := as.integer(BN_bin)]
share1 <- sprintf("%.1f%%", 100 * mean(mreg$BN == 1))

pB <- ggplot(sat, aes(x)) +
  geom_ribbon(aes(ymin = Hlo, ymax = Hhi), fill = OI["blue"], alpha = 0.15) +
  geom_line(aes(y = H, colour = "Shannon H"), linewidth = 0.6) +
  geom_point(aes(y = H, colour = "Shannon H"), size = 1) +
  geom_line(aes(y = S / 40, colour = "Species richness"), linewidth = 0.6) +
  geom_point(aes(y = S / 40, colour = "Species richness"), size = 1) +
  scale_y_continuous(name = "Observed Shannon H (county-month)",
                     sec.axis = sec_axis(~ . * 40, name = "Observed species richness")) +
  scale_x_continuous(breaks = sat$x, labels = levels(sat$BN_bin)) +
  scale_colour_manual(values = unname(OI[c("green", "blue")])) +
  annotate("segment", x = 1, xend = 1, y = 1.62, yend = 1.82, linewidth = 0.3,
           colour = "grey40", arrow = arrow(length = unit(1.4, "mm"))) +
  annotate("text", x = 0.95, y = 1.52,
           label = paste0(share1, " of county-months\ncome from a single birder"),
           size = 2.1, hjust = 0, vjust = 1, colour = "grey25") +
  labs(tag = "B", x = "Birdwatchers per county-month",
       title = "The outcome variable is a sampling-effort curve",
       subtitle = "Mean ± s.d.; species accumulation, not community change") +
  thm + theme(legend.position = c(0.98, 0.06), legend.justification = c(1, 0),
              legend.background = element_blank())

## ---- Panel C: sparse unbalanced coverage / 稀疏非平衡覆盖 ------------------
cov <- fread(file.path(out, "county_coverage.csv"))
med <- median(cov$months_observed)
pC <- ggplot(cov, aes(months_observed)) +
  geom_histogram(binwidth = 4, boundary = 0, fill = OI["sky"], colour = "white",
                 linewidth = 0.15) +
  geom_vline(xintercept = med, colour = OI["red"], linewidth = 0.5, linetype = 2) +
  annotate("text", x = med + 4, y = Inf, vjust = 1.4, hjust = 0,
           label = paste0("median = ", med, " of 120 months"),
           size = 2.2, colour = OI["red"]) +
  labs(tag = "A", x = "Months with any birdwatching record (of 120)",
       y = "Counties",
       title = "Panel coverage is extremely sparse",
       subtitle = "54% of counties observed in ≤12 of 120 months") +
  thm

## ---- Panel D: corruption reaches the outcome / 错误记录进入因变量 ----------
xh <- m[市 == "江门市" & 县 == "新会区",
        .(date = as.Date(paste0(ymkey, "-01")), ShannonBD)][order(date)]
bad_date <- as.Date("2015-03-01")
pD <- ggplot(xh, aes(date, ShannonBD)) +
  geom_line(colour = "grey65", linewidth = 0.35) +
  geom_point(size = 0.8, colour = "grey35") +
  geom_point(data = xh[date == bad_date], colour = OI["red"], size = 1.8) +
  annotate("curve", x = as.Date("2018-04-01"), y = 1.02,
           xend = bad_date + 60, yend = 0.12, curvature = -0.22,
           linewidth = 0.3, colour = OI["red"],
           arrow = arrow(length = unit(1.6, "mm"), type = "closed")) +
  annotate("text", x = as.Date("2018-06-01"), y = 1.30, hjust = 0, vjust = 1,
           size = 2.1, colour = OI["red"],
           label = "Mar 2015: a corrupted count\ncollapses H to 8\u00d710\u207b\u2077 (4 species)") +
  labs(tag = "C", x = NULL, y = "Shannon H, Xinhui County",
       title = "Uncleaned records corrupt the dependent variable",
       subtitle = "18 further county-months show ≥20 species yet H < 0.2") +
  thm

fig1 <- (pC | pB) / (pD | pA) + plot_layout(heights = c(1, 1))
ggsave(file.path(figd, "Fig1_observation_process.pdf"), fig1,
       width = 18.3, height = 11.2, units = "cm", device = cairo_pdf)
ggsave(file.path(figd, "Fig1_observation_process.png"), fig1,
       width = 18.3, height = 11.2, units = "cm", dpi = 600)

## ================= FIGURE 2 =================================================

## ---- Panel A: specification forest / 规格森林图 ---------------------------
sp <- fread(file.path(out, "spec_results.csv"))
mn <- list(ShannonBD = mean(m$ShannonBD), Richness = mean(m$Richness, na.rm = TRUE))
sd_pi <- sd(m$PI)

pick <- rbind(
  sp[label == "Authors' specification"][, grp := "Authors' model"],
  sp[label == "+ ln(birdwatchers)"][, grp := "Effort corrected"],
  sp[label == "+ ln(total duration)"][, grp := "Effort corrected"],
  sp[label == "+ both effort terms"][, grp := "Effort corrected"],
  sp[label == "Counties in policy source only"][, grp := "No PSI=0 imputation"],
  sp[label == "2014-2019 (pre-boom)"][, grp := "By period"],
  sp[label == "2020-2023 (boom)"][, grp := "By period"],
  sp[label == "2020-2023 + effort"][, grp := "By period"],
  sp[label == "Species richness"][, grp := "Richness outcome"],
  sp[label == "Species richness + effort"][, grp := "Richness outcome"]
)
# 统一单位:1 SD PSI 的百分比效应 / % change per 1-SD PSI
pick[, mean_out := fifelse(outcome == "Richness", mn$Richness, mn$ShannonBD)]
pick[, est := 100 * coef * sd_pi / mean_out]
pick[, lo  := 100 * (coef - 1.96 * se) * sd_pi / mean_out]
pick[, hi  := 100 * (coef + 1.96 * se) * sd_pi / mean_out]
pick[, sig := p < 0.05]
lab_map <- c("Authors' specification" = "Authors' model (Table 1, col. 3)",
             "+ ln(birdwatchers)" = "+ ln(no. of birdwatchers)",
             "+ ln(total duration)" = "+ ln(total birdwatching hours)",
             "+ both effort terms" = "+ both effort terms",
             "Counties in policy source only" = "Counties documented in policy source",
             "2014-2019 (pre-boom)" = "2014–2019 subsample",
             "2020-2023 (boom)" = "2020–2023 subsample",
             "2020-2023 + effort" = "2020–2023 + effort terms",
             "Species richness" = "Richness outcome, authors' controls",
             "Species richness + effort" = "Richness outcome + effort terms")
# 组内排序 + 组间分隔线 / ordered rows with separators between groups
lab_lv <- rev(unname(lab_map))
pick[, lab := factor(lab_map[label], levels = lab_lv)]
seps <- c(2.5, 5.5, 6.5, 9.5)   # 从底部数的组界 / group boundaries from bottom

pF <- ggplot(pick, aes(est, lab)) +
  geom_hline(yintercept = seps, linewidth = 0.25, colour = "grey88") +
  geom_vline(xintercept = 0, linetype = 2, linewidth = 0.35, colour = "grey50") +
  geom_vline(xintercept = -2.108, linetype = 3, linewidth = 0.35,
             colour = OI["red"]) +
  geom_errorbar(aes(xmin = lo, xmax = hi, colour = sig), width = 0.16,
                linewidth = 0.45, orientation = "y") +
  geom_point(aes(colour = sig, shape = outcome == "Richness"), size = 1.6) +
  scale_colour_manual(values = c(`TRUE` = unname(OI["red"]),
                                 `FALSE` = "grey55"),
                      labels = c(`TRUE` = "P < 0.05", `FALSE` = "P ≥ 0.05")) +
  scale_shape_manual(values = c(`FALSE` = 16, `TRUE` = 17), guide = "none") +
  scale_x_continuous(limits = c(-16, 3.4), breaks = seq(-15, 0, 5)) +
  labs(tag = "A", x = "Effect of 1 s.d. of PSI (% of outcome mean, 95% CI)",
       y = NULL,
       title = "The effect vanishes under correction",
       subtitle = "Same data, fixed effects, clustering as Zhang et al.\nRed dotted line: headline −2.10%") +
  thm + theme(legend.position = "bottom",
              legend.margin = margin(t = -6),
              legend.background = element_blank())

## ---- Panel B: variance ledger / 方差账本 ----------------------------------
r2d <- fread(file.path(out, "r2_decomposition.csv"))
led <- data.table(
  item = factor(c("County + year-month fixed effects",
                  "Nine control variables",
                  "PSI (the headline variable)",
                  "Unexplained"),
                levels = rev(c("County + year-month fixed effects",
                               "Nine control variables",
                               "PSI (the headline variable)",
                               "Unexplained"))),
  share = c(r2d[component == "County + year-month FE only", r2],
            r2d[component == "FE + controls (no PSI)", r2] -
              r2d[component == "County + year-month FE only", r2],
            r2d[component == "PSI unique increment over controls", r2],
            1 - r2d[component == "FE + controls + PSI (full)", r2]))
led[, pct := 100 * share]

pR <- ggplot(led, aes(pct, item)) +
  geom_col(fill = c("grey80", OI[["red"]], OI[["orange"]], OI[["blue"]]),
           width = 0.62) +
  geom_text(aes(label = fifelse(pct < 0.1, sprintf("%.2f%%", pct),
                                sprintf("%.1f%%", pct))),
            hjust = -0.08, size = 2.3) +
  scale_x_continuous(limits = c(0, 80), expand = expansion(mult = c(0, 0.01))) +
  labs(tag = "B", x = "Share of variance in county-month Shannon H (%)", y = NULL,
       title = "PSI explains 0.03% of the variance",
       subtitle = "1-s.d. PSI shift = 0.052 on H; residual s.d. = 0.80") +
  thm

fig2 <- pF / pR + plot_layout(heights = c(2.15, 0.85))
ggsave(file.path(figd, "Fig2_effect_fragility.pdf"), fig2,
       width = 13.5, height = 14.5, units = "cm", device = cairo_pdf)
ggsave(file.path(figd, "Fig2_effect_fragility.png"), fig2,
       width = 13.5, height = 14.5, units = "cm", dpi = 600)

cat("Figures written to", figd, "\n")


## ---- 投稿版:去除图内叙述性标题(期刊规范)/ submission versions -----------
subfig <- file.path(base, "submission/figures")
fig1s <- fig1 & labs(title = NULL, subtitle = NULL)
fig2s <- fig2 & labs(title = NULL, subtitle = NULL)
ggsave(file.path(subfig, "Fig1.pdf"), fig1s, width = 18.3, height = 10.2,
       units = "cm", device = cairo_pdf)
ggsave(file.path(subfig, "Fig1.png"), fig1s, width = 18.3, height = 10.2,
       units = "cm", dpi = 600)
ggsave(file.path(subfig, "Fig2.pdf"), fig2s, width = 18.3, height = 8.6,
       units = "cm", device = cairo_pdf)
ggsave(file.path(subfig, "Fig2.png"), fig2s, width = 18.3, height = 8.6,
       units = "cm", dpi = 600)
cat("submission Fig1/Fig2 written\n")
