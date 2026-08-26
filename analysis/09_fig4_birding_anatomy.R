# ============================================================
# Scientific question / 科学问题:
# What does the birdwatching dataset actually look like — how unequal,
# how sparse, how seasonal, and how mismatched is the growth of effort
# against the growth of policy? Four reader-facing panels.
# 观鸟数据到底长什么样:县间多不平等、县-月多稀疏、季节结构如何、
# 努力增长与政策增长的错位有多大?面向读者的四联图。
#
# Input / 输入: output/panel_master.rds, output/hotspot_trajectories.csv
# Output / 输出: figures/Fig4_birding_data_anatomy.{png,pdf}
# Main packages / 主要包: data.table, ggplot2, patchwork, scales
# ============================================================

suppressPackageStartupMessages({
  library(data.table); library(ggplot2); library(patchwork); library(scales)
})

base <- "/Users/dingchenchen/Documents/能源转型与生态保护"
out  <- file.path(base, "output"); figd <- file.path(base, "figures")
m    <- readRDS(file.path(out, "panel_master.rds"))

OI <- c(blue = "#0072B2", verm = "#D55E00", orange = "#E69F00",
        green = "#009E73", sky = "#56B4E9", grey = "#8C9BA8")
theme_pub <- theme_minimal(base_size = 10.5, base_family = "Helvetica") +
  theme(panel.grid.minor = element_blank(),
        panel.grid.major = element_line(linewidth = .25, colour = "#E3E9EE"),
        axis.title = element_text(size = 9.5, colour = "#33404E"),
        axis.text  = element_text(size = 8.5, colour = "#5B6B7A"),
        plot.title = element_text(size = 11, face = "bold", colour = "#16202B"),
        plot.subtitle = element_text(size = 8.8, colour = "#5B6B7A"),
        plot.tag = element_text(size = 12, face = "bold"),
        legend.position = "none",
        plot.margin = margin(6, 10, 4, 6))

## ---- A. 洛伦兹曲线:观测努力的县间集中度 / Lorenz curve of effort ----------
cb <- m[, .(bn = sum(BN)), by = id][order(bn)]
cb[, `:=`(cx = seq_len(.N) / .N, cy = cumsum(bn) / sum(bn))]
gini <- 1 - 2 * sum(cb$cy * diff(c(0, cb$cx)))          # 数值积分 / numeric Gini
top1 <- 1 - cb[cx <= 0.99, max(cy)]                     # top 1% 县的观测份额
top10 <- 1 - cb[cx <= 0.90, max(cy)]
pA <- ggplot(cb, aes(cx, cy)) +
  geom_abline(slope = 1, intercept = 0, linetype = 2,
              colour = OI["grey"], linewidth = .35) +
  geom_line(colour = OI["blue"], linewidth = .9) +
  annotate("text", x = .06, y = .93, hjust = 0, size = 3.1, colour = "#33404E",
           label = sprintf("基尼系数 Gini = %.2f", gini)) +
  annotate("text", x = .06, y = .82, hjust = 0, size = 2.9, colour = "#5B6B7A",
           label = sprintf("1%% 的县贡献 %.0f%% 的观测\n10%% 的县贡献 %.0f%% 的观测",
                           100 * top1, 100 * top10)) +
  scale_x_continuous(labels = percent) + scale_y_continuous(labels = percent) +
  labs(tag = "A", title = "观测努力高度集中于少数县",
       subtitle = "县按累计观鸟人数升序;虚线为完全均等",
       x = "县的累计份额(按观测量排序)", y = "观测人数的累计份额") +
  theme_pub

## ---- B. 县-月观鸟人数分布 / distribution of birders per county-month ------
bins <- m[, .N, by = .(g = cut(BN, c(0, 1, 2, 5, 10, 50, 100, Inf),
          labels = c("1", "2", "3–5", "6–10", "11–50", "51–100", ">100")))]
bins[, share := N / sum(N)]
pB <- ggplot(bins, aes(g, share)) +
  geom_col(fill = OI["blue"], width = .68,
           alpha = c(1, rep(.55, nrow(bins) - 1))) +
  geom_text(aes(label = percent(share, accuracy = .1)), vjust = -.45,
            size = 2.8, colour = "#33404E") +
  annotate("segment", x = 1.55, xend = 1.08, y = .435, yend = .405,
           colour = OI["verm"], linewidth = .35) +
  annotate("text", x = 1.7, y = .44, size = 3, colour = OI["verm"],
           fontface = "bold", hjust = 0,
           label = "38.8% 的县-月仅 1 名观鸟者") +
  scale_y_continuous(labels = percent, expand = expansion(mult = c(0, .12))) +
  labs(tag = "B", title = "近四成县-月只有一名观鸟者",
       subtitle = "回归样本 46,371 个县-月的观鸟人数分布",
       x = "该县-月的观鸟人数", y = "县-月占比") +
  theme_pub

