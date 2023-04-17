# Defines auction parameters (e.g., name, month, shapefile),
#   file directories, input file characteristics, and model parameters
#  
# Point Blue, California Rice Commission

# Processing parameters --------------------------------------------
# Name of this auction
# Used as a folder name, so letters, numbers, underscores, and dashes only
auction_id <- "2023-Feb-DSOD" #example format: year-mth-code

# Months to analyze
# Vector of three letter month abbreviations with first letter capitalized
auction_months <- c("Mar", "Apr")
#auction_months <- month.abb[3:4] #alternate way to specify months using numeric code

# Spatial extent of the fields to process
# Specifies the landsat scene the fields are part of, or 'valley' if multiple scenes
# Allowed values: 'p44r33' (Sacramento), 'p44r34' (Suisun), 'p43r34' (Delta), 'p42r35' (Tulare)
#                 'valley' (entire CVJV) if multiple
# See map in documentation for details
auction_extent <- "valley"

# Name and path of the field shapefile specifying the bids to analyze
shp_fn <- "example_shapefile" #do not include extension
shp_dir <- getwd() #change as needed with "PATH/TO/SHAPEFILE"
axn_file <- file.path(shp_dir, paste0(shp_fn, ".shp"))

# Whether or not previously-created outputs in this auction should be skipped or overwritten
# Must be TRUE or FALSE
overwrite_global <- FALSE

# Maximum number of cores to use for processing
# Must be an integer less than or equal to the number of cores on your machine
cores_max_global <- 4

# Directory parameters ---------------------------------------
# Name of the directory / folder in which to run the processing
base_dir <- getwd() #replace as necessary with "YOUR/BASE/DIR"

# Temporary directory to use for storing temp files
temp_dir <- tempdir() #change if desired

# Directory containing the GitHub repository with the code and data
# Defaults to assuming 'water_tracker' cloned to base_dir; adjust as needed
code_dir <- file.path(base_dir, "water_tracker")


# Packages ----------------------------------------------------
# Parts of processing upgraded to terra, but predict.gbm requires raster
library(terra)
library(parallel)
library(MASS)
library(dismo)
library(gbm)
library(rgdal)
library(raster)
library(dplyr)
library(tidyr)

# Set temp processing directory for terra and raster
terraOptions(tmpdir = temp_dir)
rasterOptions(tmpdir = temp_dir)


# Load code files ---------------------------------------------
fxn_dir <- file.path(code_dir, "code/functions")
code_files <- file.path(fxn_dir, c("00_shared_functions.R",
                                   "01_process_field_file.R",
                                   "02_impose_flooding.R",
                                   "03_water_x_landcover.R",
                                   "04_water_moving_window.R",
                                   "05_predict_birds.R",
                                   "06_extract_predictions.R",
                                   "07_summarize_predictions.R"))
code_files_exist <- file.exists(code_files)
if (!all(code_files_exist)) {
  stop(add_ts(paste0("required code files not found. Please check that you have cloned the GitHub repo to ",
                     "the directory specified in definitions_local.R. Missing file(s):\n\t",
                     paste0(code_files[!code_files_exist], collapse = "\n\t"))))
}
source(code_files)


# Check inputs ------------------------------------------------
# Check allowed_months
bad_months <- allowed_months[!(allowed_months %in% month.abb)]
if (length(bad_months) > 0) {
  stop(add_ts(paste0("all allowed_months must be a valid 3-letter abbreviation for month. ",
                     "The following are not recognized:\n\t",
                     paste0(bad_months, collapse = "\n\t"))))
}

# Check processing_extent
allowed_scenes <- c("p44r33", "p44r34", "p43r34", "p42r35", "valley")
if (!length(auction_extent) == 1) stop("auction_extent must be a single entry")
if (!(auction_extent %in% C(allowed_scenes))) {
  stop(add_ts(paste0("invalid processing extent specified in definitions_local.R. ", 
                     "Defined auction_extent must be one of the following values:\n\t",
                     paste0(allowed_scenes, collapse = "\n\t"))))
}

# Check code_dir
if (!file.exists(code_dir)) {
  stop(add_ts(paste0("required code directory not found. Please check that you have cloned the GitHub repo to ",
                     "the directory specified in definitions_local.R. Missing directory:\n\t",
                     code_dir)))
}

# Check overwrite_global
if (!is.logical(overwrite_global)) stop("overwrite_global parameter must be either TRUE or FALSE.")

# Check cores_max_global
if (!is.integer(cores_max_global)) stop("cores_max_global parameter must be an integer.")
cores_available <- detectCores()
if (cores_max_global > cores_available)  {
  warning(add_ts(paste0("Specified cores_max_global for multi-core processing of ", cores_max_global, 
                        " is higher than available cores. Setting to ", cores_available, ".")))
  cores_max_global <- cores_available
}


# Check shapefile
if (!file.exists(axn_file)) {
  stop(add_ts(paste0("auction shapefile axn_file specified in 00_setup.R not found. Missing file:\n\t",
                     axn_file)))
}

