# Run auction-level part of the processing
# Must run using Rterm.exe to see console output on Windows when using multiple cores

# Load directories and functions
# Either run 00_setup.R in the same R environment prior to running this script
# Or specify path to 00_setup.R below and uncomment out the following two lines:
#setup_dir <- "PATH/TO/SETUP/FILE"
#source(file.path(setup_dir, "00_setup.R"))

# Processing parameters
# Default to those specified in definitions_local.R 
# Included here so that you can overwrite for this run only
overwrite <- overwrite_global
cores_max <- cores_max_global

# Field parameters
scn <- auction_extent
mths <- allowed_months

# Guide raster
ref_file <- file.path(cov_dir, paste0("data_type_constant_ebird_", scn , ".tif"))
guide_rst <- rast(ref_file)

# Shapefile
axn_file_prj <- file.path(fld_dir, paste0(shp_fn, "_prj.shp"))
if (!file.exists(axn_file_prj)) {
  
  message_ts("Cleaning and projecting shapefile...")
  
  fld_shp <- vect(axn_file)
  
  # Clean names
  # TODO -- remove apostrophes first and replace with space rather than -
  fld_shp$BidID <- clean_string(fld_shp$BidID, "")
  fld_shp$FieldID <- clean_string(fld_shp$FieldID)
  
  # Fill blanks
  fld_shp$FieldID <- ifelse(fld_shp$FieldID == "", "Field", fld_shp$FieldID)
  
  # Check for duplicates
  bid_field_df <- as.data.frame(fld_shp)[c("BidID", "FieldID")]
  dup_df <- unique(bid_field_df[duplicated(bid_field_df),])
  if (nrow(dup_df) > 0) {
    
    message_ts("Found ", nrow(dup_df), " duplicate(s). Will make unique by appending a number in ascending order...")
    
    # Make duplicates unique by appending an ascending number (-1, -2, etc)
    for (n in 1:nrow(dup_df)) {
      bid <- dup_df$BidID[n]
      fld <- dup_df$FieldID[n]
      n_dups <- length(fld_shp$FieldID[fld_shp$BidID == bid & fld_shp$FieldID == fld])
      fld_shp$FieldID[fld_shp$BidID == bid & fld_shp$FieldID == fld] <- paste(fld, 1:n_dups, sep = "-")
    }
    
  }
  
  fld_shp$BidFieldID <- paste(fld_shp$BidID, fld_shp$FieldID, sep = "-")
  split_column <- "BidFieldID"
  fld_shp_prj <- project(fld_shp, guide_rst)
  
  writeVector(fld_shp_prj, filename = axn_file_prj, filetype = "ESRI Shapefile", overwrite = TRUE)
  
}

# TODO -- collapse multiple spaces in a row to one dash

# TODO -- already does multicore? check. 
#         could multi-core this if desired; get number of rows, divide into ncore groups, and pass file plus rows to each

# TODO -- consider breaking into two functions: one to parse and split shapefile (single call), one to rasterize and buffer (multicore)

# Split, rasterize, and buffer
floodarea_files <- split_flooding_area(axn_file_prj,
                                       split_column,
                                       guide_raster = ref_file,
                                       output_dir = spl_dir, #defined in definitions.R
                                       do_rasterize = TRUE, #required for next step
                                       buffer_dist = 10000,
                                       ncores = cores_max)

floodarea_files <- list.files(spl_dir, pattern = ".shp$", full.names = TRUE)
fa_rst_files <- list.files(spl_dir, pattern = ".tif$", full.names = TRUE)

# Water files

#water_files <- file.path(avg_dir, paste0("p44r33_average_", mths, "_2010-2020.tif"))
water_files <- file.path(avg_dir, paste0(scn, "_average_", mths, "_2011-2021.tif"))

# Specify landcover files; lc_dir defined in definitions.R
landcovers <- c("Rice", "Corn", "Grain", "NonRiceCrops", "TreatedWetland", "Wetland_SemiSeas", "AltCrop")
lc_files <- file.path(lc_dir, paste0(landcovers, "_", scn, ".tif")) #add _snapped for non-p44r33 files: "_snapped.tif"))
# TODO -- standardize naming of landcover files

# Set cores for first step
# multicore set up for water_files, not fa_rst_files; reverse loop nesting to increase speed
ncores <- min(detectCores(), length(water_files), cores_max)

# TODO - vectorize by both water_file and field

# Impose flooding
water_imp_files <- impose_flooding(water_files,
                                   fa_rst_files,
                                   output_dir = imp_wtr_dir,
                                   mask = TRUE, #significantly speeds up processing in later steps
                                   ncores = ncores)

water_imp_files <- list.files(imp_wtr_dir, pattern = paste0(scn, ".*tif$"), full.names = TRUE)

# Overlay water and landcover
ncores <- min(detectCores(), length(water_imp_files), cores_max)

wxl_files <- overlay_water_landcover(water_imp_files, 
                                     lc_files,
                                     output_dir = imp_wxl_dir,
                                     ncores = ncores)

wxl_files <- list.files(imp_wxl_dir, pattern = paste0(scn, ".*tif$"), full.names = TRUE)

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

fcl_imp_files <- list.files(imp_fcl_dir, pattern = paste0(scn, ".*tif$"), full.names = TRUE)

# water_files_longterm are created by 01_get_longterm_water.R
fcl_avg_files <- list.files(avg_fcl_dir, pattern = paste0(scn, ".*average.*tif$"), full.names = TRUE)

# Can subset files using the scenarios parameter, which is applied as a regex filter
scenarios_filter <- "imposed"

bird_model_cov_files <- file.path(cov_dir, c("data_type_constant_ebird_valley.tif", "valley_roads_valley.tif"))
tmax_files <- file.path(cov_dir, paste0("tmax_", mths, "_valley_snapped2.tif"))
tmax_months <- mths
tmax_names <- rep("tmax250m", length(mths))

prd_files <- predict_bird_rasters(water_files_realtime = fcl_imp_files,
                                  water_files_longterm = fcl_avg_files,
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
prd_files <- list.files(imp_prd_dir, pattern = ".*tif$", full.names = TRUE)
ncores <- min(detectCores(), length(floodarea_files), cores_max)


# Column that contains the names of the fields to extract prediction data for
# Fields with the same name in a flooding area are grouped
field_column <- "BidFieldID"
stat_files <- extract_predictions(prd_files,
                                  floodarea_files,
                                  field_column = field_column,
                                  area_column = "AreaAcres",
                                  output_dir = imp_stat_dir,
                                  ncores = ncores)


stat_files <- list.files(imp_stat_dir, pattern = ".rds$", full.names = TRUE)
fld_shp <- vect(file.path(fld_dir, paste0(shp_fn, "_prj.shp")))
metadata_df <- as.data.frame(fld_shp)

sum_files <- summarize_predictions(stat_files, 
                                   field_shapefile = axn_file, 
                                   output_dir = imp_stat_dir, 
                                   overwrite = overwrite)


