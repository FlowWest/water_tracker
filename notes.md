# Bid for Birds Computation 

_These are a set of notes I took while recreating the cloud infrastrcutre on GCP
for this project._

---

## Introduction 

Here are the steps I listed out as necesary to carry out this computation:
 

1. Be able to spin up a Virtual Machine with software deps already installed
   - for this step I will use Docker and GCP's Artifact Registry in order to have a an easy to access image that can be loaded whenever I create an VM.
2. Be able to bring in the water_tracker code into the machine
   - for this step I will make use of github actions and push 
3. Be able to bring all the software deps into the machine 



## Dockerfile 

The docker container for the project will be based of the debian and
using the base image: `r-base:latest` from the Rocker R project. In addition the dockerfile
will handle installing all deps for the project to run, including software and all code.



## Github Action

TODO