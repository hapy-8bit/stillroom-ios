#!/usr/bin/env ruby
require 'xcodeproj'
require 'fileutils'

root = File.expand_path('..', __dir__)
project = Xcodeproj::Project.new(File.join(root, 'Stillroom.xcodeproj'))
app = project.new_target(:application, 'Stillroom', :ios, '18.0')
app.product_reference.name = 'Stillroom.app'
config_group = project.main_group.new_group('Config', 'Config')
config = config_group.new_file('App.xcconfig')
widget_config = config_group.new_file('Widget.xcconfig')
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

shared_refs = {}

def populate(group, absolute, app, root, shared_refs)
  Dir.children(absolute).sort.each do |name|
    next if name.start_with?('.') || name == 'Info.plist' || name.end_with?('.entitlements')
    path = File.join(absolute, name)
    if File.directory?(path) && !name.end_with?('.xcassets')
      populate(group.new_group(name, name), path, app, root, shared_refs)
    else
      reference = group.new_file(name)
      rel = path.sub("#{root}/", '')
      shared_refs[rel] = reference
      name.end_with?('.swift', '.metal') ? app.source_build_phase.add_file_reference(reference) : app.resources_build_phase.add_file_reference(reference)
    end
  end
end
populate(project.main_group.new_group('Stillroom', 'Stillroom'), File.join(root, 'Stillroom'), app, root, shared_refs)

widget = project.new_target(:app_extension, 'StillroomWidget', :ios, '18.0')
widget.product_reference.name = 'StillroomWidget.appex'
widget.build_configurations.each do |build|
  build.base_configuration_reference = widget_config
  build.build_settings['PRODUCT_NAME'] = 'StillroomWidget'
  build.build_settings['SUPPORTED_PLATFORMS'] = 'iphoneos iphonesimulator'
  build.build_settings['SUPPORTS_MACCATALYST'] = 'NO'
  build.build_settings['TARGETED_DEVICE_FAMILY'] = '1'
  build.build_settings['SWIFT_ACTIVE_COMPILATION_CONDITIONS'] = '$(inherited) ONE_TAPE_WIDGET_EXTENSION'
  build.build_settings['LD_RUNPATH_SEARCH_PATHS'] = '$(inherited) @executable_path/Frameworks @executable_path/../../Frameworks'
end

widget_group = project.main_group.new_group('StillroomWidget', 'StillroomWidget')
Dir.glob(File.join(root, 'StillroomWidget', '*.swift')).sort.each do |file|
  widget.source_build_phase.add_file_reference(widget_group.new_file(File.basename(file)))
end

widget_shared_sources = [
  'Stillroom/Domain/OneTapeWidgetSnapshot.swift',
  'Stillroom/Services/OneTapeWidgetSharedStore.swift',
  'Stillroom/Services/OneTapeWidgetIntents.swift',
  'Stillroom/Features/OneTape/Widget/OneTapeWidgetCassetteView.swift',
  'Stillroom/Features/OneTape/Widget/OneTapeWidgetView.swift'
]
widget_shared_sources.each do |rel|
  ref = shared_refs[rel]
  raise "Missing shared widget source: #{rel}" unless ref
  widget.source_build_phase.add_file_reference(ref)
end

widget_shared_fonts = [
  'Stillroom/Resources/Fonts/GeistMono-Regular.ttf',
  'Stillroom/Resources/Fonts/GeistPixel-Square.ttf',
  'Stillroom/Resources/Fonts/DMSans-Regular.ttf',
  'Stillroom/Resources/Fonts/DMSans-Medium.ttf'
]
widget_shared_fonts.each do |rel|
  ref = shared_refs[rel]
  raise "Missing shared widget font: #{rel}" unless ref
  widget.resources_build_phase.add_file_reference(ref)
end

app.add_dependency(widget)
embed_extensions = app.new_copy_files_build_phase('Embed Foundation Extensions')
embed_extensions.dst_subfolder_spec = '13'
embed_extensions.dst_path = ''
embedded_widget = embed_extensions.add_file_reference(widget.product_reference)
embedded_widget.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }

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
