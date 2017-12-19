# frozen_string_literal: true

require_relative 'lib/simple_sdk_builder/version'

Gem::Specification.new do |s|
  # definition
  s.name = 'simple_sdk_builder'
  s.version = SimpleSDKBuilder::VERSION

  # details
  s.license = 'Nonstandard'
  s.summary = 'Makes building SDKs for RESTful JSON services easy.'
  s.description = 'A set of libraries that supports building an object-oriented ruby SDK on top ' \
    'of a RESTful JSON web service.'
  s.authors = ['David Dawson']
  s.email = 'daws23@gmail.com'
  s.homepage = 'https://github.com/daws/simple_sdk_builder'

  # files and paths
  s.files = Dir['lib/**/*.rb', 'README.rdoc', 'CHANGELOG.rdoc', 'LICENSE.txt']
  s.require_paths = ['lib']

  # dependencies
  s.add_dependency 'activemodel', '>= 4.2', '< 6'
  s.add_dependency 'activesupport', '>= 4.2', '< 6'
  s.add_dependency 'faraday', '~> 0.13'
  s.add_dependency 'simply_configurable', '~> 0.2'
end
