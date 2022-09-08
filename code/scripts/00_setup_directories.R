# Setup directories

code_dir <-"V:/Project/wetland/NASA_water/CVJV_misc_pred_layer/ForecastingTNC/code/water_tracker/code"
source(file.path(code_dir, "definitions_local.R"))
source(file.path(code_dir, "functions/00_shared_functions.R"))

dirs <- c(data_dir, 
          axn_dir, 
          fld_dir,
          spl_dir,
          scn_avg_dir,
          avg_wtr_dir,
          avg_wxl_dir, 
          avg_fcl_dir, 
          avg_prd_dir, 
          avg_stat_dir,
          scn_imp_dir, 
          imp_wtr_dir, 
          imp_wxl_dir, 
          imp_fcl_dir, 
          imp_prd_dir, 
          imp_stat_dir)

check_dir(dirs, create = TRUE)
