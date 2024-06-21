library(paws)

aws_access_key_id <- Sys.getenv("AWS_ACCESS_KEY_ID")
aws_secret_access_key <- Sys.getenv("AWS_SECRET_ACCESS_KEY")
aws_session_token <- Sys.getenv("AWS_SESSION_TOKEN")


sns <- paws::sns(region="us-west-2",
                 credentials = list(
                   creds = list(
                     access_key_id = aws_access_key_id,
                     secret_access_key = aws_secret_access_key,
                     session_token = aws_session_token
                   )
                 ))

topic_arn <- "arn:aws:sns:us-west-2:975050180415:water-tracker-status"

water_tracker <- function() {
  target <- 10
  n <- 1
  sim <- sample(1:10, 1)
  while (sim != target) {
    sim <- sample(1:10, 1)
    sns$publish(
                TopicArn = topic_arn,
                Message = paste("at step:", n, "the value generated:", sim)
    )
    n <- n + 1
    Sys.sleep(5)

  }
    sns$publish(
      TopicArn = topic_arn,
      Message = "COMPLETE - model run complete"
    )
    return(0)
}

water_tracker()
