require './errors.rb'

class Preset
  attr_accessor :name, :code
  @path

  def initialize(path)
    @path = path
    @code = RallyTools::open_file(path)
    parse_preset()
  end

  # read metadata values written into a preset's comments
  def parse_preset()
    # parse the preset's name value
    name_matches = /name:\s(.*)\s/.match(@code)
    begin
      @name = name_matches[1]
    rescue NoMethodError
      raise InvalidPresetException.new("No metadata key 'name' found in preset: #{@path}")
    end
  end

end
