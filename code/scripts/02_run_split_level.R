# Run auction-level part of the processing
# Must run using Rterm.exe to see console output on Windows when using multiple cores

# Load directories and functions
code_dir <-"V:/Project/wetland/NASA_water/CVJV_misc_pred_layer/ForecastingTNC/code/water_tracker/code"
source(file.path(code_dir, "definitions_local.R"))

source(file.path(code_dir, "functions/00_shared_functions.R"))
source(file.path(code_dir, "functions/01_process_field_file.R"))
source(file.path(code_dir, "functions/02_impose_flooding.R"))
source(file.path(code_dir, "functions/03_water_x_landcover.R"))
source(file.path(code_dir, "functions/04_water_moving_window.R"))
source(file.path(code_dir, "functions/05_predict_birds.R"))
source(file.path(code_dir, "functions/06_extract_predictions.R"))

overwrite <- FALSE
cores_max <- 16

# Packages
library(rgdal)
library(raster)
rasterOptions(tmpdir = "E:/nelliott/temp")

# Shapefile
shp_fn <- "B4B_22_Fall_fields"
shp_file <- file.path(fld_dir, paste0(shp_fn, ".shp"))
split_column <- "BidFieldID"

# Guide raster
ref_file <- file.path(cov_dir, "data_type_constant_ebird_p44r33.tif")
guide_rst <- raster(ref_file)

# Split, rasterize, and buffer
floodarea_files <- split_flooding_area(shp_file,
                                       split_column,
                                       guide_raster = ref_file,
                                       output_dir = spl_dir, #defined in definitions.R
                                       do_rasterize = TRUE, #required for next step
                                       buffer_dist = 10000,
                                       ncores = cores_max)

floodarea_files <- list.files(spl_dir, pattern = ".shp$", full.names = TRUE)
fa_rst_files <- list.files(spl_dir, pattern = ".tif$", full.names = TRUE)

# Water files
mths <- c("Jul", "Aug", "Sep", "Oct")
water_files <- file.path(avg_dir, paste0("p44r33_average_", mths, "_2010-2020.tif"))

# Specify landcover files; lc_dir defined in definitions.R
landcovers <- c("Rice", "Corn", "Grain", "NonRiceCrops", "TreatedWetland", "Wetland_SemiSeas", "AltCrop")
lc_files <- file.path(lc_dir, paste0(landcovers, "_p44r33.tif"))

# Set cores for first step
# multicore set up for water_files, not fa_rst_files; reverse loop nesting to increase speed
ncores <- min(detectCores(), length(water_files), cores_max)

# Impose flooding
water_imp_files <- impose_flooding(water_files,
                                   fa_rst_files,
                                   output_dir = imp_wtr_dir,
                                   mask = TRUE, #significantly speeds up processing in later steps
                                   ncores = ncores)

# Overlay water and landcover
ncores <- min(detectCores(), length(water_imp_files), cores_max)

wxl_files <- overlay_water_landcover(water_imp_files, 
                                     lc_files,
                                     output_dir = imp_wxl_dir,
                                     ncores = ncores)

# Calculate moving windows
ncores <- min(detectCores(), length(water_imp_files), cores_max)
fcl_imp_files <- mean_neighborhood_water(wxl_files, #previously-created water x landcover files
                                           distances = c(250, 5000), #250m and 5km
                                           output_dir = imp_fcl_dir,
                                           trim_extent = TRUE,  #only set for TRUE with splits
                                           ncores = ncores)

# Predict birds using reallong model -- long-term average water and realtime imposed flooding
# use length of water_imp_files, because that's the number of unique month/flood_area combos
ncores <- min(detectCores(), length(water_imp_files), cores_max)

fcl_imp_files <- list.files(imp_fcl_dir, pattern = ".tif$", full.names = TRUE)

# water_files_longterm are created by the auction-level analysis
fcl_avg_files <- list.files(avg_fcl_dir, pattern = "average.*tif$", full.names = TRUE)

# Can subset files using the scenarios parameter, which is applied as a regex filter
scenarios_filter <- "imposed"

prd_files <- predict_bird_rasters(fcl_imp_files,
                                  fcl_avg_files,
                                  scenarios = scenarios_filter,
                                  water_months = mths,
                                  model_files = shorebird_model_files_reallong,
                                  model_names = shorebird_model_names_reallong,
                                  static_cov_files = bird_model_cov_files,
                                  static_cov_names = bird_model_cov_names,
                                  monthly_cov_files = tmax_files,
                                  monthly_cov_months = tmax_months,
                                  monthly_cov_names = tmax_names,
                                  output_dir = imp_prd_dir,
                                  ncores = ncores)


# Extract bird predictions ----------------------------------------
prd_files <- list.files(imp_prd_dir, pattern = ".tif$", full.names = TRUE)
ncores <- min(detectCores(), length(floodarea_files), cores_max)


# Column that contains the names of the fields to extract prediction data for
# Fields with the same name in a flooding area are grouped
source(file.path(code_dir, "functions/06_extract_predictions.R"))
stat_files <- extract_predictions(prd_files,
                                  floodarea_files,
                                  field_column = split_column,
                                  area_column = "AreaAcres",
                                  output_dir = imp_stat_dir,
                                  ncores = 1)


stat_files <- list.files(imp_stat_dir, pattern = ".rds$", full.names = TRUE)
