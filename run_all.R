# ============================================================
# 按依赖顺序运行全部分析脚本 / run the analysis scripts in dependency order
#
# 用法 / usage(在仓库根目录 / from the repository root):
#   Rscript run_all.R
#
# 前置 / prerequisites:
#   1. 作者公开复现包置于 original_replication/extracted/DATA/
#      (见 README;脚本 01-09 只需要它)
#      The authors' public replication package under
#      original_replication/extracted/DATA/ (scripts 01-09 need only this).
#   2. 脚本 10-11 另需记录级观鸟数据,置于 data_raw/(见 README 与仓库 Release)。
#      Scripts 10-11 additionally need the record-level birdwatching data
#      under data_raw/ (see README and the repository release).
#
# 说明 / notes:
#   - 01 生成 output/panel_master.rds,02-09 依赖它;
#     06 生成 hotspot_trajectories.csv,09 依赖它;
#     02 生成的派生表供 04 绘图。下面的顺序已满足这些依赖。
#   - 缺少记录级数据时,10-11 会给出下载提示并跳过,其余结果不受影响。
# ============================================================

scripts <- c(
  "01_assemble_replicate.R",      # 面板组装 + Table 1 精确复现
  "02_corrected_models.R",        # 努力/填零/指标/时段校正 + R2 分解
  "03_data_pathology.R",          # 污染记录核验 + 记录方式模拟
  "05_final_pipeline.R",          # 36 规格曲线 + 首选估计
  "06_negative_control.R",        # 阴性对照与机制检验
  "07_independent_audit.R",       # 一致性规则 R1-R5 + CPUE + 功效
  "08_iv_replication.R",          # 工具变量一阶段与 2SLS 复现
  "04_figures.R",                 # 图 1-2(依赖 02 的派生表)
  "09_fig4_birding_anatomy.R",    # 观鸟数据结构图(依赖 06)
  "10_species_level_validation.R",# 记录级核验(需 data_raw/)
  "11_raw_platform_validation.R", # 原始省级交付核验(需 data_raw/)
  "12_visits_proxy_robustness.R", # 清单数作第三努力代理(需 data_raw/)
  "13_effort_accessibility.R"     # 努力与夜光/人口密度的县-月关联(仅需公开包)
)

optional <- c("10_species_level_validation.R", "11_raw_platform_validation.R",
              "12_visits_proxy_robustness.R")

for (s in scripts) {
  cat("\n========== ", s, " ==========\n", sep = "")
  path <- file.path("analysis", s)
  ok <- tryCatch({ source(path, echo = FALSE); TRUE },
                 error = function(e) { message("ERROR in ", s, ": ", conditionMessage(e)); FALSE })
  if (!ok && !(s %in% optional))
    stop("Stopped at ", s, ". Fix the error above before continuing.")
  if (!ok) message("Skipped ", s, " (record-level data absent); other results are unaffected.")
}

cat("\nAll available scripts finished. Derived tables are in output/, figures in figures/.\n")
writeLines(capture.output(sessionInfo()), "sessionInfo.txt")
cat("Session information written to sessionInfo.txt\n")
