$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)

require 'qc'
require 'minitest/autorun'
require 'minitest/spec'
require 'minitest/mock'
require 'system_test'
require 'vcr'

Dir[File.join(__dir__, 'support/**/*.rb')].each {|f| require f}

$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)

