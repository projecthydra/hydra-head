$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))

ENV["RAILS_ENV"] ||= "test"

require File.expand_path("config/environment", ENV['RAILS_ROOT'] || File.expand_path("../internal", __FILE__))
require 'bundler/setup'
require 'rspec/rails'
require 'rspec/autorun'
require 'hydra-core'

if ENV['COVERAGE'] and RUBY_VERSION =~ /^1.9/
  require 'simplecov'
  require 'simplecov-rcov'

  SimpleCov.formatter = SimpleCov::Formatter::RcovFormatter
  SimpleCov.start
end

RSpec.configure do |config|
  config.include Devise::TestHelpers, :type => :controller
  config.use_transactional_fixtures = true
  config.before(:suite) { User.destroy_all }
end


