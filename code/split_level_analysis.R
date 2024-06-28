# Run split-level analysis
arguments <- commandArgs(trailingOnly = TRUE)

auction_id <- arguments[1]
split_column <- arguments[2]
water_input_months <- unlist(strsplit(arguments[3], ","))
water_input_files <- unlist(strsplit(arguments[4], ","))

# Load definitions and code
# def_file <- file.path(base_dir, "code/definitions.R")
source("code/definitions.R")

suppressPackageStartupMessages({ # keep the console clean
    source("code/functions/00_shared_functions.R")
    source("code/functions/02_impose_flooding.R")
    source("code/functions/03_water_x_landcover.R")
    source("code/functions/04_water_moving_window.R")
    source("code/functions/05_predict_birds.R")
    source("code/functions/06_extract_predictions.R")
    source("code/functions/07_summarize_predictions.R")
})


# invisible(sapply(c(def_file, code_files), FUN = function(x) source(x)))


# Name of the column with names on which to group and split shapefile; should not contain special characters
# This would be the column of field name for a field-level split analysis and the column of the bid for a bid-level one
# If doing a combination, must create a new column as a composite key prior to running


# Reference raster
ref_file <- file.path(cov_dir, "data_type_constant_ebird_p44r33.tif")



floodarea_files <- list.files(fld_dir, pattern = ".shp$", full.names = TRUE)

# Impose flooding on fields -----------------------------------
# In this section, the number of files becomes water_files * floodarea_files; usually ~120 (3*40)
# One option for parallelization would be to split each field or even each water/field combo into it's own core here and process
# separately until all the bird predictions are done
#
# Specify the (monthly) forecasted (or long-term average) water files to process; usually 3-4 per auction

water_files <- file.path(wfc_dir, water_input_files)

# Specify field files; want tifs, not the shapefiles
floodarea_raster_files <- gsub(".shp", ".tif", floodarea_files)

# Impose flooding
# Function defined in functions/02_impose_flooding.R


cat("IMPOSE FLOODING ---------------------------------------\n")

water_imp_files <- impose_flooding(water_files,
                                   floodarea_raster_files,
                                   output_dir = imp_imp_dir, #imp_imp_dir defined in definitions.R; imp_imp is not a typo
                                   mask = TRUE) #significantly speeds up processing in later steps

# Overlay water and landcover layers --------------------------
# Specify the water water files to process; usually the results of impose_flooding above

# Specify landcover files; lc_dir defined in definitions.R
landcovers <- c("Rice", "Corn", "Grain", "NonRiceCrops", "TreatedWetland", "Wetland_SemiSeas", "AltCrop")
lc_files <- file.path(lc_dir, paste0(landcovers, "_p44r33.tif"))

# Overlay water and landcover
# Function defined in functions/03_water_x_landcover.R

# Overwrite the water imp files var for async processing
water_imp_files <- list.files(imp_imp_dir, full.names = TRUE)
water_imp_files <- water_imp_files[which(grepl(".tif", water_imp_files))]

cat("OVERLAY WATER LANDCOVER --------------------------------------\n")
wxl_files <- overlay_water_landcover(water_imp_files, 
                                     lc_files,
                                     output_dir = imp_wxl_dir) #imp_wxl_dir defined in definitions.R


# Calculate moving windows -------------------------------------
# Use returned filenames from previous function as input; alternatively could define via table or directory search

# Create mean neighborhood water rasters
# Function defined in functions/04_water_moving_window.R
#
# The last iteration produced major performace gains in this step
# message_ts('here is where we will run on cloud')

# Overwrite the wxl_files var for async processing
wxl_files <- list.files(imp_wxl_dir, full.names = TRUE)
wxl_files <- wxl_files[which(grepl(".tif", wxl_files))]

cat("MEAN NEIGHBORHOOD WATER -----------------------------\n")
means_res <- mean_neighborhood_water(wxl_files, #previously-created water x landcover files
                                     distances = c(250, 5000), #250m and 5km
                                     output_dir = imp_fcl_dir,
                                     trim_extent = TRUE) #only set for TRUE with splits

# Overwrite the fcl_files var for async processing
fcl_files <- list.files(imp_fcl_dir, full.names = TRUE)
fcl_files <- fcl_files[which(grepl(".tif", fcl_files))]

# Create bird predictions -------------------------------------
# This is messy because the models need a ton of files from different places.
# Everything is passed via the function call.

# Can pass all fcl_files if divided processing upstream or subset fcl_files here and call multiple instances.
# If splitting, ensure all files from one flooding area and month are included

# water_files_longterm are created by the auction-level analysis
fcl_files_longterm <- list.files(avg_fcl_dir, pattern = "average.*tif", full.names = TRUE) ##############CHANGE###############

# Can subset files using the scenarios parameter, which is applied as a regex filter
scenarios_filter <- "imposed"

# # values passed to model_files, model_names, covariate_files, covariate_names, and monthly_files
# #    will change rarely and are specified in definitions.R

cat("PREDICT BIRDS -------------------------------------------\n")
prd_files <- predict_bird_rasters(fcl_files,
                                    fcl_files_longterm,
                                    scenarios = scenarios_filter,
                                    water_months = water_input_months,
                                    model_files = shorebird_model_files_reallong,
                                    model_names = shorebird_model_names_reallong,
                                    static_cov_files = bird_model_cov_files,
                                    static_cov_names = bird_model_cov_names,
                                    monthly_cov_files = tmax_files,
                                    monthly_cov_months = tmax_months,
                                    monthly_cov_names = tmax_names,
                                    output_dir = imp_prd_dir)



# Overwrite the prd_files var for async processing
prd_files <- list.files(imp_prd_dir, full.names = TRUE)

# Extract bird predictions ----------------------------------------

# Column that contains the names of the fields to extract prediction data for
# Fields with the same name in a flooding area are grouped
cat("EXTRACT PREDS --------------------------------\n")
stat_files <- extract_predictions(prd_files,
                                  floodarea_files,
                                  field_column = split_column,
                                  area_column = "Acres",
                                  output_dir = imp_stat_dir)


# RUN AFTER ALL SPLITS ARE DONE
# Combine bird predictions -----------------------------------------
# This can only be run after every prediction has finished and all have been extracted
stat_files <- list.files(imp_stat_dir, pattern = ".*summary.rds$", full.names = TRUE)
message("the stat files: ", stat_files)

stat_df <- do.call(rbind, lapply(stat_files, function(x) readRDS(x)))
write.csv(stat_df, file.path(imp_stat_dir, "combined_stats.csv"), row.names = FALSE)

# summary_files <- summarize_predictions(stat_files,
#                                        metadata_csv_file = file.path(fld_dir, "bid_metadata.csv"),
#                                        output_dir = imp_stat_dir)

# summary_files <- list.files(imp_stat_dir, full.names = TRUE)
# print("----------------------------------------------------------------------------------------------------")
# message_ts(summary_files)
