module Errors
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

  class FileNotFoundException < StandardError

    @path
    def initiailze(path)
      @path = path
    end

    def to_str()
      return "File not found for path:" + @path
    end

  end

  class RallyGitDeploymentError < StandardError
    @message
    def initialize(message)
      @message = message
    end

    def to_str()
      return @message
    end
  end

  class InvalidLogFileException < StandardError
  end
end
