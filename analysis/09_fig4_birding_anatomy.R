# ============================================================
# Scientific question / 科学问题:
# What does the birdwatching dataset actually look like — how unequal,
# how sparse, how seasonal, and how mismatched is the growth of effort
# against the growth of policy? Four reader-facing panels (v2, refined).
# 观鸟数据到底长什么样:县间多不平等、县-月多稀疏、季节结构如何、
# 努力增长与政策增长的错位有多大?面向读者的四联图(v2 精修版)。
#
# Input / 输入: output/panel_master.rds, output/hotspot_trajectories.csv
# Output / 输出: figures/Fig4_birding_data_anatomy.{png,pdf}
# Main packages / 主要包: data.table, ggplot2, patchwork, scales
# ============================================================

suppressPackageStartupMessages({
  library(data.table); library(ggplot2); library(patchwork); library(scales)
})

# 从仓库根目录运行本脚本 / run this script from the repository root:
#   Rscript analysis/<script>.R
base <- "."
out  <- file.path(base, "output"); figd <- file.path(base, "figures")
m    <- readRDS(file.path(out, "panel_master.rds"))

OI <- c(blue = "#0072B2", verm = "#D55E00", orange = "#E69F00",
        green = "#009E73", sky = "#56B4E9", grey = "#8C9BA8")
theme_pub <- theme_minimal(base_size = 10.5, base_family = "Helvetica") +
  theme(panel.grid.minor = element_blank(),
        panel.grid.major = element_line(linewidth = .25, colour = "#E8EDF1"),
        axis.line = element_line(linewidth = .3, colour = "#B9C4CE"),
        axis.ticks = element_line(linewidth = .3, colour = "#B9C4CE"),
        axis.ticks.length = unit(2.5, "pt"),
        axis.title = element_text(size = 9.5, colour = "#33404E"),
        axis.text  = element_text(size = 8.5, colour = "#5B6B7A"),
        plot.title = element_text(size = 11, face = "bold", colour = "#16202B"),
        plot.subtitle = element_text(size = 8.8, colour = "#5B6B7A",
                                     margin = margin(b = 7)),
        plot.tag = element_text(size = 13, face = "bold"),
        legend.position = "none",
        plot.margin = margin(8, 12, 6, 8))

## ---- A. 洛伦兹曲线 / Lorenz curve of effort concentration ------------------
cb <- m[, .(bn = sum(BN)), by = id][order(bn)]
cb[, `:=`(cx = seq_len(.N) / .N, cy = cumsum(bn) / sum(bn))]
gini  <- 1 - 2 * sum(cb$cy * diff(c(0, cb$cx)))
top1  <- 1 - cb[cx <= 0.99, max(cy)]
top10 <- 1 - cb[cx <= 0.90, max(cy)]
pA <- ggplot(cb, aes(cx, cy)) +
  geom_ribbon(aes(ymin = cy, ymax = cx), fill = OI["blue"], alpha = .08) +
  geom_abline(slope = 1, intercept = 0, linetype = "22",
              colour = OI["grey"], linewidth = .4) +
  geom_line(colour = OI["blue"], linewidth = 1) +
  annotate("text", x = .40, y = .60, size = 2.8, colour = OI["grey"],
           angle = 45, label = "完全均等线") +
  annotate("text", x = .05, y = .96, hjust = 0, vjust = 1, size = 3.2,
           colour = "#16202B", fontface = "bold",
           label = sprintf("基尼系数 = %.2f", gini)) +
  annotate("text", x = .05, y = .84, hjust = 0, vjust = 1, size = 2.9,
           colour = "#33404E", lineheight = 1.15,
           label = sprintf("最活跃 1%% 的县贡献 %.0f%% 的观测\n最活跃 10%% 的县贡献 %.0f%% 的观测",
                           100 * top1, 100 * top10)) +
  scale_x_continuous(labels = percent_format(accuracy = 1),
                     expand = expansion(mult = c(.005, .02))) +
  scale_y_continuous(labels = percent_format(accuracy = 1),
                     expand = expansion(mult = c(.005, .02))) +
  coord_equal() +
  labs(tag = "A", title = "观测努力高度集中于少数县",
       subtitle = "2,344 个县按累计观鸟人数升序排列的洛伦兹曲线",
       x = "县的累计份额(按观测量升序)", y = "观测人数的累计份额") +
  theme_pub

