#!/bin/bash

### stop on an error
set -e

echo "starting exectution"

export GDAL_PAM_ENABLED=NO

# get the latest data from storage
echo "copying files from GCS..."
# Copy data from S3 to local storage
aws s3 cp s3:bid-runner-input-2024/auction_2022_spring/ ./data --recursive

# echo "generating split level files..."
# time Rscript --no-save code/generate_split_messages.R auction_2022_spring Bid4Birds_Fields_Spring2022_metadata_utm10.shp Splt_ID

# echo "complete."
#
# echo "running split-level anlysis..."
# #time Rscript --no-save code/split_level_analysis.R auction_2022_spring Splt_ID Mar,Apr,May\
# # p44r33_forecast_Feb_2022.tif,p44r33_forecast_Mar_2022.tif,p44r33_forecast_Apr_2022.tif,p44r33_forecast_May_2022.tif
# touch data/hello.txt
#
# echo "copying output to bucket..."
# gsutil -m cp -r data/auction_2022_spring/auction/ "gs://bid4birds-output"
# echo "copying to GCS complete"
#
# echo "complete"
#