## ---- C. 季节结构 / seasonality of reporting -------------------------------
seas <- m[, .(cm = .N, bn = sum(BN)), by = month][order(month)]
pC <- ggplot(seas, aes(factor(month), cm)) +
  geom_col(fill = OI["green"], alpha = .8, width = .68) +
  annotate("rect", xmin = 3.5, xmax = 5.5, ymin = 0, ymax = Inf,
           fill = OI["orange"], alpha = .10) +
  annotate("rect", xmin = 8.5, xmax = 11.5, ymin = 0, ymax = Inf,
           fill = OI["orange"], alpha = .10) +
  annotate("text", x = 4.5, y = max(seas$cm) * 1.04, size = 2.7,
           colour = "#8A6A1F", label = "春迁") +
  annotate("text", x = 10, y = max(seas$cm) * 1.04, size = 2.7,
           colour = "#8A6A1F", label = "秋迁/越冬") +
  scale_y_continuous(labels = comma, expand = expansion(mult = c(0, .10))) +
  labs(tag = "C", title = "观测带有强烈的季节结构",
       subtitle = "各月份的有观测县-月数;迁徙与越冬季为观鸟高峰",
       x = "月份", y = "有观测的县-月数") +
  theme_pub

## ---- D. 扩散错位 / diffusion mismatch: hotspot vs non-hotspot -------------
traj <- fread(file.path(out, "hotspot_trajectories.csv"))
traj[, grp := fifelse(hotspot == "hotspot", "观鸟热点县(基线前 25%)", "非热点县")]
dl <- melt(traj, id.vars = c("grp", "YEAR"),
           measure.vars = c("BN_rel", "PI_rel"),
           variable.name = "series", value.name = "rel")
dl[, what := fifelse(series == "BN_rel", "观鸟人数", "政策强度")]
pD <- ggplot(dl, aes(YEAR, rel, colour = grp, linetype = what)) +
  geom_line(linewidth = .8) +
  geom_point(data = dl[what == "观鸟人数"], size = 1.3) +
  scale_y_log10(labels = comma) +
  scale_colour_manual(values = c("观鸟热点县(基线前 25%)" = unname(OI["blue"]),
                                 "非热点县" = unname(OI["verm"]))) +
  scale_linetype_manual(values = c("观鸟人数" = "solid", "政策强度" = "22")) +
  scale_x_continuous(breaks = seq(2014, 2023, 3)) +
  annotate("text", x = 2021.1, y = 210, size = 2.8, colour = OI["verm"],
           label = "非热点县 ×299", fontface = "bold") +
  annotate("text", x = 2022.3, y = 38, size = 2.8, colour = OI["blue"],
           label = "热点县 ×134", fontface = "bold") +
  annotate("text", x = 2020.5, y = 1.55, size = 2.7, colour = "#5B6B7A",
           label = "政策强度(虚线)仅 ×3–4") +
  labs(tag = "D", title = "观鸟扩张与政策扩张的轨迹错位",
       subtitle = "相对 2014 年的倍数(对数轴);实线为观鸟人数,虚线为政策强度",
       x = NULL, y = "相对 2014 的倍数(log)") +
  theme_pub + theme(legend.position = c(.26, .88),
                    legend.title = element_blank(),
                    legend.text = element_text(size = 7.6),
                    legend.key.height = unit(10, "pt"),
                    legend.background = element_blank())

fig4 <- (pA | pB) / (pC | pD)
ggsave(file.path(figd, "Fig4_birding_data_anatomy.png"), fig4,
       width = 8.4, height = 6.6, dpi = 600, bg = "white")
ggsave(file.path(figd, "Fig4_birding_data_anatomy.pdf"), fig4,
       width = 8.4, height = 6.6, bg = "white")
cat(sprintf("Fig4 saved. Gini=%.3f top1=%.1f%% top10=%.1f%%\n",
            gini, 100 * top1, 100 * top10))
