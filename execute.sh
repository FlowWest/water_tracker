#!/bin/bash

QUEUE_URL="https://sqs.us-west-2.amazonaws.com/975050180415/water-tracker-Q"

### stop on an error
set -e

# capture cl arguments
bid_name=$1
input_bucket=$2
auction_id=$3
auction_shapefile=$4
split_id=$5
bid_id=$6
bid_monts=$7
waterfiles=$8
output_bucket=$9

MESSAGE_ATTRIBUTES="{
    \"bid_name\": {
        \"DataType\": \"String\",
        \"StringValue\": \"$bid_name\"
    }
}"

aws sqs send-message \
    --queue-url "$QUEUE_URL" \
    --message-body "TESTING IF THIS WORKS!!!!!!!!!!!!!" \
    --message-attributes "$MESSAGE_ATTRIBUTES"

# aws sqs send-message --queue-url "$QUEUE_URL" --message-body "[docker run] - Excutation of execute.sh started"
#
# export GDAL_PAM_ENABLED=NO
# aws sqs send-message --queue-url "$QUEUE_URL" --message-body "[docker run] - Setting GDAL_PAM_ENABLED to No"
#
# # get the latest data from storage
# echo "copying files from S3"
# aws sqs send-message --queue-url "$QUEUE_URL" --message-body "[docker run] - Copying files from S3 for model inputs"
# aws sqs send-message --queue-url "$QUEUE_URL" --message-body "[docker run] - done running for now"


# Copy data from S3 to local storage
#aws s3 cp s3:bid-runner-input-2024/auction_2022_spring/ ./data --recursive

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
