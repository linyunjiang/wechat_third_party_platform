module WechatThirdPartyPlatform
  class InstallGenerator < Rails::Generators::Base
    source_root File.expand_path('templates', __dir__)

    def install
      route 'mount WechatThirdPartyPlatform::Engine => "/wtpp"'
    end

    def copy_initializer
      template 'install_wechat_third_party_platform.rb', 'config/initializers/wechat_third_party_platform.rb'
    end

    def configure_application
      application <<-CONFIG
      config.to_prepare do
        # Load application's model / class decorators
        Dir.glob(File.join(File.dirname(__FILE__), "../app/**/*_decorator*.rb")) do |c|
          Rails.configuration.cache_classes ? require(c) : load(c)
        end
      end
      CONFIG
    end

    def copy_decorators
      template 'wechat_controller.rb', 'app/decorators/controllers/wechat_third_party_platform/wechat_controller_decorator.rb'
    end
  end
end
