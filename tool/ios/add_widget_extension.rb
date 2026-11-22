# Adds the home-screen widgets' extension (ios/TahfeezWidgets) to the Xcode
# project (owner, 2026-11-22), as a target of its own embedded in the app,
# and gives the app its App Group entitlement. Run on a Mac before building
# (the iOS workflows do, through .github/actions/ios-setup); it changes
# nothing when the target is already there.
#
#   ruby tool/ios/add_widget_extension.rb
#
# Uses the xcodeproj gem (CocoaPods brings it).
require 'xcodeproj'

ROOT = File.expand_path('../..', __dir__)
PROJECT = File.join(ROOT, 'ios/Runner.xcodeproj')
NAME = 'TahfeezWidgets'
BUNDLE_ID = 'ai.tahfeez.tahfeezAi.TahfeezWidgets'
TEAM = 'SABR3VK8ZA'

project = Xcodeproj::Project.open(PROJECT)
app = project.targets.find { |t| t.name == 'Runner' } or abort 'no Runner target'

if project.targets.any? { |t| t.name == NAME }
  puts "#{NAME}: already in the project"
  exit 0
end

# The app's App Group (what it writes for the widgets).
app.build_configurations.each do |c|
  c.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'Runner/Runner.entitlements'
end

# The extension target.
ext = project.new_target(:app_extension, NAME, :ios, '15.1', nil, :swift)
group = project.main_group.find_subpath(NAME, true)
group.set_source_tree('<group>')
group.set_path(NAME)

ext.add_file_references([group.new_reference('TahfeezWidgets.swift')])
group.new_reference('Info.plist')
group.new_reference('TahfeezWidgets.entitlements')
fonts = group.find_subpath('Fonts', true)
fonts.set_source_tree('<group>')
fonts.set_path('Fonts')
resources = [
  fonts.new_reference('MaterialIcons-Widgets.otf'),
  fonts.new_reference('AmiriQuran.ttf'),
]
# Each language's widget names (tool/l10n/build_widget_strings.py).
strings = group.new_variant_group('Localizable.strings')
Dir.children(File.join(ROOT, 'ios', NAME)).select { |d| d.end_with?('.lproj') }.sort.each do |lproj|
  ref = strings.new_reference("#{lproj}/Localizable.strings")
  ref.name = lproj.delete_suffix('.lproj')
end
resources << strings
ext.add_resources(resources)
%w[WidgetKit SwiftUI].each { |f| ext.add_system_framework(f) }

# Its settings: the app's version (Widgets.xcconfig: Flutter's generated
# settings only — not the app's pods).
xcconfig = group.new_reference('Widgets.xcconfig')
ext.build_configurations.each do |c|
  c.base_configuration_reference = xcconfig
  s = c.build_settings
  s['PRODUCT_BUNDLE_IDENTIFIER'] = BUNDLE_ID
  s['PRODUCT_NAME'] = '$(TARGET_NAME)'
  s['INFOPLIST_FILE'] = "#{NAME}/Info.plist"
  s['CODE_SIGN_ENTITLEMENTS'] = "#{NAME}/#{NAME}.entitlements"
  s['DEVELOPMENT_TEAM'] = TEAM
  s['IPHONEOS_DEPLOYMENT_TARGET'] = '15.1'
  s['SWIFT_VERSION'] = '5.0'
  s['TARGETED_DEVICE_FAMILY'] = '1,2'
  s['SKIP_INSTALL'] = 'YES'
  s['GENERATE_INFOPLIST_FILE'] = 'NO'
  s['MARKETING_VERSION'] = '$(FLUTTER_BUILD_NAME)'
  s['CURRENT_PROJECT_VERSION'] = '$(FLUTTER_BUILD_NUMBER)'
  s['LD_RUNPATH_SEARCH_PATHS'] = ['$(inherited)', '@executable_path/Frameworks', '@executable_path/../../Frameworks']
  s['ASSETCATALOG_COMPILER_WIDGET_BACKGROUND_COLOR_NAME'] = ''
end

# Embedded in the app — before Flutter's script phases (after them, Xcode
# finds a dependency cycle).
app.add_dependency(ext)
embed = project.new(Xcodeproj::Project::Object::PBXCopyFilesBuildPhase)
embed.name = 'Embed Foundation Extensions'
embed.symbol_dst_subfolder_spec = :plug_ins
embed.add_file_reference(ext.product_reference).settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
first_script = app.build_phases.index { |p| p.is_a?(Xcodeproj::Project::Object::PBXShellScriptBuildPhase) && p.name.to_s.include?('Thin Binary') }
if first_script
  app.build_phases.insert(first_script, embed)
else
  app.build_phases << embed
end

project.save
puts "#{NAME}: added"