## ---- B. 县-月观鸟人数分布 / birders per county-month ----------------------
# 与回归口径一致:剔除单观测县(reghdfe singleton)/ drop singleton counties
mreg <- m[, if (.N > 1) .SD, by = county]
bins <- mreg[, .N, by = .(g = cut(BN, c(0, 1, 2, 5, 10, 50, 100, Inf),
          labels = c("1", "2", "3–5", "6–10", "11–50", "51–100", ">100")))]
bins[, share := N / sum(N)][, hl := g == "1"]
pB <- ggplot(bins, aes(g, share, fill = hl)) +
  geom_col(width = .66) +
  geom_text(aes(label = percent(share, accuracy = .1)), vjust = -.5,
            size = 2.9, colour = "#33404E") +
  scale_fill_manual(values = c(`TRUE` = unname(OI["verm"]),
                               `FALSE` = "#9DC6E0")) +
  annotate("text", x = 2.6, y = .335, hjust = 0, size = 3.05,
           colour = OI["verm"], fontface = "bold", lineheight = 1.15,
           label = "38.8% 的县-月仅一名观鸟者\n单人月均 15 种,百人月均 142 种") +
  annotate("curve", x = 2.5, xend = 1.36, y = .33, yend = .40,
           curvature = .25, linewidth = .35, colour = OI["verm"],
           arrow = arrow(length = unit(4, "pt"), type = "closed")) +
  scale_y_continuous(labels = percent_format(accuracy = 1),
                     limits = c(0, .46), expand = expansion(mult = c(0, .02))) +
  labs(tag = "B", title = "近四成县-月只有一名观鸟者",
       subtitle = sprintf("回归样本 %s 个县-月的观鸟人数分布", format(nrow(mreg), big.mark=",")),
       x = "该县-月的观鸟人数", y = "县-月占比") +
  theme_pub

## ---- C. 季节结构 / seasonality ---------------------------------------------
seas <- m[, .(cm = .N), by = month][order(month)]
band <- data.table(x1 = c(3.5, 8.5), x2 = c(5.5, 11.5),
                   lab = c("春迁", "秋迁与越冬"))
pC <- ggplot(seas, aes(factor(month), cm)) +
  geom_rect(data = band, aes(xmin = x1, xmax = x2, ymin = -Inf, ymax = Inf),
            inherit.aes = FALSE, fill = OI["orange"], alpha = .10) +
  geom_col(fill = OI["green"], alpha = .85, width = .66) +
  geom_text(data = band, aes(x = (x1 + x2) / 2, y = 5350, label = lab),
            inherit.aes = FALSE, size = 2.9, colour = "#8A6A1F") +
  scale_y_continuous(labels = label_comma(),
                     limits = c(0, 5600), expand = expansion(mult = c(0, 0))) +
  labs(tag = "C", title = "观测量呈明显的季节结构",
       subtitle = "各月份的有观测县-月数;群落组成亦随季节更替",
       x = "月份", y = "有观测的县-月数") +
  theme_pub

## ---- D. 扩散错位 / diffusion mismatch, direct-labelled ---------------------
traj <- fread(file.path(out, "hotspot_trajectories.csv"))
traj[, grp := fifelse(hotspot == "hotspot", "热点县", "非热点县")]
dl <- melt(traj, id.vars = c("grp", "YEAR"),
           measure.vars = c("BN_rel", "PI_rel"),
           variable.name = "series", value.name = "rel")
