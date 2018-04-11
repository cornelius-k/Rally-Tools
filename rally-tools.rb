# The beginning of a set of tools to make working with Rally easier.
require 'http'
require 'json'
require 'pry'
require 'yaml'

class RallyTools

  @rally_api_key = ENV['rally_api_key_UAT']
  @rally_api = ENV['rally_api_url_UAT']

  def self.make_api_request(path, path_override: nil, payload: nil, one_line: false, suppress: false, patch: false)
    path = path_override || @rally_api + path
    endchar = one_line ? "\t" : "\n"
    print "Making request for path: #{path} #{endchar}" if !suppress
    if payload
      if patch
        resp = HTTP.headers(:accept => "application/json").auth("Bearer " + @rally_api_key).patch(path, json: payload)
      end
      resp = HTTP.accept(:json).auth("Bearer " + @rally_api_key).post(path, json: payload)
    else
      resp = HTTP.accept(:json).auth("Bearer " + @rally_api_key).get(path)
    end
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
    begin id = body['data'][0]['id'] rescue NoMethodError end
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
        puts preset['attributes']['name']
    end
    return parsed_presets
  end

  def self.get_preset_code(preset_id)
    resp = RallyTools.make_api_request("/presets/#{preset_id}/providerData")
  end

  def self.get_next_page(response)
    begin
      return response['links']['next'] rescue NoMethodError
    end
  end

  def self.download_all_presets()
    presets = {}
    presets_path = '/presets'
    resp = RallyTools.make_api_request(presets_path)
    while RallyTools.get_next_page(resp) do
      presets.merge!(RallyTools.parse_presets_response(resp))
      resp = RallyTools.make_api_request(nil, path_override: RallyTools.get_next_page(resp), one_line: true)
    end
    return presets
  end

  def self.parse_preset_from_file(file_path)
    file_name = File::basename(file_path)
    name = /(.*).py/.match(file_name)[1]
    parsed_presets = {}
    parsed_presets[name.to_sym] = {code: File.read(file_path), name: name}
  end

  def self.load_all_presets_in_folder(path)
    preset_files = {}
    Dir.glob("#{path}/**/*.py") do |file|
      preset_files.merge!(RallyTools.parse_preset_from_file(file)) if File.file?(file)
    end
    return preset_files
  end

  def self.compare_preset_lists(one, two)
    difference = one.to_a - two.to_a
  end

end
