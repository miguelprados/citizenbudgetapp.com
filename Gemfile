source 'https://rubygems.org'

ruby '1.9.3'
gem 'rails', '3.2.16'
gem 'rails-i18n'

group :production do
  # Non-Heroku deployments
  gem 'foreman'

  # Error logging
  gem 'airbrake'
  gem 'heroku'

  # Performance
  gem 'memcachier'
  gem 'dalli'
  gem 'newrelic_rpm', '3.5.3.25'
end

# Background jobs
gem 'girl_friday'

# Database
gem 'mongoid', '~> 3.0.12'

# Admin
gem 'formtastic', '2.2.1'
# Waiting for 0.6.1
gem 'activeadmin', git: 'git://github.com/gregbell/active_admin.git', ref: '9d6656316929cab7954aed0be0dbe7e91f5d8462'
# Waiting for 0.0.2
gem 'activeadmin-mongoid', git: 'git://github.com/elia/activeadmin-mongoid.git', ref: '83183a6a9daa4e2d4a62bb010025a50c4a10049a'
gem 'cancan'
gem 'devise', '~> 2.1.3'
gem 'devise-i18n'
gem 'google-api-client', require: 'google/api_client'
gem 'mustache'

# Image uploads
gem 'fog'
gem 'rmagick'
gem 'carrierwave-mongoid', '~> 0.4.0'

# Views
gem 'haml-rails'
gem 'rdiscount'
gem 'unicode_utils'

# Export
gem 'spreadsheet'
gem 'axlsx', '1.3.5'

# Heroku API
gem 'oj'
gem 'multi_json'
gem 'faraday'

# Rake
gem 'ruby-progressbar'

# Gems used only for assets and not required
# in production environments by default.
group :assets do
  # Non-Heroku deployments
  # gem 'therubyracer', require: 'v8'

  gem 'sass-rails',   '~> 3.2.3'
  gem 'coffee-rails', '~> 3.2.1'
  gem 'uglifier', '>= 1.0.3'
end

gem 'jquery-rails'

# For maintenance scripts to run in development console.
group :development do
  gem 'mechanize'
end

group :development, :test do
  gem 'rspec-rails', '~> 2.6'
end

gem 'unicorn'