dl[, what := fifelse(series == "BN_rel", "观鸟人数", "政策强度")]
cols <- c("热点县" = unname(OI["blue"]), "非热点县" = unname(OI["verm"]))
pD <- ggplot(dl, aes(YEAR, rel, colour = grp, linetype = what)) +
  geom_line(linewidth = .85) +
  geom_point(data = dl[what == "观鸟人数"], size = 1.4) +
  scale_y_log10(breaks = c(1, 10, 100), labels = c("×1", "×10", "×100"),
                limits = c(0.8, 480)) +
  scale_colour_manual(values = cols) +
  scale_linetype_manual(values = c("观鸟人数" = "solid", "政策强度" = "22")) +
  scale_x_continuous(breaks = c(2014, 2017, 2020, 2023),
                     expand = expansion(mult = c(.02, .18))) +
  annotate("text", x = 2023.15, y = 299, hjust = 0, size = 3,
           colour = OI["verm"], fontface = "bold", label = "非热点县\n×299") +
  annotate("text", x = 2023.15, y = 110, hjust = 0, size = 3,
           colour = OI["blue"], fontface = "bold", label = "热点县\n×134") +
  annotate("text", x = 2023.15, y = 3.4, hjust = 0, size = 2.8,
           colour = "#5B6B7A", lineheight = 1.1, label = "政策强度\n×3–4") +
  annotate("text", x = 2014.2, y = 330, hjust = 0, size = 2.9,
           colour = "#33404E", lineheight = 1.2,
           label = "实线:观鸟人数(基线前 25% 为热点县)\n虚线:政策强度均值") +
  labs(tag = "D", title = "观鸟扩张与政策扩张的轨迹错位",
       subtitle = "相对 2014 年的倍数(2014 = 1;对数轴)",
       x = NULL, y = "相对 2014 年的倍数") +
  theme_pub

fig4 <- (pA | pB) / (pC | pD)
ggsave(file.path(figd, "Fig4_birding_data_anatomy.png"), fig4,
       width = 8.6, height = 6.9, dpi = 600, bg = "white")
ggsave(file.path(figd, "Fig4_birding_data_anatomy.pdf"), fig4,
       width = 8.6, height = 6.9, bg = "white")
cat(sprintf("Fig4 v2 saved. Gini=%.3f top1=%.1f%% top10=%.1f%%\n",
            gini, 100 * top1, 100 * top10))


## ---- 投稿版 fig. S2:英文标签、无叙述性标题 / English submission version ---
pA_en <- ggplot(cb, aes(cx, cy)) +
  geom_ribbon(aes(ymin = cy, ymax = cx), fill = OI["blue"], alpha = .08) +
  geom_abline(slope = 1, intercept = 0, linetype = "22",
              colour = OI["grey"], linewidth = .4) +
  geom_line(colour = OI["blue"], linewidth = 1) +
  annotate("text", x = .40, y = .60, size = 2.8, colour = OI["grey"],
           angle = 45, label = "line of equality") +
  annotate("text", x = .05, y = .96, hjust = 0, vjust = 1, size = 3.2,
           colour = "#16202B", fontface = "bold",
           label = sprintf("Gini = %.2f", gini)) +
  annotate("text", x = .05, y = .84, hjust = 0, vjust = 1, size = 2.9,
           colour = "#33404E", lineheight = 1.15,
           label = sprintf("top 1%% of counties: %.0f%% of effort\ntop 10%%: %.0f%% of effort",
                           100 * top1, 100 * top10)) +
  scale_x_continuous(labels = percent_format(accuracy = 1)) +
  scale_y_continuous(labels = percent_format(accuracy = 1)) +
  coord_equal() +
  labs(tag = "A", x = "Cumulative share of counties (ascending effort)",
       y = "Cumulative share of birdwatchers") + theme_pub
