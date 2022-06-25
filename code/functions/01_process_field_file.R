library(parallel)
library(MASS)
library(rgdal)
library(raster)
library(sp)

# this script took 20 minutes to run on my computer

# Define function to split and buffer flooding areas
# Shapefile must have a column containing the names you wish to group and split the analysis
# Use of buffer_dist is recommended to speed processing; set as 2x your largest moving window
# Returns a vector of created files
split_flooding_area <- function(field_shapefile, field_column_name, guide_raster, output_dir, 
                                do_rasterize = TRUE, buffer_dist = NULL, overwrite = FALSE, 
                                ncores = min(2, detectCores())) {

  # Load required packages
  if (!require(sp)) stop(add_ts("Library sp is required"))
  if (!require(rgdal)) stop(add_ts("Library rgdal is required"))
  if (!require(raster)) stop(add_ts("Library raster is required"))

  # Check simple parameters
  if (!is.logical(do_rasterize)) stop(add_ts("Argument 'rasterize' must be TRUE or FALSE"))
  if (!is.logical(overwrite)) stop(add_ts("Argument 'overwrite' must be TRUE or FALSE"))
  if (!is.null(buffer_dist)) {
    if (!is.numeric(buffer_dist)) stop(add_ts("Argument 'buffer_dist' must either be NULL for no buffering or a number specifying the buffer distance"))
  }

  # Check output dir
  if (!(file.exists(output_dir))) stop(add_ts("output_dir does not exist"))

  # Check and load shapefile
  if (class(field_shapefile) == "SpatialPolygonsDataFrame") {

    field_shp <- field_shapefile

  } else if (is.character(field_shapefile)) {

    if (length(field_shapefile) != 1) stop(add_ts("field_shapefile must be a single shapefile or filename"))
    if (!file.exists(field_shapefile)) stop(add_ts("field_shapefile does not exist: ", field_shapefile, " not found."))

    # Parse and load
    field_dir <- dirname(field_shapefile)
    field_fn <- basename(field_shapefile)
    field_fn <- substr(field_fn, 0, nchar(field_fn) - 4)

    field_shp <- suppressMessages(readOGR(field_dir, field_fn, verbose=FALSE))

  } else {

    stop(add_ts("field_shapefile must be a SpatialPolygonsDataFrame or a filename of an ESRI shapefile"))

  }

  # Check field column name
  if (!(field_column_name) %in% names(field_shp@data)) stop(add_ts("Column ", field_column_name, " does not exist in field_shapefile."))

  # Check and load guide raster
  if (is.raster(guide_raster)) {

    guide_rst <- guide_raster

  } else if (is.character(guide_raster)) {

    if (length(guide_raster) != 1) stop(add_ts("field_shapefile must be a single shapefile or filename"))
    if (!file.exists(guide_raster)) stop(add_ts("field_shapefile does not exist: ", field_shapefile, " not found."))

    guide_rst <- raster(guide_raster)

  } else {

    stop(add_ts("guide_raster must be a raster or filename of a raster"))

  }

  # Reproject shapefile if needed
  if (projection(field_shp) != projection(guide_rst)) {

    message("Reprojecting shapefile to match guide_rst...")
    field_shp <- spTransform(field_shp, crs(guide_rst))

  }


  # Get unique flooding areas
  flooding_areas <- unique(field_shp@data[[field_column_name]])

  process_flooding_areas <- function(fa) {
    clean_name <- clean_string_remove_underscores(fa)
    
    # Split shapefiles ----------------

    fa_file <- file.path(output_dir, paste0(clean_name, ".shp"))

    if (file.exists(fa_file) & overwrite == FALSE) {

      message("Split shapefile for flooding area ", fa, " already created and overwrite == FALSE. Moving to next...")
      return(-1)
      # append to a vector that file has been processed

    } else {

      message("Subsetting area ", fa, "...")
      fa_shp <- field_shp[field_shp[[field_column_name]] == fa,]

      suppressMessages(writeOGR(fa_shp, output_dir, clean_name, driver = "ESRI Shapefile", overwrite_layer=TRUE))
      message("Complete.")

      # append to a vector that file has been processed    

    }
    
    if (do_rasterize == TRUE) {

      fa_rst_file <- file.path(output_dir, paste0(clean_name, ".tif"))

      if (file.exists(fa_rst_file) & overwrite == FALSE) {

        message("Flooding area ", fa, " already rasterized and overwrite == FALSE. Moving to next...")
        return(0) # 0 for file already exists 

      }

      if (is.null(buffer_dist)) {

        message("Rasterizing...")
        fa_rst <- raster::rasterize(fa_shp, guide_rst, field = 1, filename = fa_file, overwrite = TRUE)
        
      } else {

        fa_rst <- raster::rasterize(fa_shp, guide_rst, field = 1) #keep in memory, as overwriting in subsequent call causes error

        message("Rasterizing...")

        # Turn values within buffer distance of field to 2s instead of NAs
        # Used for masking later to speed processing
        # Width is in meters
        message("Calculating ", buffer_dist, "m buffer for", fa, "...")
        fa_buf_rst <- buffer(fa_rst, width = buffer_dist)
        message("Adding buffer to flooding area raster...")
        fa_out_rst <- overlay(x = fa_rst, y = fa_buf_rst, fun = function(x, y) { ifelse(is.na(x) & y == 1, 2, x) },
                              filename = fa_rst_file, overwrite = TRUE)
      }

      message("split_id=", basename(fa_rst_file))
      gc(full=TRUE)
      return(1) # 1 for file was created
    }
  }

  out <- mclapply(flooding_areas, FUN=process_flooding_areas, mc.cores = ncores, mc.silent = FALSE, mc.preschedule = TRUE)
  # out <- lapply(flooding_areas, FUN=process_flooding_areas) 
  res <- unlist(out)
  
  return(res)

}