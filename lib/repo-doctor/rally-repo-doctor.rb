require './rally-tools.rb'
require 'YAML'

local_presets = RallyTools.load_all_presets_in_folder('/Users/nkempin/workspace/ONRAMP_WORKFLOW_PYTHON/supply chain')
uat_presets = RallyTools.download_all_presets(suppress: true)
#
presets_not_in_uat = RallyTools.difference_of_preset_lists(local_presets, uat_presets)
presets_not_in_repo = RallyTools.difference_of_preset_lists(uat_presets, local_presets)
presets_present_in_both = RallyTools.presets_in_both_lists(uat_presets, local_presets)
presets_that_differ_in_code = RallyTools.compare_preset_code_for_differences(uat_presets, local_presets, presets_present_in_both.keys)
difference_in_num_presets = presets_not_in_uat.size


puts "\n\n"
puts "\n\n"
puts "#################### Rally Repo Doctor Report ########################"
puts "\n"
puts "Difference in num preset files (repo vs rally): \t #{presets_not_in_repo}"
puts "\n\n"

puts "The following presets were detected in the repository but not in Rally:"
puts "-------------------------"
puts presets_not_in_uat.map {|k,v| k}
puts "\n\n"

puts "The following presets were detected in Rally but not in the repository:"
puts "-------------------------"
puts presets_not_in_repo.map {|k,v| k}
puts "\n\n"

puts "Here is a list of presets that are in both Rally and the repository, but their code differs:"
puts "-------------------------"
puts presets_that_differ_in_code.map {|e| e[:name]}

# puts "The following presets are in the repo, but not present in UAT Rally: "
# presets_not_in_uat.map do |e| puts e[:name] end
#
# puts "\nThe following presets are in UAT Rally but missing from the repo:"
# presets_not_in_repo.map do |e| puts e[:name] end
