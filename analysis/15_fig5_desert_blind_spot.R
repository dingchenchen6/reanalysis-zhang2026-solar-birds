# ============================================================
# Scientific question / 科学问题:
# One figure showing why the desert-subgroup null of Zhang et al. (2026)
# cannot support siting decisions: desert-flagged counties are thinly
# observed (a), their outcome variable is built from widespread species
# (b), the subgroup had ~18% power to detect the national estimate and its
# contrast with other counties disappears once effort is modelled (c), and
# 80% power is reached only for effects far larger than the headline (d).
# 用一张图说明荒漠亚组零结果为何不能支撑选址决策。
#
# Input data / 输入数据:
#   output/desert_*.csv, output/county_effort_map.csv (script 14);
#   original_replication/extracted/DATA/Gebi.dta (authors' desert flag);
#   2019 standard map of China, GS(2019)1822 (env CHINA_MAP_DIR): county,
#   province, national-boundary and nine-dash-line layers.
# Main workflow / 主要流程:
#   1. Build map layers in the map's own Albers equal-area CRS.
#   2. Fix the map frame from geographic anchors so that every piece of
#      map furniture sits on blank ground: north arrow top-left (Kazakhstan),
#      legend and scale bar bottom-left (south of Tibet), South China Sea
#      inset bottom-right (east of Taiwan, clear of Taiwan and Diaoyu Dao).
#      地图框由地理锚点确定,使指北针、图例、比例尺、南海插图都落在境外空白处,
#      且不遮挡台湾与钓鱼岛。
#   3. Panels b-d from the derived tables; true minus signs on all axes.
#   4. Export journal version (no panel titles) and a titled web version.
# Expected output / 预期输出:
#   submission/figures/Fig5.(pdf|png)   journal version, 183 mm wide
#   figures/Fig5_desert_blind_spot.(pdf|png)   web version with headings
# Key assumptions / 关键假设:
#   Effects use the national conversion (s.d. PSI 4.116; mean H 2.446).
# Main packages / 主要包: data.table, ggplot2, patchwork, sf, ggspatial, ggtext
# Output directory / 输出路径: submission/figures/, figures/
# ============================================================

suppressPackageStartupMessages({
  library(data.table); library(ggplot2); library(patchwork); library(sf); library(haven)
})

base <- "."
out  <- file.path(base, "output"); figd <- file.path(base, "figures")
mapd <- Sys.getenv("CHINA_MAP_DIR",
                   "/Users/dingchenchen/Downloads/2019中国地图-审图号GS(2019)1822号")

FONT <- "Helvetica"
ACC  <- "#D55E00"                                   # desert group accent / 荒漠组强调色
# 顺序色(Blues 4 级)+ 无记录近白色:无记录与最低一级亮度差约 10 L*,灰度打印可分
# sequential Blues (4 classes) + near-white for no record (ΔL* ≈ 10 from class 1)
FILL <- c("No record" = "#f2f2f2", "1–10" = "#c6dbef", "11–100" = "#6baed6",
          "101–1,000" = "#2171b5", ">1,000" = "#08306b")
update_geom_defaults("text", list(family = FONT))
minus <- function(x) gsub("-", "−", format(x, trim = TRUE))   # true minus / 真负号

thm <- theme_classic(base_size = 7, base_family = FONT) +
  theme(axis.text = element_text(size = 6, colour = "black"),
        axis.title = element_text(size = 6.5),
        plot.tag = element_text(size = 8, face = "bold"),
        legend.text = element_text(size = 5.8), legend.title = element_text(size = 6),
        legend.key.size = unit(0.26, "cm"), legend.background = element_blank(),
        axis.line = element_line(linewidth = 0.3), axis.ticks = element_line(linewidth = 0.3),
        plot.margin = margin(3, 5, 2, 2))

## ---- a: map layers / 地图图层 ----------------------------------------------
cmap <- fread(file.path(out, "county_effort_map.csv"))
gb   <- as.data.table(read_dta(file.path(base, "original_replication/extracted/DATA/Gebi.dta")))
cty  <- st_read(file.path(mapd, "县（等积投影）.shp"), quiet = TRUE)
crs_map <- st_crs(cty)
cty$id <- as.integer(cty$PAC)
cty  <- merge(cty, gb[, .(id, desert_gobi)], by = "id", all.x = TRUE)
desert_outline <- st_simplify(st_union(st_make_valid(cty[cty$desert_gobi %in% 1, ])),
                              dTolerance = 1000)
