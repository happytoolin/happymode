require 'rubygems'
require 'xcodeproj'

project_path = 'happymode.xcodeproj'
project = Xcodeproj::Project.new(project_path)

target = project.new_target(:application, 'happymode', :osx, '14.0')

target.build_configurations.each do |config|
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.atlantic.happymode'
  config.build_settings['SWIFT_VERSION'] = '5.0'
  config.build_settings['INFOPLIST_FILE'] = 'happymode/Info.plist'
  config.build_settings['GENERATE_INFOPLIST_FILE'] = 'NO'
  config.build_settings['MACOSX_DEPLOYMENT_TARGET'] = '14.0'
  config.build_settings['ASSETCATALOG_COMPILER_APPICON_NAME'] = 'AppIcon'
  config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
end

app_group = project.main_group.new_group('happymode', 'happymode')

source_files = [
  'HappymodeApp.swift',
  'MenuBarView.swift',
  'SettingsView.swift',
  'ThemeController.swift',
  'SolarCalculator.swift'
]

source_files.each do |file|
  file_ref = app_group.new_file(file)
  target.add_file_references([file_ref])
end

assets_ref = app_group.new_file('Assets.xcassets')
target.resources_build_phase.add_file_reference(assets_ref)

app_group.new_file('Info.plist')

project.save
puts "Created #{project_path}"
