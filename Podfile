platform :ios, '12.0'

target 'Beiwe' do
    use_frameworks!
    pod 'FirebaseCrashlytics'
    pod 'FirebaseAnalytics'
    pod 'FirebaseMessaging'
    
    pod 'KeychainSwift', '~> 8.0'
    pod 'Alamofire', '~> 4.5'
    pod 'ObjectMapper', :git => 'https://github.com/Hearst-DD/ObjectMapper.git', :branch => 'master'
    pod 'Eureka'
    pod 'SwiftValidator', :git => 'https://github.com/SwiftValidatorCommunity/SwiftValidator.git', :branch => 'master'
    pod 'PKHUD', :git => 'https://github.com/pkluz/PKHUD.git', :tag => '5.4.0'
    pod 'IDZSwiftCommonCrypto', '~> 0.16.1'
    pod 'CouchbaseLite-Swift'
    pod 'ResearchKit', :git => 'https://github.com/ResearchKit/ResearchKit.git', :commit => 'b50e1d7'
    pod 'ReachabilitySwift', '5.2.3'
    pod 'EmitterKit', '~> 5.2.2'
    pod 'Hakuba', :git => 'https://github.com/eskizyen/Hakuba.git', :branch => 'Swift3'
    pod 'XLActionController', '~>5.0.1'
    pod 'XCGLogger', '~> 7.0.0'
    pod 'Sentry', :git => 'https://github.com/getsentry/sentry-cocoa.git', :tag => '8.36.0'
    
end

post_install do |installer|
    installer.pods_project.targets.each do |target|
        next unless (target.name == 'ResearchKit')
        target.build_configurations.each do |config|
            config.build_settings['SWIFT_OPTIMIZATION_LEVEL'] = '-Onone'
        end
    end
    
    installer.pods_project.targets.each do |target|
        if target.name == 'Eureka' || target.name == 'XLActionController' || target.name == 'ResearchKit' || target.name == 'ReachabilitySwift' || target.name == 'IDZSwiftCommonCrypto'
            target.build_configurations.each do |config|
                config.build_settings['SWIFT_VERSION'] = '5.10'
                config.build_settings['ENABLE_BITCODE'] = 'NO'
            end
        elsif target.name == 'Hakuba' || target.name == 'EmitterKit' || target.name == 'SwiftValidator'
            target.build_configurations.each do |config|
                config.build_settings['SWIFT_VERSION'] = '4.1'
                config.build_settings['ENABLE_BITCODE'] = 'NO'
            end
        else
            target.build_configurations.each do |config|
                config.build_settings['SWIFT_VERSION'] = '5.0'
                config.build_settings['ENABLE_BITCODE'] = 'NO'
                if target.name != "Sentry"
                    config.build_settings['APPLICATION_EXTENSION_API_ONLY'] = 'NO'
                end
            end
        end
    end
    
    installer.pods_project.targets.each do |target|
        target.build_configurations.each do |config|
            config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '12.0'
        end
    end
end
