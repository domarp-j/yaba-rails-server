# yaba (Yet Another Budget App) - Rails Server/API

The Rails server & API for yaba, a simple but intuitive budgeting app.

## Setup

Follow the setup instructions on `yaba-infrastructure`'s README. This will set up all of the services needed (including this one) to get the app running.

Note: You will have to prepend app-specific commands with `docker-compose run rails-server`. To make life less tedious, you can run `docker-compose run rails-server bash` and run commands as normal from within the `rails-server` container.

## Static Analysis & Testing

- Rubocop `docker-compose run rails-server bundle exec rubocop`
- RSpec `docker-compose run rails-server bundle exec rspec`

## Deploys

Updates to the master branch are automatically deployed to [Heroku](https://www.heroku.com//).
