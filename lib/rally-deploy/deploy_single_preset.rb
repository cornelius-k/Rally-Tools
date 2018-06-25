require 'optparse'
require_relative '../preset.rb'
require_relative './deployment.rb'
require_relative './rally_deploy.rb'
# This will hold the options we parse
options = {}

OptionParser.new do |parser|
  parser.on("-f", "--file NAME", "The name of the preset to deploy") do |v|
    options[:file] = v
    p v
  end
end.parse!

preset = Preset.new(options[:file])
deployment = Deployment.new([preset])
deployment.deploy()
p deployment.get_results()
