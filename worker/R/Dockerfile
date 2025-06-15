FROM rocker/tidyverse:4.2.2     

RUN apt -y update && apt -y install locales
RUN echo "ja_JP UTP-8" > /etc/locale.gen
RUN locale-gen

RUN install2.r RPostgreSQL
  
