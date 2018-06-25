require 'optparse'
require 'tempfile'
require_relative '../preset.rb'
require_relative './deployment.rb'
require_relative '../rally-tools.rb'

options = {}

OptionParser.new do |parser|
  parser.on("-f", "--file NAME", "The name of the preset to deploy") do |v|
    options[:file] = v
    p v
  end
end.parse!

preset = Preset.new(options[:file])
body = RallyTools.make_api_request("/presets?filter=name=#{preset.name}")
exit if body['data'].empty?
body = RallyTools.make_api_request(nil, path_override: body['data'][0]['links']['providerData'])

file = Tempfile.new(["rallydiff", ".py"])
file.write(body)
file.close

file_args = "\"#{options[:file]}\" #{file.path}"

`diff #{file_args}`
exit if $?.exitstatus == 0

exec("vim -d #{file_args}")
