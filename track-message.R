library(paws)

aws_access_key_id <- Sys.getenv("AWS_ACCESS_KEY_ID")
aws_secret_access_key <- Sys.getenv("AWS_SECRET_ACCESS_KEY")
aws_session_token <- Sys.getenv("AWS_SESSION_TOKEN")

args <- commandArgs(trailingOnly = TRUE)

bid_name <- args[1]
bid_input_bucket <- args[2]
bid_auction_id <- args[3]
bid_auction_shapefile <- args[4]
bid_split_id <- args[5]
bid_id <- args[6]
selected_months <- args[7]
bid_waterfiles <- args[8]
bid_output_bucket <- args[9]

all_inputs  <- c(
    bid_name,
    bid_input_bucket,
    bid_auction_id,
    bid_auction_shapefile,
    bid_split_id,
    bid_id,
    selected_months,
    bid_waterfiles,
    bid_output_bucket
)



sqs <- paws::sqs(region="us-west-2",
                 credentials = list(
                   creds = list(
                     access_key_id = aws_access_key_id,
                     secret_access_key = aws_secret_access_key,
                     session_token = aws_session_token
                   )
                 ))

Q_url <- "https://sqs.us-west-2.amazonaws.com/975050180415/water-tracker-Q"

water_tracker <- function() {
  for (i in 1:10) {
    Sys.sleep(5)
    sqs$send_message(
      QueueUrl = Q_url,
      MessageBody = paste("The values of the inputs are:", paste0(all_inputs, collapse = ",")),
      MessageAttributes = list(
        bid_name = list(
          DataType = "String",
          StringValue = "fdsa"
        )
      )
    )
  }
    return(0)
}

water_tracker()