pB_en <- ggplot(bins, aes(g, share, fill = hl)) +
  geom_col(width = .66) +
  geom_text(aes(label = percent(share, accuracy = .1)), vjust = -.5,
            size = 2.9, colour = "#33404E") +
  scale_fill_manual(values = c(`TRUE` = unname(OI["verm"]), `FALSE` = "#9DC6E0")) +
  annotate("text", x = 2.6, y = .335, hjust = 0, size = 3.0,
           colour = OI["verm"], fontface = "bold", lineheight = 1.15,
           label = "38.8% of county-months:\na single birdwatcher") +
  annotate("curve", x = 2.5, xend = 1.36, y = .33, yend = .40,
           curvature = .25, linewidth = .35, colour = OI["verm"],
           arrow = arrow(length = unit(4, "pt"), type = "closed")) +
  scale_y_continuous(labels = percent_format(accuracy = 1),
                     limits = c(0, .46), expand = expansion(mult = c(0, .02))) +
  labs(tag = "B", x = "Birdwatchers in the county-month",
       y = "Share of county-months") + theme_pub
band_en <- data.table(x1 = c(3.5, 8.5), x2 = c(5.5, 11.5),
                      lab = c("spring migration", "autumn & wintering"))
pC_en <- ggplot(seas, aes(factor(month), cm)) +
  geom_rect(data = band_en, aes(xmin = x1, xmax = x2, ymin = -Inf, ymax = Inf),
            inherit.aes = FALSE, fill = OI["orange"], alpha = .10) +
  geom_col(fill = OI["green"], alpha = .85, width = .66) +
  geom_text(data = band_en, aes(x = (x1 + x2)/2, y = 5350, label = lab),
            inherit.aes = FALSE, size = 2.6, colour = "#8A6A1F") +
  scale_y_continuous(labels = label_comma(), limits = c(0, 5600),
                     expand = expansion(mult = c(0, 0))) +
  labs(tag = "C", x = "Month", y = "County-months with records") + theme_pub
dl_en <- copy(dl)
dl_en[, grp := fifelse(grp == "热点县", "hotspot", "non-hotspot")]
cols_en <- c(hotspot = unname(OI["blue"]), `non-hotspot` = unname(OI["verm"]))
pD_en <- ggplot(dl_en, aes(YEAR, rel, colour = grp, linetype = what)) +
  geom_line(linewidth = .85) +
  geom_point(data = dl_en[what == "观鸟人数"], size = 1.4) +
  scale_y_log10(breaks = c(1, 10, 100), labels = c("\u00d71", "\u00d710", "\u00d7100"),
                limits = c(0.8, 480)) +
  scale_colour_manual(values = cols_en) +
  scale_linetype_manual(values = c("观鸟人数" = "solid", "政策强度" = "22")) +
  scale_x_continuous(breaks = c(2014, 2017, 2020, 2023),
                     expand = expansion(mult = c(.02, .42))) +
  annotate("text", x = 2023.15, y = 299, hjust = 0, size = 3,
           colour = OI["verm"], fontface = "bold", label = "non-hotspot\n\u00d7299") +
  annotate("text", x = 2023.15, y = 110, hjust = 0, size = 3,
           colour = OI["blue"], fontface = "bold", label = "hotspot\n\u00d7134") +
  annotate("text", x = 2023.15, y = 3.4, hjust = 0, size = 2.8,
           colour = "#5B6B7A", lineheight = 1.1, label = "policy stringency\n\u00d73\u20134") +
  annotate("text", x = 2014.2, y = 330, hjust = 0, size = 2.8,
           colour = "#33404E", lineheight = 1.2,
           label = "solid: birdwatcher counts (top 25% = hotspot)\ndashed: mean policy stringency") +
  labs(tag = "D", x = NULL, y = "Multiple of 2014 level (log scale)") + theme_pub
figS2 <- (pA_en | pB_en) / (pC_en | pD_en)
subfig <- file.path(base, "submission/figures")
ggsave(file.path(subfig, "FigS2.png"), figS2, width = 8.6, height = 6.6,
       dpi = 600, bg = "white")
ggsave(file.path(subfig, "FigS2.pdf"), figS2, width = 8.6, height = 6.6, bg = "white", device = cairo_pdf)
cat("submission FigS2 (English) written\n")
