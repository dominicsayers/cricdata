# frozen_string_literal: true

source 'http://rubygems.org'

ruby '4.0.1'

gem 'bson_ext'
gem 'mongo'
gem 'mongoid', git: 'https://github.com/mongodb/mongoid'
gem 'moped'
gem 'nokogiri'
gem 'rails', '~> 8.1.2'
gem 'rails_12factor'
gem 'thin'

# Gems used only for assets and not required
# in production environments by default.
group :assets do
  gem 'coffee-rails'
  gem 'sass-rails'
  gem 'uglifier'
end

# Javascript libs
gem 'jquery-rails'
gem 'modernizr-rails'

group :test, :development do
  gem 'rubocop', require: false
  gem 'rubocop-rails', require: false
  gem 'rubocop-rake', require: false
end
