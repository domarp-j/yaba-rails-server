
FROM ruby:2.3.4

RUN apt-get update && apt-get install -y build-essential libpq-dev
RUN mkdir -p /yaba/server
WORKDIR /yaba/server

COPY Gemfile /yaba/server/Gemfile
COPY Gemfile.lock /yaba/server/Gemfile.lock

RUN bundle install

COPY . /yaba/server
