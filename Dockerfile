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

# copy all the R code
COPY code/ b4b/code/
COPY track-message.R b4b/
COPY execute.sh b4b/execute.sh
RUN chmod +x b4b/execute.sh

WORKDIR /b4b/ 

# RUN Rscript --no-save code/install_packages.R 


CMD ["/b4b/execute.sh"]
