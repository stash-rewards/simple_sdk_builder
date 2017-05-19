require 'simplecov'

SimpleCov.start do
  track_files 'lib/**/*.rb'

  add_filter 'bundle/'
  add_filter 'spec/'
  add_filter 'lib/simple_sdk_builder/version'

  minimum_coverage 35
end