desert_outline <- st_sf(lab = "Desert-flagged counties", geometry = desert_outline)
cty  <- st_simplify(st_make_valid(cty), dTolerance = 800)       # drawing geometry only
cty  <- merge(cty, cmap[, .(id, birders_total)], by = "id", all.x = TRUE)
cty$birders_total[is.na(cty$birders_total)] <- 0
cty$cls <- cut(cty$birders_total, c(-Inf, 0, 10, 100, 1000, Inf), labels = names(FILL))
rd   <- function(f) st_transform(st_read(file.path(mapd, f), quiet = TRUE), crs_map)
prov <- st_simplify(rd("省（等积投影）.shp"), dTolerance = 1500)
nat  <- st_simplify(rd("国界.shp"), dTolerance = 1500)
ndl  <- rd("九段线.shp")

## ---- map frame from geographic anchors / 由地理锚点确定地图框 --------------
P <- function(lon, lat) st_coordinates(st_transform(st_sfc(st_point(c(lon, lat)), crs = 4326), crs_map))[1, ]
cen  <- st_coordinates(st_transform(st_centroid(st_geometry(cty)), 4326))
bb   <- st_bbox(cty[cen[, 2] > 17, ])                  # mainland, Hainan, Taiwan
tw_e <- P(122.0, 23.5)[["X"]]                          # Taiwan east coast / 台湾东岸
dyd  <- P(123.7, 25.8)                                 # Diaoyu Dao / 钓鱼岛
xmin <- bb[["xmin"]] - 60e3; ymax <- bb[["ymax"]] + 40e3
ymin <- bb[["ymin"]] - 60e3                            # just below Hainan / 海南以南
# 南海插图范围与宽高比 / South China Sea inset extent and aspect
scs  <- st_bbox(st_transform(st_as_sfc(st_bbox(c(xmin = 106.5, xmax = 122.5, ymin = 2.5, ymax = 24.5),
                                               crs = 4326)), crs_map))
asp  <- (scs[["xmax"]] - scs[["xmin"]]) / (scs[["ymax"]] - scs[["ymin"]])
ins_h <- 1.05e6; ins_w <- ins_h * asp                  # inset size in map metres
ins_l <- max(tw_e, dyd[["X"]]) + 90e3                  # east of Taiwan and Diaoyu Dao
xmax <- ins_l + ins_w + 50e3
ins  <- c(l = ins_l, r = ins_l + ins_w, b = ymin + 45e3, t = ymin + 45e3 + ins_h)
W <- xmax - xmin; H <- ymax - ymin
npc <- function(x, y) c((x - xmin) / W, (y - ymin) / H)
cat(sprintf("frame %.0f x %.0f km; inset %.0f x %.0f km; inset top %.0f km below Diaoyu\n",
            W / 1e3, H / 1e3, ins_w / 1e3, ins_h / 1e3, (dyd[["Y"]] - ins[["t"]]) / 1e3))

pMap <- ggplot() +
  geom_sf(data = cty, aes(fill = cls), colour = NA) +
  geom_sf(data = prov, fill = NA, colour = "white", linewidth = 0.18) +
  geom_sf(data = nat,  fill = NA, colour = "grey25", linewidth = 0.25) +
  geom_sf(data = desert_outline, aes(colour = lab), fill = NA, linewidth = 0.4,
          key_glyph = "path") +
  coord_sf(xlim = c(xmin, xmax), ylim = c(ymin, ymax), expand = FALSE) +
  # 经纬网标签用 Unicode 字符串,避免 plotmath 度符号回落到非 Helvetica 字体
  # graticule labels as plain Unicode strings (plotmath degree falls back to another font)
  scale_x_continuous(breaks = seq(80, 130, 10), labels = function(x) paste0(x, "\u00b0E")) +
  scale_y_continuous(breaks = seq(20, 50, 10), labels = function(x) paste0(x, "\u00b0N")) +
  scale_fill_manual(values = FILL, name = "Birdwatchers,\n2014–2023", drop = FALSE) +
  scale_colour_manual(values = ACC, name = NULL) +
  guides(fill = guide_legend(order = 1, ncol = 1),
         colour = guide_legend(order = 2, override.aes = list(linewidth = 0.6))) +
  ggspatial::annotation_north_arrow(
    location = "tl", which_north = "true",
    height = unit(0.5, "cm"), width = unit(0.36, "cm"),
    pad_x = unit(0.12, "cm"), pad_y = unit(0.1, "cm"),
    style = ggspatial::north_arrow_orienteering(line_width = 0.35, text_size = 5,
                                                text_family = FONT, fill = c("white", "grey25"))) +
  # 比例尺置于指北针右侧(哈萨克斯坦—蒙古一线以北的境外空白)
  # scale bar right of the north arrow, on blank ground north of Xinjiang
  ggspatial::annotation_scale(
    location = "tl", width_hint = 0.15, style = "bar", line_width = 0.25,
    text_cex = 0.48, text_family = FONT, bar_cols = c("grey25", "white"), height = unit(0.09, "cm"),
    pad_x = unit(0.62, "cm"), pad_y = unit(0.2, "cm")) +
  thm + theme(axis.text = element_text(size = 5, colour = "grey35"),
              axis.ticks = element_blank(), axis.line = element_blank(), axis.title = element_blank(),
              panel.grid.major = element_line(colour = "grey88", linewidth = 0.12),
              panel.border = element_rect(fill = NA, colour = "grey45", linewidth = 0.3),
              # 图例置于图框外左侧、底对齐:不压任何陆地或制图要素
              # legend outside the neatline, bottom-aligned on the left: overlaps nothing
              legend.position = "left", legend.justification = c(1, 0),
              legend.box = "vertical", legend.box.just = "left", legend.spacing.y = unit(0.05, "cm"),
              legend.key.size = unit(0.24, "cm"), legend.text = element_text(size = 5.6),
              legend.title = element_text(size = 5.8), legend.margin = margin(0, 1, 0, 0),
              legend.box.spacing = unit(0.1, "cm"))

