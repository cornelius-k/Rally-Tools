# A data structure defining the log
class RallyDeploymentLog
  attr_reader :last_deployed_hash, :deployment_log, :date

  @log

  def initialize(existing_log)
    if existing_log
      @log = existing_log
    else
      @log = RallyDeploymentLog::initialize_new_log()
    end
  end

  def add_deployment_to_log(commits, deployment_results)
    new_log_entry = {
      commits_deployed: commits,
      deployment_results: deployment_results,
      date: DateTime.now
    }
    @log.append(new_log_entry)
  end


  # serialize to json for saving to output file
  def tojson()
    return @log.to_json
  end

  def self.initialize_new_log()
    data = {
      commits_deployed: nil,
      deploy_log: nil,
      date: DateTime.now
    }
  end
end
