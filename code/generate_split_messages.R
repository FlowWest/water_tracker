# Run split-level analysis

# command line arguments ----------------------------
arguments <- commandArgs(trailingOnly = TRUE)
bid_name <- arguments[1]
auction_id <- arguments[2]
shape_file_name <- arguments[3]
split_column <- arguments[4]

source("sqs-appender.R")
q_url <- "https://sqs.us-west-2.amazonaws.com/975050180415/water-tracker-Q"
logger::log_appender(appender_sqs(bid_name = bid_name, sqs_url = q_url))


tryCatch(source("code/definitions.R"),
         error = \(x) logger::log_error("there was an error trying to source definitions. {x}"),
         warning = \(w) logger::log_warn("there was a warning trying to source definitions. {w}"))

tryCatch(source("code/functions/00_shared_functions.R"),
         error = \(e) logger::log_error("there was an error trying to source shared functions {e}"))

tryCatch(source("code/functions/01_process_field_file.R"),
         error = \(e) logger::log_error("there was an error trying to source 01_process_field_file.R. {e}"))

# Split field file ------------------------------------------
# This section happens once and must complete before any subsequent steps run
# Name of the shapefile

input_bucket <- "auction_2022_spring"
shape_file_dir <- paste0("/mnt/efs/", input_bucket, "/auction/fields")
floodarea_shapefile <- file.path(shape_file_dir, shape_file_name) #YOUR_SHAPEFILE_NAME.shp"

if (!file.exists(floodarea_shapefile)) {
  stop(logger::log_error("the floodarea shapefile was not found"))
}


# Name of the column with names on which to group and split shapefile; should not contain special characters
# This would be the column of field name for a field-level split analysis and the column of the bid for a bid-level one
# If doing a combination, must create a new column as a composite key prior to running


# Reference raster
ref_file <- file.path(covariates_dir, "data_type_constant_ebird_p44r33.tif")
if (!file.exists(ref_file)) {
  stop(logger::log_error("the ref file was not found"))
}

# # Split, rasterize, and buffer field shapefile
# # Function defined in functions/01_process_floodarea_file.R
# floodarea_files <- split_flooding_area(
#     floodarea_shapefile,
#     split_column,
#     guide_raster = ref_file,
#     output_dir = fld_dir, #defined in definitions.R
#     do_rasterize = TRUE, #required for next step
#     buffer_dist = 10000
# )
#
# cat("results from R script: ", floodarea_files)
