# Code to combine all bird prediction stats into a single file and do preliminary analysis
#

# TODO: add parameters for joining data
summarize_predictions <- function(stat_files, metadata_csv_file, output_dir, overwrite = FALSE) {

  # Load required packages
  if (!require(rgdal)) stop(add_ts("Library rgdal is required"))
  if (!require(raster)) stop(add_ts("Library raster is required"))
  if (!require(dplyr)) stop(add_ts("Library dplyr is required"))
  if (!require(tidyr)) stop(add_ts("Library tidyr is required"))

  # Check input files
  if (!all(file.exists(stat_files))) stop(add_ts("The following stat_files do not exist:\n",
                                                       paste0(stat_files[!file.exists(stat_files)], collapse = ", ")))

  if (!(file.exists(metadata_csv_file))) stop(add_ts("metadata_csv_file does not exist"))

  # Check output dir
  if (!(file.exists(output_dir))) stop(add_ts("output_dir does not exist"))

  # Check other parameters
  if (!is.logical(overwrite)) stop(add_ts("Argument 'overwrite' must be TRUE or FALSE"))

  # Initialize output
  processed_files <- c()
  
  # Read metadata
  #md_df <- read.csv(metadata_csv_file, stringsAsFactors = FALSE)
  md_shp <- readOGR(fld_dir, "BirdReturns_D-SOD_Winter_2022-23_Ponds")
  md_df <- md_shp@data
  md_df$BidFieldID <- paste0(md_df$BidID, "-", clean_string(md_df$FieldID))
  write.csv(md_df, file.path(fld_dir, "field_metadata.csv"), row.names = FALSE)
  
  # Read data
  long_file <- file.path(output_dir, "00_prediction_summary_long.csv")
  if (file.exists(long_file) & overwrite != TRUE) {
    
    message_ts("File already exists and overwrite != TRUE. Loading already-combined data...")
    long_df <- read.csv(long_file)
    
  } else {
    
    message_ts("Reading and combining data...")
    long_df <- do.call(rbind, lapply(stat_files, function(x) readRDS(x)))
    
    write.csv(long_df, long_file, row.names = FALSE)
    message_ts("Exported.")
    
    processed_files <- c(processed_files, long_file)
    
  }
  
  # Join to metadata
  # Must be unique -- If Flooding area is bid+field, use that alone
  # Otherwise, use bid + field.  If field lost, use bid + acres
  #join_col <- "BidID" #add as argument
  #joined_df <- left_join(long_df, md_df, by = c("FloodingArea" = join_col))
  #joined_df <- left_join(long_df, md_df, by = c("FloodingArea" = "BidID", "FieldAreaAcres" = "AreaAcres"))
  joined_df <- left_join(long_df, md_df, by = c("FloodingArea" = "BidFieldID"))
  
  # Fix bid ID
  joined_df <- mutate(joined_df, BidID = gsub("SDW", "-SDW-", BidID))
  
  # Fix county
  cty_df <- read.csv(file.path(fld_dir, "delta_sod_wetland_counties.csv"))
  names(cty_df)[1] <- "BidID"
  cty_df <- cty_df[c("BidID", "County")]
  names(cty_df)[2] <- "County2"
  joined_df <- left_join(joined_df, cty_df, by = c("BidID" = "BidID"))
  joined_df$County <- ifelse(is.na(joined_df$County) | joined_df$County == "", joined_df$County2, joined_df$County)
  
  # Fix date if needed
  # TODO - check format
  joined_df <- joined_df %>%
    mutate(StartDate = as.Date(StartDate, format = "%Y/%m/%d"),
           EndDate = as.Date(EndDate, format = "%Y/%m/%d"))
  
  # Overlap
  joined_df <- joined_df %>%
    mutate(PredictionDateStart = as.Date(paste0(ifelse(PredictionMonth %in% c("Oct", "Nov", "Dec"), "2022", "2023"), 
                                                "-", match(PredictionMonth, month.abb), "-01")), #need to fix year somehow
           PredictionDateEnd = as.Date(paste0(ifelse(PredictionMonth %in% c("Oct", "Nov", "Dec"), "2022", "2023"),
                                              "-", match(PredictionMonth, month.abb), "-", 
                                              ifelse(PredictionMonth == "Feb", "28",
                                                     ifelse(PredictionMonth %in% c("Apr", "Jun", "Sep", "Nov"), "30", "31")))),
           FloodDateStart = as.Date(StartDate, format = "%Y/%m/%d"),
           FloodDateEnd = as.Date(EndDate, format = "%Y/%m/%d")) %>%
    mutate(OverlapMin = pmax(as.Date(FloodDateStart), PredictionDateStart), 
           OverlapMax = pmin(as.Date(FloodDateEnd), PredictionDateEnd),
           DaysOverlap = pmax(0, difftime(OverlapMax, OverlapMin, unit = "days")) + 1)

  # Fix field name
  #joined_df <- rename(joined_df, FieldName = Field_Name, Property = Prop_Name, ReportedAcres = Report_Ac)
  
  # Export
  long_file <- file.path(output_dir, "01_prediction_summary_joined.csv")
  if (file.exists(long_file) & overwrite != TRUE) {
    message_ts("File already exists and overwrite != TRUE. Moving to next...")
  } else {
    write.csv(joined_df, long_file, row.names = FALSE)
    message_ts("Exported.")
    processed_files <- c(processed_files, long_file)
  }

  # Calculate ensembles
  message_ts("Calculating ensembles...")
  ens_df <- joined_df %>%
    #rename(Bid = BidID) %>%
    #mutate(Bid = FloodingArea) %>% # if bid is the flooding area unit
    group_by(FloodingArea, BidID, FieldID, Split, FieldAreaAcres, PricePerAc, County, PredictionMonth, 
             FloodDateStart, FloodDateEnd, DaysOverlap, Species, Model) %>%
    mutate(EnsembleWeights = ifelse(ModelLocation == "S", 1, 2)) %>%
    summarize(SuitabilityMean = weighted.mean(PredictionMean, EnsembleWeights),
              SuitabilitySum = sum(PredictionSum * EnsembleWeights / 3),
              LandscapeMean = weighted.mean(PredictionMean_Landscape, EnsembleWeights),
              LandscapeSum = sum(PredictionSum_Landscape * EnsembleWeights / 3)) %>%
    mutate(PredictionMonth = factor(PredictionMonth, levels = month.abb, ordered = TRUE)) %>%
    arrange(FloodingArea, BidID, FieldID, PredictionMonth)

  ## SUMMARIZE BY FIELD ##
  fld_df <- filter(ens_df, Split == TRUE | Split == "Y" | Split == 1, DaysOverlap > 0)
  
  # Export (ensembles)
  fld_file <- file.path(output_dir, "02_prediction_summary_field.csv")
  if (file.exists(fld_file) & overwrite != TRUE) {
    message_ts("File already exists and overwrite != TRUE. Moving to next...")
  } else {
    write.csv(fld_df, fld_file, row.names = FALSE)
    message_ts("Exported.")
    processed_files <- c(processed_files, fld_file)
  }
  
  # Combine by month
  fld_cmb_df <- fld_df %>%
    group_by(FloodingArea, BidID, FieldID, Split, FieldAreaAcres, PricePerAc, County, FloodDateStart, FloodDateEnd, Species) %>%
    summarize(PredictionYear = "Combined", PredictionMonth = "Combined", BidLength = sum(DaysOverlap),
              SuitMean = weighted.mean(SuitabilityMean, DaysOverlap),
              SuitSum = sum(SuitabilityMean * DaysOverlap * FieldAreaAcres), 
              LandscapeMean = weighted.mean(LandscapeMean, DaysOverlap))
  
  # Export
  fld_cmb_file <- file.path(output_dir, "02a_prediction_summary_field_across_months.csv")
  if (file.exists(fld_cmb_file) & overwrite != TRUE) {
    message_ts("File already exists and overwrite != TRUE. Moving to next...")
  } else {
    write.csv(fld_cmb_df, fld_cmb_file, row.names = FALSE)
    message_ts("Exported.")
    processed_files <- c(processed_files, fld_cmb_file)
  }
  
  # Calculate totals across species
  fld_wide_df <- fld_cmb_df %>%
    select(-PredictionYear, - PredictionMonth, - LandscapeMean) %>%
    pivot_wider(names_from = Species, values_from = c(SuitMean, SuitSum)) %>%
    mutate(SuitMean_Total = mean(c(SuitMean_AMAV, SuitMean_BNST, SuitMean_DOWI, SuitMean_DUNL)),
           SuitSum_Total = sum(c(SuitSum_AMAV, SuitSum_BNST, SuitSum_DOWI, SuitSum_DUNL)))
  
  # Export
  fld_wide_file <- file.path(output_dir, "02b_prediction_summary_field_totals_wide.csv")
  if (file.exists(fld_wide_file) & overwrite != TRUE) {
    message_ts("File already exists and overwrite != TRUE. Moving to next...")
  } else {
    write.csv(fld_wide_df, fld_wide_file, row.names = FALSE)
    message_ts("Exported.")
    processed_files <- c(processed_files, fld_wide_file)
  }
  
  
  ## BY BID ##
  
  ## TODO: make it easier to add columns
  
  # Summarize by bid
  # Field-level stats calculated above for splittable fields, so summarize at bid level here
  message_ts("Summarizing by bid...")
  fa_df <- ens_df %>%
    filter(DaysOverlap > 0) %>%
    ungroup() %>%
    group_by(BidID, County, PredictionMonth, FloodDateStart, FloodDateEnd, DaysOverlap, Species, Model) %>%
    summarize(FieldsIncluded = paste0(FieldID, collapse = ", "),
              AreaAcres = sum(FieldAreaAcres), 
              PricePerAc = weighted.mean(PricePerAc, FieldAreaAcres),
              SuitabilityMean = weighted.mean(SuitabilityMean, FieldAreaAcres),
              SuitabilitySum = sum(SuitabilitySum),
              LandscapeMean = weighted.mean(LandscapeMean, FieldAreaAcres))
  
  # Export
  fa_file <- file.path(output_dir, "03_prediction_summary_bid.csv")
  if (file.exists(fa_file) & overwrite != TRUE) {
    message_ts("File already exists and overwrite != TRUE. Moving to next...")
  } else {
    write.csv(fa_df, fa_file, row.names = FALSE)
    message_ts("Exported.")
    processed_files <- c(processed_files, fa_file)
  }
  
  # Combine by month
  fa_cmb_df <- fa_df %>%
    group_by(BidID, FieldsIncluded, AreaAcres, PricePerAc, County, FloodDateStart, FloodDateEnd, Species) %>%
    summarise(PredictionYear = "Combined", PredictionMonth = "Combined", BidLength = sum(DaysOverlap),
              SuitMean = weighted.mean(SuitabilityMean, DaysOverlap),
              SuitSum = sum(SuitabilityMean * DaysOverlap * AreaAcres), LandscapeMean = weighted.mean(LandscapeMean, DaysOverlap))
  
  # Export
  fa_cmb_file <- file.path(output_dir, "03a_prediction_summary_bid_across_months.csv")
  if (file.exists(fa_cmb_file) & overwrite != TRUE) {
    message_ts("File already exists and overwrite != TRUE. Moving to next...")
  } else {
    write.csv(fa_cmb_df, fa_cmb_file, row.names = FALSE)
    message_ts("Exported.")
    processed_files <- c(processed_files, fa_cmb_file)
  }
  
  # Calculate totals 