# yaba (Yet Another Budget App) - Rails Server/API

The Rails server & API for yaba, a simple but intuitive budgeting app.

Check out yaba at [yaba.netlify.com](https://yaba.netlify.com)!

## Setup

Follow the setup instructions on the [yaba-infrastructure](https://github.com/domarp-j/yaba-infrastructure) README. This will set up all of the services needed to get yaba running.

## Running Commands

- After setup, go to your `yaba-infrastructure` directory
- Run `docker-compose run rails-server bash` to bash into the `yaba-rails-server` container
- Run commands as needed (i.e. the static analysis & testing commands below)

## Static Analysis & Testing

- Rubocop `bundle exec rubocop`
- RSpec `bundle exec rspec`

## Deploys

Updates to the master branch are automatically deployed to [Heroku](https://www.heroku.com//).
