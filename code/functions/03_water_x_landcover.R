# Create water x landcover overlays
options("rgdal_show_exportToProj4_warnings"="none")
# Function to overlay water and landcover files
# Takes water and landcover files as inputs
# Returns a vector of created files
overlay_water_landcover <- function(water_files, landcover_files, output_dir = NULL, overwrite = FALSE) {

  # Load required packages
  if (!require(rgdal, quietly = TRUE, warn.conflicts = FALSE)) stop(add_ts("Library rgdal is required"))
  if (!require(raster, quietly = TRUE, warn.conflicts = FALSE)) stop(add_ts("Library raster is required"))

  # Check input files
  if (!all(file.exists(water_files))) stop(add_ts("The following water_files do not exist:\n",
                                                  paste0(water_files[!file.exists(water_files)], collapse = ", ")))
  if (!all(file.exists(landcover_files))) stop(add_ts("The following landcover_files do not exist:\n",
                                                  paste0(landcover_files[!file.exists(landcover_files)], collapse = ", ")))

  # Check output dir
  if (!(file.exists(output_dir))) stop(add_ts("output_dir does not exist"))

  # Check other parameters
  if (!is.logical(overwrite)) stop(add_ts("Argument 'overwrite' must be TRUE or FALSE"))

  # Initialize output
  processed_files <- c()

	# Loop across passed water files
	for (wf in water_files) {

		wfn <- basename(wf)
		logger::log_info("creating landcover overlays for water file {wfn}")
		# Check output files
		out_files <- file.path(output_dir, paste0(substr(wfn, 0, nchar(wfn) - 4), "_x_", basename(landcover_files)))
		if (all(file.exists(out_files)) & overwrite != TRUE) {

			# Append to output
			processed_files <- c(processed_files, out_files)

			logger::log_info("All water x landcover overlays created for this file, moving to next...")
			next
		}

		# Load
		wtr_rst <- raster(wf)

		# Loop across passed landcover files
		logger::info("processing landcover files: {landcover_files}")
		for (lcf in landcover_files) {

			lcfn <- basename(lcf)
			logger::log_info("calculating overlay for {lcfn}")

			# Load
			lc_rst <- raster(lcf)

			# Check file existence and whether or not to overwrite
			out_file <- file.path(output_dir, paste0(substr(wfn, 0, nchar(wfn) - 4), "_x_", lcfn))
			if (file.exists(out_file) & overwrite != TRUE) {
			  logger::log_info("file already processed and overwrite is set to FALSE, moving to next...")
			  next
			}

			# Create overlay
			logger::log_info("overlaying water and landcover...")
			logger::log_info("output file: {out_file}")
			wxl_rst <- overlay(x = wtr_rst, y = lc_rst, fun = function(x, y) {x * y}, filename = out_file, overwrite = overwrite)
		  logger::log_info("Complete.")

		  # Append to output
		  processed_files <- c(processed_files, out_file)

		}

	}

  # Return
  return(processed_files)

}
