#
# Be sure to run `pod lib lint WSLiveStream.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
# pod lib lint --use-libraries --allow-warnings --verbose
# pod spec lint --verbose --allow-warnings

Pod::Spec.new do |s|
  s.name             = 'WSLiveStream'
  s.version          = '0.0.1'
  s.summary          = 'iOS rtmp WSLiveStream.'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
TODO: Add long description of the pod here.
                       DESC

  s.homepage         = 'https://gitee.com/wrswenrisheng/wslive-stream'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'wrs' => '252797991@qq.com' }
  s.source           = { :git => 'https://gitee.com/wrswenrisheng/wslive-stream.git', :tag => s.version.to_s }
  s.social_media_url = 'https://www.jianshu.com/u/95d8b8a740e0'

  s.ios.deployment_target = '9.0'

  s.public_header_files = 'WSLiveStream/Sources/**/*.h'   #公开头文件地址
  s.source_files = 'WSLiveStream/Sources/**/*.{h,m,mm,cpp,c}'
  s.frameworks = "VideoToolbox", "AudioToolbox","AVFoundation","Foundation","UIKit"
  s.libraries = "c++"
  
#  s.ios.frameworks   = ['VideoToolbox', 'AudioToolbox', 'AVFoundation', 'Foundation', 'UIKit', 'OpenGLES', 'CoreMedia', 'QuartzCore', 'AVFoundation']

#  s.subspec 'pili-librtmp' do |ss|
#    ss.requires_arc = true
#    ss.source_files = "WSLiveStream/Sources/Vendors/pili-librtmp/*.{h,c}"
#    ss.exclude_files = "WSLiveStream/Sources/Vendors/pili-librtmp/dh.h", "WSLiveStream/Sources/Vendors/pili-librtmp/handshake.h"
#  end
#  s.subspec 'GPUImage' do |ss|
#    ss.source_files = 'WSLiveStream/Sources/Vendors/GPUImage/**/*.{h,m}'
#    ss.requires_arc = true
#    ss.xcconfig = { 'CLANG_MODULES_AUTOLINK' => 'YES' }
#    ss.ios.exclude_files = 'WSLiveStream/Sources/Vendors/GPUImage/Mac'
#    ss.ios.frameworks   = ['OpenGLES', 'CoreMedia', 'QuartzCore', 'AVFoundation']
##    ss.osx.exclude_files =  'WSLiveStream/Sources/Vendors/GPUImage/iOS',
##                            'WSLiveStream/Sources/Vendors/GPUImage/GPUImageFilterPipeline.*',
##                            'WSLiveStream/Sources/Vendors/GPUImage/GPUImageMovieComposition.*',
##                            'WSLiveStream/Sources/Vendors/GPUImage/GPUImageVideoCamera.*',
##                            'WSLiveStream/Sources/Vendors/GPUImage/GPUImageStillCamera.*',
##                            'WSLiveStream/Sources/Vendors/GPUImage/GPUImageUIElement.*'
##    ss.osx.xcconfig = { 'GCC_WARN_ABOUT_RETURN_TYPE' => 'YES' }
#  end
  
  # s.resource_bundles = {
  #   'WSLiveStream' => ['WSLiveStream/Assets/*.png']
  # }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
  # s.dependency 'AFNetworking', '~> 2.3'
end
