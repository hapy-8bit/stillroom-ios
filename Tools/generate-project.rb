#!/usr/bin/env ruby
require 'xcodeproj'
require 'fileutils'

root = File.expand_path('..', __dir__)
project = Xcodeproj::Project.new(File.join(root, 'Stillroom.xcodeproj'))
app = project.new_target(:application, 'Stillroom', :ios, '18.0')
app.product_reference.name = 'Stillroom.app'
config_group = project.main_group.new_group('Config', 'Config')
config = config_group.new_file('App.xcconfig')
project.build_configurations.each do |build|
  build.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '18.0'
  build.build_settings['SWIFT_VERSION'] = '5.0'
end
app.build_configurations.each do |build|
  build.base_configuration_reference = config
  build.build_settings['PRODUCT_NAME'] = 'Stillroom'
  build.build_settings['SUPPORTED_PLATFORMS'] = 'iphoneos iphonesimulator'
  build.build_settings['SUPPORTS_MACCATALYST'] = 'NO'
  build.build_settings['TARGETED_DEVICE_FAMILY'] = '1'
  build.build_settings['LD_RUNPATH_SEARCH_PATHS'] = '$(inherited) @executable_path/Frameworks'
end

def populate(group, absolute, app)
  Dir.children(absolute).sort.each do |name|
    next if name.start_with?('.') || name == 'Info.plist'
    path = File.join(absolute, name)
    if File.directory?(path) && !name.end_with?('.xcassets')
      populate(group.new_group(name, name), path, app)
    else
      reference = group.new_file(name)
      name.end_with?('.swift') ? app.source_build_phase.add_file_reference(reference) : app.resources_build_phase.add_file_reference(reference)
    end
  end
end
populate(project.main_group.new_group('Stillroom', 'Stillroom'), File.join(root, 'Stillroom'), app)

unit = project.new_target(:unit_test_bundle, 'StillroomTests', :ios, '18.0')
ui = project.new_target(:ui_test_bundle, 'StillroomUITests', :ios, '18.0')
[unit, ui].each do |target|
  target.add_dependency(app)
  group = project.main_group.new_group(target.name, target.name)
  Dir.glob(File.join(root, target.name, '*.swift')).sort.each do |file|
    target.source_build_phase.add_file_reference(group.new_file(File.basename(file)))
  end
  target.build_configurations.each do |build|
    build.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = "com.liuhang.stillroom.#{target.name.downcase}"
    build.build_settings['GENERATE_INFOPLIST_FILE'] = 'YES'
    build.build_settings['SWIFT_VERSION'] = '5.0'
    build.build_settings['TARGETED_DEVICE_FAMILY'] = '1'
    build.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
  end
end
unit.build_configurations.each do |build|
  build.build_settings['TEST_HOST'] = '$(BUILT_PRODUCTS_DIR)/Stillroom.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/Stillroom'
  build.build_settings['BUNDLE_LOADER'] = '$(TEST_HOST)'
end
ui.build_configurations.each { |build| build.build_settings['TEST_TARGET_NAME'] = 'Stillroom' }
project.save
scheme = Xcodeproj::XCScheme.new
scheme.add_build_target(app)
scheme.set_launch_target(app)
scheme.add_test_target(unit)
scheme.add_test_target(ui)
scheme.save_as(project.path, 'Stillroom', true)
puts "Generated #{project.path}"