axn_shp <- vect(axn_file)
required_cols <- c("BidID", "FieldID", "StartDate", "EndDate", "Split", "AreaAcres", "PricePerAc", "CoverType")
missing_cols <- required_cols[!(required_cols %in% names(axn_shp))]
if (length(missing_cols) > 0) {
  stop(add_ts(paste0("The following required column(s) are missing from the auction shapefile:\n\t",
                     paste0(missing_cols, collapse = "\n\t"))))
}
  
# Set directories ---------------------------------------------
data_dir <- file.path(code_dir, "data")
axn_dir <- file.path(base_dir, auction_id)
lc_dir <- file.path(data_dir, "landcover")
run_dir <- file.path(data_dir, "runoff")
pcp_dir <- file.path(data_dir, "precip")
wtr_dir <- file.path(data_dir, "water")
avg_dir <- file.path(data_dir, "water_averages")
cov_dir <- file.path(data_dir, "other_covariates")

mdl_dir <- file.path(data_dir, "models")
brd_mdl_dir <- file.path(mdl_dir, "birds")
fld_dir <- file.path(axn_dir, "fields")
spl_dir <- file.path(fld_dir, "splits")

# Average flooding (baseline)
base_avg_dir <- file.path(data_dir, "longterm_averages")
base_wtr_dir <- file.path(scn_avg_dir, "water")
base_wxl_dir <- file.path(scn_avg_dir, "water_x_landcover")
base_fcl_dir <- file.path(scn_avg_dir, "water_focal")
base_prd_dir <- file.path(scn_avg_dir, "bird_predictions")

# Average flooding (auction-level)
scn_avg_dir <- file.path(axn_dir, "scenario_average_water")
avg_wtr_dir <- file.path(scn_avg_dir, "water")
avg_wxl_dir <- file.path(scn_avg_dir, "water_x_landcover")
avg_fcl_dir <- file.path(scn_avg_dir, "water_focal")
avg_prd_dir <- file.path(scn_avg_dir, "bird_predictions")
avg_stat_dir <- file.path(scn_avg_dir, "stats")

# Imposed flooding (field or bid-level)
scn_imp_dir <- file.path(axn_dir, "scenario_imposed_water")
imp_wtr_dir <- file.path(scn_imp_dir, "water")
imp_wxl_dir <- file.path(scn_imp_dir, "water_x_landcover")
imp_fcl_dir <- file.path(scn_imp_dir, "water_focal")
imp_prd_dir <- file.path(scn_imp_dir, "bird_predictions")
imp_stat_dir <- file.path(scn_imp_dir, "stats")

# Create missing directories ----------------------------------
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

# Model definitions -------------------------------------------
# Landcovers
landcovers <- c("Rice", "Corn", "Grain", "NonRiceCrops", "TreatedWetland", "Wetland_SemiSeas", "AltCrop")
lc_files <- file.path(lc_dir, paste0(landcovers, "_", scn, ".tif"))

# Bird definitions
bird_df <- data.frame("CommonName" = c("American Avocet", "Black-necked Stilt", "Dowitcher", "Dunlin", 
                                       "Northern Pintail", "Northern Shoveler", "Green-winged Teal"),
                      "CommonCode" = c("AMAV", "BNST", "DOWI", "DUNL", "NOPI", "NSHO", "GWTE"),
                      "ScientificCode" =c("REAM", "HIME", "LISPP", "CALA", "ANAC", "ANCL", "ANCR"))

# Bird models
shorebird_sci_base <- paste(rep(c("CALA", "HIME", "LISPP", "REAM"), each = 2), c("N", "S"), sep = "_")
shorebird_com_base <- paste(rep(c("DUNL", "BNST", "DOWI", "AMAV"), each = 2), c("N", "S"), sep = "_")
# Two models for each species and model type, one for the north valley one and for the south
# Ensemble at (2N + 1S) / 3 for north and (1N + 2S) / 3 for south
# Reallong models that combine long-term and real-time water data
shorebird_model_files_reallong <- file.path(brd_mdl_dir, paste0(shorebird_sci_base, "_Reallong_nopattern_subset.rds"))
shorebird_model_names_reallong <- paste0(shorebird_com_base, "_reallong")

# Long models that just use the long-term average
shorebird_model_files_long <- file.path(brd_mdl_dir, paste0(shorebird_sci_base, "_Long_lowN_subset.rds"))
shorebird_model_names_long <-  paste0(shorebird_com_base, "_longterm")

# Static covariates
bird_model_cov_files <- file.path(cov_dir, c("data_type_constant_ebird_p44r33.tif", "valley_roads_p44r33.tif"))
bird_model_cov_names <- c("COUNT_TYPE2", "roads5km")

# Monthly covariates (tmax)
mths <- month.abb[c(1:4, 7:12)]
tmax_files <- file.path(cov_dir, paste0("tmax_", mths, "_p44r33.tif"))
tmax_months <- mths
tmax_names <- rep("tmax250m", length(mths))
