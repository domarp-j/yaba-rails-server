
FROM ruby:2.3.4

RUN apt-get update && apt-get install -y build-essential libpq-dev
RUN mkdir -p /yaba-rails-server
WORKDIR /yaba-rails-server

COPY Gemfile /yaba-rails-server/Gemfile
COPY Gemfile.lock /yaba-rails-server/Gemfile.lock

RUN bundle install

COPY . /yaba-rails-server
