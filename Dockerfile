FROM 975050180415.dkr.ecr.us-west-2.amazonaws.com/r-for-b4b:latest 

# # create dirs 
# RUN mkdir b4b
# RUN mkdir -p b4b/data/
# RUN mkdir -p b4b/code/
# RUN mkdir -p b4b/output/
#
# RUN apt-get update  
# RUN apt-get install -y \
#  apt-transport-https\
#  ca-certificates\
#  curl\
#  gnupg\
#  libcurl4-openssl-dev\
#  libssl-dev\
#  libxml2-dev\
#  libgdal-dev\
#  git
ENV AWS_DEFAULT_REGION=us-west-2

# copy all the R code
COPY code/ b4b/code/
COPY track-message.R b4b/
COPY execute.sh b4b/execute.sh
RUN chmod +x b4b/execute.sh

WORKDIR /b4b/ 

RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y && . "$HOME/.cargo/env"

RUN apt-get update && \
    apt-get -y install git binutils rustc cargo pkg-config libssl-dev && \
    git clone https://github.com/aws/efs-utils && \
    cd efs-utils && \
    ./build-deb.sh && \
    apt-get -y install ./build/amazon-efs-utils*deb

CMD ["/b4b/execute.sh"]
