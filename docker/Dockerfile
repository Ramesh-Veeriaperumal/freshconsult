# our base image
FROM ruby:2.2

# File Author / Maintainer
MAINTAINER Arvind Ravindran(arvind.ravindran@freshworks.com)

#Install necessary packages and do the necessary setup
ENV BUILD_PACKAGES ruby-dev libxml2-dev libxslt-dev libffi-dev libmysqld-dev mysql-client ruby-nokogiri cmake musl build-essential \
libcurl4-openssl-dev openssl libreadline6 libreadline6-dev curl git-core zlib1g zlib1g-dev \
libssl-dev libyaml-dev libsqlite3-0 libsqlite3-dev sqlite3 autoconf libc6-dev ncurses-dev automake libtool bison libicu-dev vim
RUN apt-get update -qq && apt-get install -y $BUILD_PACKAGES

RUN gem uninstall -i /usr/local/lib/ruby/gems/2.2.0 bundler
RUN gem install bundler -v 1.10.6 --no-ri --no-rdoc --conservative 

RUN mkdir -p /root/.ssh
RUN touch ~/.ssh/known_hosts

#App Setup
ENV APP_HOME /data/helpkit/current
RUN mkdir -p $APP_HOME
WORKDIR $APP_HOME




