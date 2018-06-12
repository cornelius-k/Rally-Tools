# The beginning of a set of tools to make working with Rally easier.
require_relative './errors.rb'
require_relative './preset.rb'
require 'http'
require 'json'
require 'pry'
require 'yaml'

class HTTPRequestError < StandardError
  attr_reader :msg
  @msg = nil
  def initialize(resp)
    @msg = "Bad response from HTTP Request, status code #{resp.code}, body: #{resp.body}"
  end
end

class InvalidPresetException < StandardError
  attr_reader :object

  def initialize(object)
    @object = object
  end
end

class RallyMatchNotFoundError < StandardError
end


class RallyTools
  @env_name = "UAT"
  @rally_api_key = ENV["rally_api_key_#{@env_name}"]
  @rally_api = ENV["rally_api_url_#{@env_name}"]

  def self.make_api_request(path, path_override: nil, payload: nil, one_line: false, suppress: false, patch: false, put: false)
    path = path_override || @rally_api + path
    endchar = one_line ? "\t" : "\n"

    # make the request
    print "Making request for path: #{path} #{endchar}" if !suppress
    if payload && @env_name != "PROD" # saftey -- don't modify Production
      if patch
        resp = HTTP.accept(:json).auth("Bearer " + @rally_api_key).patch(path, json: payload)
      elsif put
        resp = HTTP.accept(:json).auth("Bearer " + @rally_api_key).put(path, body: payload)
      else
        resp = HTTP.accept(:json).auth("Bearer " + @rally_api_key).post(path, json: payload)
      end
    else
      resp = HTTP.accept(:json).auth("Bearer " + @rally_api_key).get(path)
    end

    # check for a successful response
    if ![200, 201, 204].include?(resp.code)
      raise HTTPRequestError.new(resp)
    end

    # parse response body into hash
    body = nil
    begin
      body = JSON[resp.body]
    rescue JSON::ParserError
      body = resp.body.to_s
    end
    return body
  end

  def self.get_rally_id_for_movie_name(movie_name)
    movie_search_path = "/movies?filter=nameContains=#{movie_name}"
    body = self.make_api_request(movie_search_path)
    id = nil
    begin
      id = body['data'][0]['id']
    rescue NoMethodError
       raise RallyMatchNotFoundError.new
    end
    return id
  end

  def self.get_rally_id_for_preset_name(preset_name)
    preset_search_path = "/presets?filter=name=#{URI::escape(preset_name)}"
    begin
      body = self.make_api_request(preset_search_path)
    rescue HTTPRequestError => e
        p e.msg
    end
    id = nil
    begin
      id = body['data'][0]['id']
    rescue NoMethodError
       raise RallyMatchNotFoundError.new
     end
    return id
  end

  def self.get_metadata_for_movie_id(movie_id, suppress: false)
    metadata_path = "/movies/#{movie_id}/metadata/Metadata"
    response = self.make_api_request(metadata_path, suppress: suppress)
    begin metadata = response['data']['attributes']['metadata'] rescue NoMethodError end
    return metadata
  end

  def self.patch_metadata_for_movie_id(movie_id, metadata_obj)
    metadata_path = "/movies/#{movie_id}/metadata/Metadata"
    response = self.make_api_request(metadata_path, payload: metadata_obj, patch: true)
  end

  def self.set_recontribution_status_metadata(movie_id, status)
    status_reset_metadata = {
      data: {
        id: "Metadata",
        type: "metadata",
        attributes: {
          usage: "Metadata",
          metadata: {
            "Recontribution Status" => status
          }
        }
      }
    }
    RallyTools.patch_metadata_for_movie_id(movie_id, status_reset_metadata)
  end

  def self.poll_until_metadata_equals(movie_id, key, value)
    movie_metadata = nil
    loop do
      print "Polling for Recontribution status on movie #{movie_id}:\t"
      movie_metadata = RallyTools.get_metadata_for_movie_id(movie_id, suppress: true)
      status = movie_metadata['Recontribution Status'] || "not started"
      print "status: #{status} \t"
      break if movie_metadata['Recontribution Status'] == 'complete'
      RallyTools.wait_and_animate(5)
      print("\n")
    end
    puts "###### Complete"
    puts 'Resetting Recontribution Status Metadata'
    RallyTools.set_recontribution_status_metadata(movie_id, "test complete")
    return movie_metadata
  end

  def self.wait_and_animate(iterations)
    iterations.times do
      sleep(1)
      print('.')
    end
  end

  def self.new_jobs_payload(init_data, filename, rule)
    return {
        "data" =>  {
            "type" => "workflows",
            "attributes" =>  {
                "initData" => init_data.to_json
            },
            "relationships" => {
                "movie" => {
                    "data" => {
                        "type" => "movies",
                        "attributes" => {
                            "name" => filename
                        }
                    }
                },
                "rule" => {
                   "data" => {
                       "type" => "rules",
                       "attributes" => {
                            "name" => rule
                        }
                    }
                }
            }
        }
    }
  end

  def self.parse_presets_response(response)
    parsed_presets = {}
    response['data'].each do |preset|
      name = preset['attributes']['name']
      parsed_presets[name] = {
          id: preset['id'],
          code: RallyTools.get_preset_code(preset['id'])
        }
        puts "Reading from Rally #{@env_name}: \t #{preset['attributes']['name']}"
    end
    return parsed_presets
  end

  def self.get_preset_code(preset_id)
    resp = RallyTools.make_api_request("/presets/#{preset_id}/providerData", suppress: true)
  end

  def self.get_next_page(response)
    begin
      return response['links']['next'] rescue NoMethodError
    end
  end

  def self.download_all_presets(suppress: false)
    presets = {}
    presets_path = '/presets'
    resp = RallyTools.make_api_request(presets_path, suppress: suppress)
    while RallyTools.get_next_page(resp) do
      presets.merge!(RallyTools.parse_presets_response(resp))
      resp = RallyTools.make_api_request(nil, path_override: RallyTools.get_next_page(resp), one_line: true, suppress: suppress)
    end
    return presets
  end

  def self.parse_preset_from_file(file_path)
    file_name = File::basename(file_path)
    name = /(.*).py/.match(file_name)[1]
    parsed_preset = {}
    code = IO.read(file_name)
    #File.open('path', 'wb') do |fo|
    #    code = fo.read(text)
    #end
    parsed_preset[name] = {code: code, name: name}
    return parsed_preset
  end

  def self.load_all_presets_in_folder(path)
    preset_files = {}
    path = "#{path}/**/*.py"
    puts path
    Dir.glob(path) do |file|
      preset_files.merge!(RallyTools.parse_preset_from_file(file)) if File.file?(file)
    end
    return preset_files
  end

  def self.difference_of_preset_lists(one, two)
    difference = one.dup.delete_if do |k, v|
      two.has_key?(k)
    end
  end

  def self.presets_in_both_lists(one, two)
    difference = one.dup.delete_if do |k, v|
      !two.has_key?(k)
    end
  end

  def self.compare_preset_code_for_differences(one, two, keys_to_compare)
    presets_with_code_difference = keys_to_compare.map do |preset_name|
      puts "Does preset named #{preset_name} have the same code?"
      difference = one[preset_name][:code] != two[preset_name][:code]
      {:name => preset_name} if difference
    end
    presets_with_code_difference.compact
  end

  def self.new_resource_payload(type: nil, attributes: {}, relationships: {})
    payload = {
      data: {
        type: type,
        attributes: attributes,
        relationships: relationships
      }
    }
  end

  # open a file on the file system, raises exception for missing file
  def self.open_file(file_path)
    raise Errors::FileNotFoundException.new("File not Found") if !File.exist?(file_path)
    file_contents = File.open(file_path, 'rb') { |f| f.read }
  end

  def self.update_preset_in_rally(id, preset)
    patch_update_path = "/presets/#{id}/providerData"
    begin
      response = self.make_api_request(patch_update_path, payload: preset.code , put: true)
    rescue HTTPRequestError => e
      p e.msg
    end
  end

  def self.create_preset_in_rally(preset)
    payload = {
      data: {
        type: 'presets',
        attributes: {
          name: preset.name
        },
        relationships: {
          providerType: {
            data: {
              id: RallyTools.find_evaluate_provider_type(),
              type: "providerTypes"
            },
          }
        }
      }
    }
    path = '/presets'
    begin
      response = self.make_api_request(path, payload: payload)
      return response
    rescue HTTPRequestError => e
      p e.msg
    end
  end

  def self.find_evaluate_provider_type()
    path = "/providerTypes"
    response = self.make_api_request(path)
    id = nil
    response["data"].each do |providerType|
      if providerType["attributes"]["name"] == "SdviEvaluate"
        id = providerType["id"]
      end
    end
    if id.nil?
      raise RallyMatchNotFoundError.new
    else
      return id
    end
  end

  def self.rapid_preset_dev(preset_path)
    # open the preset
    # parse the name, the rule and the test content
    # call update preset in rally
    # create a /workflows payload
    # execute it against the filename
  end

end
