platform :ios, '12.0'

target 'Beiwe' do
    use_frameworks!

    # firebase (push notifications)      
    #pod 'FirebaseCrashlytics'  # old: pod 'Crashlytics', '~> 3.4'
    pod 'FirebaseAnalytics'
    pod 'FirebaseMessaging'  # old: pod 'Firebase/Messaging', '~>6'
    
    # sentry error reporting (was 4.5, that simply stopped compiling in xcode 16 (ios 18 release)
    # Reyva - pod 'Sentry', :git => 'https://github.com/getsentry/sentry-cocoa.git', :tag => '8.36.0'
    pod 'Sentry', '~> 8.37.0'
    # pod 'Sentry', :git => 'https://github.com/getsentry/sentry-cocoa.git', :tag => '8.36.0'
    
    # one-off libraries
    pod 'KeychainSwift', '~> 8.0'
    pod 'EmitterKit', '~> 5.2.2'  # old: '~> 5.1'
    # pod 'XCGLogger', '~> 7.0.0'
    
    # I think this is ui?
    pod 'XLActionController', '~>5.0.1'

    # logging
    pod 'XCGLogger', '~> 7.0.0'

    # ui
    pod 'Eureka'
    # validates the inputs at registration
    pod 'SwiftValidator', :git => 'https://github.com/SwiftValidatorCommunity/SwiftValidator.git', :branch => 'master'
    # pops up a heads-up-display on certain pages.
    pod 'PKHUD', :git => 'https://github.com/pkluz/PKHUD.git', :tag => '5.4.0'  # old: :branch => 'release/swift4'
    # the surveys
    pod 'ResearchKit', :git => 'https://github.com/ResearchKit/ResearchKit.git', :tag => '2.1.0'  #:commit => 'b50e1d7'
    # no clue
    pod 'Hakuba', :git => 'https://github.com/eskizyen/Hakuba.git', :branch => 'Swift3'

    # Database
    # the old database library, probably not compatible with new code: pod 'couchbase-lite-ios'
    pod 'CouchbaseLite-Swift'

    # Reachability - what is reachability? well people get their app rejected for it, and it wasn't functional for Years!
    pod 'ReachabilitySwift', '5.2.3' # old: '~>3'

    # a crashy library that links state to the database.
    # master branch stopped working, gets error about minimum app version number that cannot be resolved?
    #pod 'ObjectMapper', :git => 'https://github.com/Hearst-DD/ObjectMapper.git', :branch => 'master'
    pod 'ObjectMapper', :git => 'https://github.com/Hearst-DD/ObjectMapper.git', :commit => '0b96a734de3ea1c87374ae677064f86adb0716ec'
    
    # Http requests
    pod 'Alamofire', '~> 4.5'

    # Encryption
    pod 'IDZSwiftCommonCrypto', '~> 0.16.1'  # old: '~> 0.13.0'

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
