# Moving window analysis

# Function to calculate moving window sums of water
# Takes water (by landcover) files and distances as input
# Distance is in meters
# Returns a vector of created files
mean_neighborhood_water <- function(water_files, distances, output_dir, trim_extent = FALSE, overwrite = FALSE) {

  # Load required packages
  if (!require(rgdal, quietly = TRUE)) stop(logger::log_error("Library rgdal is required"))
  if (!require(raster, quietly = TRUE)) stop(logger::log_error("Library raster is required"))

  # Check input files
  if (!all(file.exists(water_files))) stop(logger::log_error("The following water_files do not exist:\n",
                                                  paste0(water_files[!file.exists(water_files)], collapse = ", ")))

  # Check distances
  if (!is.numeric(distances)) stop(logger::log_error("Argument 'distances' must be a numeric vector"))

  # Check output dir
  if (!(file.exists(output_dir))) stop(logger::log_error("output_dir does not exist"))

  # Check other parameters
  if (!is.logical(trim_extent)) stop(logger::log_error("Argument 'trim_extent' must be TRUE or FALSE"))
  if (!is.logical(overwrite)) stop(logger::log_error("Argument 'overwrite' must be TRUE or FALSE"))

  # Initialize output
  processed_files <- c()

	# Loop across passed water files
	for (wf in water_files) {

		wfn <- basename(wf)
		logger::log_info("Summing neighborhood water for water file {wfn}")

		# Check output files
		out_files <- file.path(output_dir, paste0(substr(wfn, 0, nchar(wfn) - 4), "_", distances, "m.tif"))
		if (all(file.exists(out_files)) & overwrite != TRUE) {

			# Append to output
			processed_files <- c(processed_files, out_files)


			logger::log_info("All moving windows calculated for this file. Moving to next...")
			next

		}

		# Load
		wtr_rst <- raster(wf)

		# Trim NAs before processing if requested (can dramatically speed up processing)
		if (trim_extent) {

			logger::log_info("Trimming water file to remove rows and columns that contain no data (only NAs)...")

			# Use custom trim function; base raster function is ridiculously slow
			wtr_rst <- trim_faster(wtr_rst)

		}

		# Loop across passed distancess
		for (d in distances) {

			logger::log_info("Creating focal matrix for distances ", d, "m...")
			fwm <- focalWeight(wtr_rst, d, type = "circle")

			# Check file existence
			out_file <- file.path(output_dir, paste0(substr(wfn, 0, nchar(wfn) - 4), "_", d, "m.tif"))
			if (file.exists(out_file) & overwrite != TRUE) {

				logger::log_info("File already processed and overwrite not set to TRUE. Moving to next...")
			  next

			}

			# Calculate moving window
			logger::log_info("Calculating moving window...")
			logger::log_info("Output file: ", out_file)
			fcl_rst <- focal(wtr_rst, fwm, fun = mean, na.rm = TRUE, filename = out_file, overwrite = TRUE)
			logger::log_info("Complete.")

			# Append to output
			processed_files <- c(processed_files, out_file)

		}

	}

	# Return
	return(processed_files)

}
