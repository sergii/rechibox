require "rails"
require "action_controller/railtie"

Bundler.require(*Rails.groups)

module RechiboxBackend
  class Application < Rails::Application
    config.load_defaults 8.1
    config.api_only = true
    config.autoload_lib(ignore: %w[assets tasks]) if config.respond_to?(:autoload_lib)
  end
end
