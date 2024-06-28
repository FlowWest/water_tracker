# Run split-level analysis

# command line arguments ----------------------------
arguments <- commandArgs(trailingOnly = TRUE)
auction_id <- arguments[1]
shape_file_name <- arguments[2]
split_column <- arguments[3]

# source functions and definitions ---------------------
code_dir <- getwd()
suppressMessages(source(file.path(code_dir, "definitions.R")))
suppressMessages(source(file.path(code_dir, "functions/00_shared_functions.R")))
suppressMessages(source(file.path(code_dir, "functions/01_process_field_file.R")))

# Split field file ------------------------------------------
# This section happens once and must complete before any subsequent steps run
# Name of the shapefile

floodarea_shapefile <- file.path(shape_file_dir, shape_file_name) #YOUR_SHAPEFILE_NAME.shp"

# Name of the column with names on which to group and split shapefile; should not contain special characters
# This would be the column of field name for a field-level split analysis and the column of the bid for a bid-level one
# If doing a combination, must create a new column as a composite key prior to running


# Reference raster
ref_file <- file.path(cov_dir, "data_type_constant_ebird_p44r33.tif")

# Split, rasterize, and buffer field shapefile
# Function defined in functions/01_process_floodarea_file.R
floodarea_files <- split_flooding_area(
    floodarea_shapefile,
    split_column,
    guide_raster = ref_file,
    output_dir = fld_dir, #defined in definitions.R
    do_rasterize = TRUE, #required for next step
    buffer_dist = 10000
)

cat("results from R script: ", floodarea_files)