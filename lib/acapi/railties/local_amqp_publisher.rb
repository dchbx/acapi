module Acapi
  class ConfigurationSettings
    attr_accessor :publish_amqp_events, :app_id
  end
  
end

module Acapi
  # :nodoc:
  # @private
  module Railties
    # :nodoc:
    # @private
    class LocalAmqpPublisher < Rails::Railtie

      initializer "local_amqp_publisher.initialize_local_events" do |app|
        publish_setting = app.config.acapi.publish_amqp_events
        app_id = app.config.acapi.app_id
        disable_publish = ->(p_setting) { p_setting.blank? || !p_setting }
        case publish_setting
        when disable_publish
          disable_local_publisher
        when :log, :logging, :logger
          log_local_publisher
        else
          boot_local_publisher(app_id)
        end
        ::Acapi::Subscribers::AcapiEvents.register
      end

      def disable_publishing
        Rails.logger.info "Setting 'acapi.publish_amqp_events' set to disabled - disabling publishing of events to local AMQP instance'"
        disable_local_publisher
      end

      def boot_local_publisher(app_id)
        ::Acapi::LocalAmqpPublisher.boot!(app_id)
      end

      def log_local_publisher
        Rails.logger.info "Setting 'acapi.publish_amqp_events' set to log - events will be reflected in the log"
        ::Acapi::LocalAmqpPublisher.logging!
      end

      def disable_local_publisher
        ::Acapi::LocalAmqpPublisher.disable!
      end
    end
  end
end
