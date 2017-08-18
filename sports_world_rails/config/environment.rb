# Load the Rails application.
require File.expand_path('../application', __FILE__)

# Initialize the Rails application.
APP_CONFIG=YAML.load(ERB.new(File.read("#{Rails.root}/config/config.yml")).result)[Rails.env]
Rails.application.initialize!
