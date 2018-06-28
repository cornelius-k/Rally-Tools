# A data structure for storing a history of deployment information
require 'date'
require 'json'

# represent an individual deployment
LogEntry = Struct.new(:commits_deployed, :deployment_results, :date)

class RallyDeploymentLog
  attr_reader :last_deployed_hash
  @last_deployed_hash
  @date_updated
  @log

  # @param [Array] existing_log Pre existing log data
  def initialize(existing_log = nil, last_deployed_hash = nil)
    if existing_log
      @log = existing_log["deployment_log"]
      @last_deployed_hash = existing_log["last_deployed_hash"]
    else # initialize a new log
      p 'initializing new log with hash' + last_deployed_hash.to_s
      @last_deployed_hash = last_deployed_hash
      @log = []
    end
    @date_updated = DateTime.now
  end

  # append deployment information to the log
  def add_deployment_to_log(commits, deployment_results)
    new_log_entry = LogEntry.new(commits, deployment_results, DateTime.now)
    @log.append(new_log_entry)
  end

  # return the last deployment
  def get_last_deployment()
    @log.last
  end

  # serialize to json for saving to output file
  # @return [String] json representation of log
  def tojson()
    p @log.class
    return {
      last_deployed_hash: @last_deployed_hash,
      deployment_log: @log.map {|e| e.to_h},
      date_updated: @date_updated
    }.to_json
  end

end
