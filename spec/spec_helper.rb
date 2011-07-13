Bundler.require(:default, :development)
$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
require 'rubygems'
require 'my_obfuscate'

RSpec.configure do |config|
#  config.mock_with :rr
end
