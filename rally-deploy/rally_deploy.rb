#
require_relative '../rally-tools.rb'
require_relative '../errors.rb'
require 'json'
require 'date'
require 'pry'
require_relative './deployment.rb'
require_relative './deployment_log.rb'

# deployment_log = File.new(@@deployment_log_path, "w")
# File.write(deployment_log, data)

## A group of functions for identifying and deploying changes made to a Rally repository
module RallyDeploy
  @@deployment_log_path = 'rally_deploy_log.json'

  # parse commit information from the output of a git log
  def self.parse_log(git_log)
    logged_commits = git_log.split("COMMIT")
    commits = Array.new
    logged_commits.each do |commit_text|
      unless commit_text.nil?
        # parse the commit hashes
        hash_matches = /HASH:(\S*)/.match(commit_text)
        commit_hash = hash_matches ? hash_matches[1] : nil

        # parse the dates
        date_matches = /DATE:(.*) FILES/.match(commit_text)
        date = date_matches ? DateTime.parse(date_matches[1]) : nil

        # parse the files included
        files = commit_text.scan(/supply\ chain.*/)

        # add to commits
        commits.push({ hash: commit_hash, date: date, files: files}) unless commit_hash.nil? || date.nil?
      end
    end
    # sort by date
    commits.sort_by! {|e| e[:date]}
    return commits
  end

  def self.get_deployment_log()
    begin
      deployment_log_contents = RallyTools::open_file(@@deployment_log_path)
      log_contents_as_hash = JSON[deployment_log_contents]
      return RallyDeploymentLog.new(log_contents_as_hash)
    rescue Errors::FileNotFoundException
      return RallyDeploymentLog.new(nil)
    end

    return deployment_log
  end

  def self.update_deploy_log(deployment_log)
    p deployment_log.tojson
    #File.open(@@deployment_log_path, 'w') { |file| file.write(deployment_log.to_json) }

  end

  def self.determine_commits_to_deploy(deployment_log, commits)
    last_deployed_hash = deployment_log.get_last_deployment["last_deployed_hash"]
    last_deployed_index = commits.find_index { |commit|  commit[:hash] == last_deployed_hash }
    commits_to_deploy = commits[last_deployed_index..-1]
  end

  def self.load_presets_for_commits(commits, rally_repo_path)
    presets = []
    p commits.size
    p commits.inspect
    commits.each do |commit|
      unless commit[:files].nil?
        commit[:files].each do |file_path|
          # only load python presets
          if file_path[-3, 3] == '.py'
            begin
              preset_path =  File.join(rally_repo_path, file_path)
              preset = Preset.new(preset_path)
              presets << preset
            rescue Errors::FileNotFoundException
              p "File Not Found Exception Occured"
              # do nothing
            end
          end
        end
      end
    end
    return presets
  end

end
