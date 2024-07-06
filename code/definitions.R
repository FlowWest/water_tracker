# Defines project directories and input file characteristics
#
# Point Blue, California Rice Commission

source("sqs-appender.R")
q_url <- "https://sqs.us-west-2.amazonaws.com/975050180415/water-tracker-Q"
logger::log_appender(appender_sqs(bid_name = bid_name, sqs_url = q_url))

logger::log_info("setting defintions using `definitions.R`")
# Set directories ---------------------------------------------
base_dir <- "." #getwd() #replace as necessary with "YOUR/BASE/DIR"
code_dir <- file.path(base_dir, "code")
data_dir <- file.path("/mnt/efs/auction_2022_spring")

landcover_dir <- file.path(data_dir, "landcover")
runoff_dir <- file.path(data_dir, "runoff")
precip_dir <- file.path(data_dir, "precip")
water_dir <- file.path(data_dir, "water")
water_average_dir <- file.path(data_dir, "water_average")
water_forecast_dir <- file.path(data_dir, "water_forecast")
covariates_dir <- file.path(data_dir, "other_covariates")

models_dir <- file.path(data_dir, "models")
bird_models_dir <- file.path(models_dir, "birds")

# Auction-specific files
axn_dir <- file.path(data_dir, "2022-03-wetlands")
fields_dir <- file.path(axn_dir, "fields")
split_dir <- file.path(fields_dir, "splits")

# Average flooding (auction-level)
scn_avg_dir <- file.path(axn_dir, "scenario_average_water")
avg_wtr_dir <- file.path(scn_avg_dir, "water")
avg_wxl_dir <- file.path(scn_avg_dir, "water_x_landcover")
avg_fcl_dir <- file.path(scn_avg_dir, "water_focal")
avg_prd_dir <- file.path(scn_avg_dir, "bird_predictions")
avg_stat_dir <- file.path(scn_avg_dir, "stats")

# Imposed flooding (field or bid-level)
scn_imp_dir <- file.path(axn_dir, "scenario_imposed_water")
imp_wtr_dir <- file.path(scn_imp_dir, "water_imposed")
imp_wxl_dir <- file.path(scn_imp_dir, "water_x_landcover")
imp_fcl_dir <- file.path(scn_imp_dir, "water_focal")
imp_prd_dir <- file.path(scn_imp_dir, "bird_predictions")
imp_stat_dir <- file.path(scn_imp_dir, "stats")

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
shorebird_model_files_reallong <- file.path(bird_models_dir, paste0(shorebird_sci_base, "_Reallong_nopattern_subset.rds"))
shorebird_model_names_reallong <- paste0(shorebird_com_base, "_reallong")

# Long models that just use the long-term average
shorebird_model_files_long <- file.path(bird_models_dir, paste0(shorebird_sci_base, "_Long_lowN_subset.rds"))
shorebird_model_names_long <-  paste0(shorebird_com_base, "_longterm")

# Static covariates
#bird_model_cov_files <- file.path(cov_dir, c("data_type_constant_ebird_p44r33.tif", "valley_roads_p44r33.tif"))
bird_model_cov_files <- file.path(covariates_dir, c("data_type_constant_ebird_valley.tif", "valley_roads_valley.tif"))
bird_model_cov_names <- c("COUNT_TYPE2", "roads5km")

# Monthly covariates (tmax)
#mths <- month.abb[c(1:5, 7:12)] #no June
mths <- month.abb[4]
#tmax_files <- file.path(cov_dir, paste0("tmax_", mths, "_p44r33.tif"))
tmax_files <- file.path(covariates_dir, paste0("tmax_", mths, "_valley_snapped2.tif"))
tmax_months <- mths
tmax_names <- rep("tmax250m", length(mths))


logger::log_info("setting defintions using `definitions.R` - DONE")
