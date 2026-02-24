require 'rubygems'
require 'xcodeproj'

project_path = 'happymode.xcodeproj'
project = Xcodeproj::Project.new(project_path)

target = project.new_target(:application, 'happymode', :osx, '14.0')

target.build_configurations.each do |config|
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.atlantic.happymode'
  config.build_settings['SWIFT_VERSION'] = '5.10'
  config.build_settings['INFOPLIST_FILE'] = 'happymode/Config/Info.plist'
  config.build_settings['GENERATE_INFOPLIST_FILE'] = 'NO'
  config.build_settings['MACOSX_DEPLOYMENT_TARGET'] = '14.0'
  config.build_settings['ASSETCATALOG_COMPILER_APPICON_NAME'] = 'AppIcon'
  config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
end

app_group = project.main_group.new_group('happymode', 'happymode')
app_subgroup = app_group.new_group('App', 'App')
features_subgroup = app_group.new_group('Features', 'Features')
menu_bar_subgroup = features_subgroup.new_group('MenuBar', 'MenuBar')
settings_subgroup = features_subgroup.new_group('Settings', 'Settings')
core_subgroup = app_group.new_group('Core', 'Core')
theme_subgroup = core_subgroup.new_group('Theme', 'Theme')
solar_subgroup = core_subgroup.new_group('Solar', 'Solar')
resources_subgroup = app_group.new_group('Resources', 'Resources')
config_subgroup = app_group.new_group('Config', 'Config')

source_files = [
  ['HappymodeApp.swift', app_subgroup],
  ['MenuBarView.swift', menu_bar_subgroup],
  ['SettingsView.swift', settings_subgroup],
  ['ThemeController.swift', theme_subgroup],
  ['SolarCalculator.swift', solar_subgroup],
  ['SolarPackage.swift', solar_subgroup]
]

source_files.each do |file, group|
  file_ref = group.new_file(file)
  target.add_file_references([file_ref])
end

assets_ref = resources_subgroup.new_file('Assets.xcassets')
target.resources_build_phase.add_file_reference(assets_ref)

config_subgroup.new_file('Info.plist')

project.save
puts "Created #{project_path}"
