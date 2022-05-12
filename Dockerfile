FROM r-base:latest

# create dirs 
RUN mkdir b4b
RUN mkdir -p b4b/data/
RUN mkdir -p b4b/code/
RUN mkdir -p b4b/output/

RUN apt-get update  
RUN apt-get install -y \
 apt-transport-https\
 ca-certificates\
 curl\
 gnupg\
 libcurl4-openssl-dev\
 libssl-dev\
 libxml2-dev\
 libgdal-dev\
 git

RUN curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | tee /usr/share/keyrings/cloud.google.gpg
RUN echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] http://packages.cloud.google.com/apt cloud-sdk main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list && curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | tee /usr/share/keyrings/cloud.google.gpg && apt-get update -y && apt-get install google-cloud-sdk -y

# copy all the R code
COPY code/ b4b/code/
COPY execute.sh b4b/execute.sh
RUN chmod +x b4b/execute.sh

WORKDIR /b4b/ 

RUN Rscript --no-save code/install_packages.R 

# CMD ["Rscript", "--no-save", "/02_code/run.R"]

CMD ["/b4b/execute.sh"]