# 南海诸岛插图:国界 + 九段线,白底遮挡经纬网 / inset with national boundary and nine-dash line
pInset <- ggplot() +
  geom_sf(data = st_crop(cty, scs), fill = "grey88", colour = NA) +
  geom_sf(data = st_crop(nat, scs), fill = NA, colour = "grey25", linewidth = 0.2) +
  geom_sf(data = ndl, colour = "grey25", linewidth = 0.3) +
  coord_sf(xlim = scs[c("xmin", "xmax")], ylim = scs[c("ymin", "ymax")], expand = FALSE) +
  theme_void() +
  theme(panel.border = element_rect(fill = NA, colour = "grey45", linewidth = 0.3),
        panel.background = element_rect(fill = "white", colour = NA))
ib <- npc(ins[["l"]], ins[["b"]]); it <- npc(ins[["r"]], ins[["t"]])
pA <- pMap + inset_element(pInset, left = ib[1], bottom = ib[2], right = it[1], top = it[2],
                           align_to = "panel", clip = TRUE)
# 地图不参与行对齐;标签挂在外层,使 a 与 b 的标签同高
# map is not row-aligned; the tag sits on the wrapper so tags a and b share a baseline
pA <- wrap_elements(full = pA) + labs(tag = "a") +
  theme(plot.tag = element_text(size = 8, face = "bold", family = FONT))

## ---- b: composition of records in flagged counties / 荒漠县记录组成 ---------
comp <- fread(file.path(out, "desert_species_composition.csv"))
top  <- comp[1:10, .(label = species, share, grp = "top")]
spec <- data.table(label = "16 desert specialists, combined",
                   share = comp[specialist == TRUE, sum(share)], grp = "spec")
pb   <- rbind(top, spec)
pb[, label := factor(label, levels = rev(label))]
has_ggtext <- requireNamespace("ggtext", quietly = TRUE)
ylab_fun <- function(x) ifelse(x %in% top$label, paste0("*", x, "*"), x)
pB <- ggplot(pb, aes(100 * share, label, fill = grp)) +
  geom_hline(yintercept = 1.5, linewidth = 0.25, colour = "grey80") +
  geom_col(width = 0.62) +
  geom_text(aes(label = sprintf("%.1f", 100 * share)), hjust = -0.25, size = 2.05) +
  scale_fill_manual(values = c(top = "grey60", spec = ACC), guide = "none") +
  scale_x_continuous(limits = c(0, 3), breaks = 0:3, expand = expansion(mult = 0)) +
  { if (has_ggtext) scale_y_discrete(labels = ylab_fun) else NULL } +
  labs(tag = "b", x = "Share of species records (%)", y = NULL) +
  thm + theme(axis.text.y = if (has_ggtext) ggtext::element_markdown(size = 6, family = FONT)
                            else element_text(size = 6),
              axis.line.y = element_blank(), axis.ticks.y = element_blank())

## ---- c: subgroup estimates and power / 亚组估计与检验力 ---------------------
pw <- fread(file.path(out, "desert_power.csv"))
sd_pi <- 4.115859; mn_H <- 2.445786
pw[, lo := 100 * (coef - 1.96 * se) * sd_pi / mn_H][, hi := 100 * (coef + 1.96 * se) * sd_pi / mn_H]
lab_c <- c("National, authors' specification"   = "National",
           "Non-desert, authors' specification" = "Non-desert",
           "Non-desert, + effort terms"         = "Non-desert, effort terms",
           "Desert, authors' specification"     = "Desert",
           "Desert, + effort terms"             = "Desert, effort terms",
           "Desert, preferred corrected"        = "Desert, corrected",
           "Desert, north-western arid belt, authors' specification" = "Desert, north-western provinces",
           "Three-North, authors' specification"= "Three-North")
