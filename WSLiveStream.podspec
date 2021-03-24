#
# Be sure to run `pod lib lint WSLiveStream.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
# pod lib lint --verbose --allow-warnings
# pod spec lint --verbose --allow-warnings

Pod::Spec.new do |s|
  s.name             = 'WSLiveStream'
  s.version          = '0.0.1'
  s.summary          = 'A short description of WSLiveStream.'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
TODO: Add long description of the pod here.
                       DESC

  s.homepage         = 'https://github.com/wenrisheng/WSLiveStream'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'wrs' => '252797991@qq.com' }
  s.source           = { :git => 'https://github.com/wenrisheng/WSLiveStream.git', :tag => s.version.to_s }
  s.social_media_url = 'https://www.jianshu.com/u/95d8b8a740e0'

  s.ios.deployment_target = '9.0'

  s.source_files = 'WSLiveStream/Classes/**/*'
  
  # s.resource_bundles = {
  #   'WSLiveStream' => ['WSLiveStream/Assets/*.png']
  # }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
  # s.dependency 'AFNetworking', '~> 2.3'
end
