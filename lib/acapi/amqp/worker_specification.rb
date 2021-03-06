require "sneakers/worker"
require "sneakers/handlers/maxretry"

module Acapi
  module Amqp
    class WorkerSpecification
      attr_reader :kind
      attr_accessor :routing_key
      attr_writer :retry_count
      attr_writer :retry_delay
      attr_accessor :queue_name

      def initialize(args = {})
        args.each_pair do |k, v|
          self.send("#{k}=", v)
        end
      end

      def kind=(val)
        unless [:topic, :direct, "topic", "direct"].include?(val)
          raise ArgumentError, "kind must be either 'topic' or 'direct'"
        end
        @kind = val
      end

      def retry_count
        @retry_count || 5
      end

      def retry_delay
        @retry_delay || 5000
      end

      def exchange_kind
        case kind
        when "topic", :topic
          :topic
        when "direct", :direct
          :direct
        else
          raise ArgumentError, "kind must be either 'topic' or 'direct'"
        end
      end

      def exchange_name
        hbx_id = Rails.application.config.acapi.hbx_id
        env_name = Rails.application.config.acapi.environment_name
        "#{hbx_id}.#{env_name}.e.#{exchange_kind}.events"
      end

      def full_queue_name
        hbx_id = Rails.application.config.acapi.hbx_id
        app_id = Rails.application.config.acapi.app_id 
        env_name = Rails.application.config.acapi.environment_name
        "#{hbx_id}.#{env_name}.q.#{app_id}.#{queue_name}"
      end

      def retry_exchange_name
        "#{full_queue_name}-retry"
      end

      def execute_sneakers_config_against(kls)
        kls.class_eval(<<-RUBYCODE)
          include ::Sneakers::Worker
          from_queue("#{full_queue_name}", {
               :ack => true,
               :prefetch => 1,
               :threads => 1,
               :durable => true,
               :exchange => "#{exchange_name}",
               :exchange_options => { :type => "#{exchange_kind}", :durable => true },
               :routing_key => "#{routing_key}",
               :handler => Sneakers::Handlers::Maxretry,
               :retry_timeout => #{retry_delay},
               :heartbeat => 5,
               :retry_max_times => #{retry_count},
               :arguments => {
                 :'x-dead-letter-exchange' => "#{retry_exchange_name}"
               }
          })
        RUBYCODE
      end
    end
  end
end
