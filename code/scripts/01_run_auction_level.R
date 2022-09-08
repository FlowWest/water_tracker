# Run auction-level part of the processing
# Must run using Rterm.exe to see console output on Windows when using multiple cores

# Load directories and functions
code_dir <-"V:/Project/wetland/NASA_water/CVJV_misc_pred_layer/ForecastingTNC/code/water_tracker/code"
source(file.path(code_dir, "definitions_local.R"))

source(file.path(code_dir, "functions/00_shared_functions.R"))
source(file.path(code_dir, "functions/02_impose_flooding.R"))
source(file.path(code_dir, "functions/03_water_x_landcover.R"))
source(file.path(code_dir, "functions/04_water_moving_window.R"))

overwrite <- FALSE
cores_max <- 16

# Packages
library(rgdal)
library(raster)
rasterOptions(tmpdir = "E:/nelliott/temp")

# Load shapefile
shp_fn <- "B4B_22_Fall_fields"
axn_shp <- readOGR(fld_dir, shp_fn)

# Load guide raster
ref_file <- file.path(cov_dir, "data_type_constant_ebird_p44r33.tif")
guide_rst <- raster(ref_file)

# Rasterize and buffer if not already done; buffer in ArcGIS is MUCH quicker
axn_buf_fn <- "B4B_22_Fall_fields_merged_buffer10k"
axn_rst_file <- file.path(fld_dir, paste0(shp_fn, ".tif"))
if (!file.exists(axn_rst_file) | overwrite == TRUE) {
  
  message_ts("Rasterizing auction file...")
  axn_rst <- raster::rasterize(axn_shp, guide_rst, field = 1)
  
  if (file.exists(paste0(fld_dir, "/", axn_buf_fn, ".shp")))  {
    
    axn_buf_shp <- readOGR(fld_dir, axn_buf_fn)
    axn_buf_rst <- raster::rasterize(axn_buf_shp, guide_rst, field = 1)
    
  } else {
    
    buffer_dist <- 10000
    message_ts("Calculating ", buffer_dist, "m buffer for combined fields raster...")
    
    axn_buf_rst <- buffer(axn_rst, width = buffer_dist)
    
  }
  
  message_ts("Adding buffer to flooding area raster...")
  axn_out_rst <- overlay(x = axn_rst, y = axn_buf_rst, fun = function(x, y) { ifelse(is.na(x) & y == 1, 2, x) },
                         filename = axn_rst_file, overwrite = TRUE)
  
}

# Water files
mths <- c("Jul", "Aug", "Sep", "Oct")
water_files <- file.path(avg_dir, paste0("p44r33_average_", mths, "_2010-2020.tif"))

# Specify landcover files; lc_dir defined in definitions.R
landcovers <- c("Rice", "Corn", "Grain", "NonRiceCrops", "TreatedWetland", "Wetland_SemiSeas", "AltCrop")
lc_files <- file.path(lc_dir, paste0(landcovers, "_p44r33.tif"))

# Set cores for first step
ncores <- min(detectCores(), length(water_files), cores_max)

# Mask water files (call impose_flooding for side effect of masking)
water_avg_files <- impose_flooding(water_files,
                                   axn_rst_file,
                                   output_dir = avg_wtr_dir,
                                   imposed_value = NULL, 
                                   imposed_label = "average",
                                   mask = TRUE, #significantly speeds up processing in later steps
                                   ncores = ncores)

# Overlay water and landcover
ncores <- min(detectCores(), length(water_avg_files), cores_max)

wxl_files <- overlay_water_landcover(water_avg_files, 
                                     lc_files,
                                     output_dir = avg_wxl_dir,
                                     ncores = ncores)

# Calculate moving windows
ncores <- min(detectCores(), length(water_avg_files), cores_max)
mean_neighborhood_water(wxl_files, #previously-created water x landcover files
                        distances = c(250, 5000), #250m and 5km
                        output_dir = avg_fcl_dir,
                        trim_extent = TRUE,
                        ncores = ncores)



# Predict birds using longterm-only model -- long-term average water with no imposed flooding
# Used as base landscape suitability value to subtract from each field's landscape total
# use length of water_imp_files, because that's the number of unique month/flood_area combos
ncores <- min(detectCores(), length(water_imp_files), cores_max)
ncores <- 1

# water_files_longterm are created by the auction-level analysis
fcl_avg_files <- list.files(avg_fcl_dir, pattern = "average.*tif$", full.names = TRUE)

# Can subset files using the scenarios parameter, which is applied as a regex filter
scenarios_filter <- "average"

source(file.path(code_dir, "functions/05_predict_birds.R"))
prd_files <- predict_bird_rasters(NULL,
                                  fcl_avg_files,
                                  scenarios = scenarios_filter,
                                  water_months = mths,
                                  model_files = shorebird_model_files_long,
                                  model_names = shorebird_model_names_long,
                                  static_cov_files = bird_model_cov_files,
                                  static_cov_names = bird_model_cov_names,
                                  monthly_cov_files = tmax_files,
                                  monthly_cov_months = tmax_months,
                                  monthly_cov_names = tmax_names,
                                  output_dir = avg_prd_dir,
                                  ncores = ncores)

