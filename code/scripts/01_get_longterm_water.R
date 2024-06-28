# Run auction-level part of the processing
# Must run using Rterm.exe to see console output on Windows when using multiple cores

# Load directories and functions
# Either run 00_setup.R in the same R environment prior to running this script
# Or specify path to 00_setup.R below and uncomment out the following two lines:
#setup_dir <- "PATH/TO/SETUP/FILE"
#source(file.path(setup_dir, "00_setup.R"))

# Processing parameters
# Default to those specified in 00_setup.R 
# Included here so that you can overwrite for this run only
#set overwrite to TRUE if you wish to update the valley-wide
overwrite <- overwrite_global
cores_max <- cores_max_global

# Field parameters
scn <- auction_extent
mths <- allowed_months

# Get / create water files ---------------------------------------------------
# If not overwriting, copy base focal water and predictions from data_dir
if (overwrite != TRUE) {
  
  # Get base files
  wxl_files <- list.files(base_wxl_dir, pattern = ".tif$", full.names = TRUE)
  
  # Copy focal files
  fcl_avg_files <- list.files(base_fcl_dir, pattern = "average.*tif$", full.names = TRUE)
  fcl_fns <- basename(fcl_avg_files)
  file.copy(fcl_avg_files, file.path(avg_fcl_dir, fcl_fns))
  
  # Copy predictions
  prd_files <- list.files(base_prd_dir, pattern = ".tif$", full.names = TRUE)
  prd_fns <- basename(prd_files)
  file.copy(prd_files, file.path(avg_prd_dir, prd_fns))

# If overwriting, recreate water x landcover layers and focal files
} else {
  
  # Load guide raster
  ref_file <- file.path(cov_dir, paste0("data_type_constant_ebird_valley", scn , ".tif"))
  guide_rst <- rast(ref_file)
  
  # Load water files
  # TODO: add parameter for year range of average to allow easier updating
  water_files <- file.path(avg_dir, paste0(scn, "_average_", mths, "_2011-2021_snapped.tif"))
  
  # Overlay water and landcover
  ncores <- min(detectCores(), length(water_files), cores_max)
  
  wxl_files <- overlay_water_landcover(water_files, 
                                       lc_files,
                                       output_dir = avg_wxl_dir,
                                       ncores = ncores)
  
  wxl_files <- list.files(avg_wxl_dir, pattern = ".tif$", full.names = TRUE)
  
  # Calculate moving windows
  ncores <- min(detectCores(), length(wxl_files), cores_max)
  fcl_avg_files <- mean_neighborhood_water(wxl_files, #previously-created water x landcover files
                                           distances = c(250, 5000), #250m and 5km
                                           output_dir = avg_fcl_dir,
                                           trim_extent = TRUE,
                                           ncores = ncores)
  
  # water_files_longterm are created by the auction-level analysis
  fcl_avg_files <- list.files(avg_fcl_dir, pattern = "average.*tif$", full.names = TRUE)
  
  # Predict birds ----------------------------------------------
  # Use longterm model -- long-term average water with no imposed flooding
  # Used as base landscape suitability value to subtract from each field's landscape total
  # use length of water_imp_files, because that's the number of unique month/flood_area combos
  ncores <- min(detectCores(), length(water_imp_files), cores_max)
  
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
  
}