pw <- pw[design %chin% names(lab_c)]
pw[, lab := factor(lab_c[design], levels = rev(unname(lab_c)))]
pw[, desert := grepl("^Desert", design)]
xr <- c(-6.5, 13.4)
pC <- ggplot(pw, aes(est_pct, lab)) +
  geom_hline(yintercept = c(1.5, 5.5, 7.5), linewidth = 0.25, colour = "grey85") +
  geom_vline(xintercept = 0, linewidth = 0.3, colour = "grey55") +
  geom_vline(xintercept = -2.108, linetype = 3, linewidth = 0.35, colour = ACC) +
  geom_errorbar(aes(xmin = lo, xmax = hi, colour = desert), width = 0.18, linewidth = 0.4,
                orientation = "y") +
  geom_point(aes(colour = desert), size = 1.5) +
  geom_text(aes(x = xr[2], label = sprintf("%.0f%%", 100 * power_headline)), hjust = 1, size = 2.05) +
  annotate("text", x = xr[2], y = nrow(pw) + 0.75, hjust = 1, size = 2.0, label = "Power") +
  annotate("text", x = -2.108, y = nrow(pw) + 0.75, hjust = 0.5, size = 2.0, colour = ACC,
           label = "−2.10%") +
  scale_colour_manual(values = c(`FALSE` = "black", `TRUE` = ACC), guide = "none") +
  scale_x_continuous(limits = xr, breaks = seq(-6, 9, 3), labels = minus) +
  coord_cartesian(clip = "off") +
  labs(tag = "c", x = "Effect per s.d. of PSI (% of outcome mean)", y = NULL) +
  thm + theme(axis.line.y = element_blank(), axis.ticks.y = element_blank())

## ---- d: power curves / 检验力曲线 -------------------------------------------
pc <- fread(file.path(out, "desert_power_curve.csv"))
keep <- c("National, authors' specification", "Non-desert, authors' specification",
          "Desert, authors' specification", "Desert, preferred corrected")
pc <- pc[design %chin% keep]
pc[, design := factor(lab_c[design], levels = lab_c[keep])]
mde_des <- pw[design == "Desert, authors' specification", MDE80_pct]
pD <- ggplot(pc, aes(true_pct, power, colour = design, linetype = design)) +
  geom_hline(yintercept = 0.8, linetype = 2, linewidth = 0.3, colour = "grey55") +
  geom_vline(xintercept = -2.108, linetype = 3, linewidth = 0.35, colour = ACC) +
  geom_line(linewidth = 0.55) +
  annotate("point", x = -mde_des, y = 0.8, size = 1.4, colour = ACC) +
  annotate("text", x = -mde_des - 0.18, y = 0.755, hjust = 1, size = 2.0, colour = ACC,
           label = sprintf("MDE −%.1f%%", mde_des)) +
  scale_colour_manual(values = c("black", "grey55", ACC, ACC), name = NULL) +
  scale_linetype_manual(values = c("solid", "solid", "solid", "22"), name = NULL) +
  scale_y_continuous(limits = c(0, 1), breaks = seq(0, 1, 0.2), labels = scales::percent) +
  scale_x_continuous(breaks = seq(-8, 0, 2), labels = minus) +
  labs(tag = "d", x = "True effect per s.d. of PSI (% of outcome mean)", y = "Power") +
  thm + theme(legend.position = c(0.02, 0.03), legend.justification = c(0, 0),
              legend.key.width = unit(0.6, "cm"), legend.key.height = unit(0.24, "cm"))

## ---- assemble and export / 组装与导出 ----------------------------------------
fig <- ((pA | pB) + plot_layout(widths = c(1.62, 1))) / (pC | pD) +
  plot_layout(heights = c(1.06, 1))

subfig <- file.path(base, "submission/figures")
dir.create(subfig, showWarnings = FALSE, recursive = TRUE)
ggsave(file.path(subfig, "Fig5.pdf"), fig, width = 18.3, height = 13.2, units = "cm",
       device = cairo_pdf)
ggsave(file.path(subfig, "Fig5.png"), fig, width = 18.3, height = 13.2, units = "cm", dpi = 600)
cat("submission Fig5 written\n")

web <- ((pA | (pB + labs(subtitle = "Composition of records in flagged counties"))) +
          plot_layout(widths = c(1.62, 1))) /
       ((pC + labs(subtitle = "Table S17 subgroups replicated exactly")) |
        (pD + labs(subtitle = "Analytical power by design"))) +
       plot_layout(heights = c(1.06, 1)) &
       theme(plot.subtitle = element_text(size = 6.4, colour = "grey25", family = FONT))
ggsave(file.path(figd, "Fig5_desert_blind_spot.pdf"), web, width = 18.3, height = 13.6, units = "cm",
       device = cairo_pdf)
ggsave(file.path(figd, "Fig5_desert_blind_spot.png"), web, width = 18.3, height = 13.6, units = "cm",
       dpi = 600)
cat("Fig 5 written.\n")
