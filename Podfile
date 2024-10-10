platform :ios, '12.0'

target 'Beiwe' do
  use_frameworks!
  # pod 'Crashlytics', '~> 3.4'
  pod 'KeychainSwift', '~> 8.0'
  pod 'Alamofire', '~> 4.5'
  pod 'ObjectMapper', :git => 'https://github.com/Hearst-DD/ObjectMapper.git', :commit => '0b96a734de3ea1c87374ae677064f86adb0716ec'
  pod 'Eureka'
  pod 'Sentry', '~> 8.37.0'

  pod 'SwiftValidator', :git => 'https://github.com/jpotts18/SwiftValidator.git', :branch => 'master'
  pod 'PKHUD', :git => 'https://github.com/pkluz/PKHUD.git', :branch => 'release/swift4'
  pod 'IDZSwiftCommonCrypto', '~> 0.13.0'
  pod 'couchbase-lite-ios'
  pod 'ResearchKit', :git => 'https://github.com/ResearchKit/ResearchKit.git', :commit => 'b50e1d7'
  # pod 'ReachabilitySwift', '~>3'
  pod 'EmitterKit', '~> 5.1'
  pod 'Hakuba', :git => 'https://github.com/eskizyen/Hakuba.git', :branch => 'Swift3'
  pod 'XLActionController', '~>5.0.1'
  # pod 'XCGLogger', '~> 7.0.0'
  pod 'Firebase/Analytics'
  pod 'Firebase/Messaging', '~>6'

end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    next unless (target.name == 'ResearchKit')
    target.build_configurations.each do |config|
      config.build_settings['SWIFT_OPTIMIZATION_LEVEL'] = '-Onone'
    end
  end
  installer.pods_project.targets.each do |target|
    if target.name == 'Eureka' || target.name == 'XLActionController' || target.name == 'ResearchKit'
      target.build_configurations.each do |config|
        config.build_settings['SWIFT_VERSION'] = '4.2'
        config.build_settings['ENABLE_BITCODE'] = 'NO'
      end
    else
      target.build_configurations.each do |config|
        config.build_settings['SWIFT_VERSION'] = '4.0'
        config.build_settings['ENABLE_BITCODE'] = 'NO'
      end
    end
  end
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '12.0'
    end
  end
end
