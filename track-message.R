library(paws)

sns <- paws::sns()

aws_access_key_id = Sys.getenv("AWS_ACCESS_KEY_ID")
aws_secret_key = Sys.getenv("AWS_SECRET_KEY")
aws_session_token = Sys.getenv("AWS_SESSION_TOKEN")
aws_region = "us-west-2"

topic_arn <- "arn:aws:sns:us-west-2:975050180415:water-tracker-status"

water_tracker <- function() {
  Sys.sleep(5)
  sim <- sample(1:50, 1)
  if (sim == 33) {
    sns$publish(
      TopicArn = topic_arn,
      Message = "COMPLETE - model run complete"
    )
  }
}
