###
##  Update-Metadata
##  A script for updating a Rally Movie's metadata resource with the
##  keys/values provided in a json file
##
##  Usage: Provide -f <filename> and -m <moviename>, optionally -v for verbose logging
##  ex. ruby update-metadata.rb -f metadata.json -m 1092_2093_My_Movie_Name

require './rally-tools'
require 'json'
require 'optparse'

# set up options parsing
options = {}
OptionParser.new do |opts|
  opts.on("-f filename", "--metadata", "The path to the metadata json file") do |path|
    options[:metadata_path] = path
    p path
  end

  opts.on("-m moviename", "--movie-name", "The Rally movie name") do |movie_name|
    options[:movie_name] = movie_name
    p movie_name
  end

  opts.on("-v", "--verbose", "Log verbosely") do |verbose|
    options[:verbose] = true
  end

end.parse!

# get the rally id for a given movie name
id = RallyTools.get_rally_id_for_movie_name(options[:movie_name])

# load the metadata file
file = File.read(options[:metadata_path])
metadata = JSON.parse(file)

# create a payload for updating the metadata resource
payload = RallyTools.new_resource_payload(type: "metadata", attributes: {metadata: metadata})

# make request
begin
  if options[:verbose]
    puts "Updating #{options[:movie_name]} metadata with payload \n #{JSON[payload]}"
  end
  resp = RallyTools.patch_metadata_for_movie_id(id, payload)
  puts "Sucessfully updated metadata for #{options[:movie_name]} with metadata from json file #{options[:metadata_path]}"
rescue HTTPRequestError => e
  # bad request
  p e.msg
end
