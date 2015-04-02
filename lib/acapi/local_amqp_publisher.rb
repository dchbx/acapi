require 'bunny'

module Acapi
  class LocalAmqpPublisher
    QUEUE_NAME = "acapi.events.local"
    TOPIC_NAME = "acapi.topic.local"

    class DoNothingPublisher
      def log(*args)
      end

      def reconnect!
      end

      def disconnect!
      end
    end

    class LoggingPublisher 
      def log(*args)
        Rails.logger.info "Acapi::LocalAmqpPublisher - Logging subscribed event:\n#{args.inspect}"
      end

      def reconnect!
      end

      def disconnect!
      end
    end

    def self.instance
      @@instance
    end

    def self.logging!
      if @@instance
        @@instance.disconnect!
      end
      @@instance = LoggingPublisher.new
    end

    def self.disable!
      if @@instance
        @@instance.disconnect!
      end
      @@instance = DoNothingPublisher.new
    end

    def self.boot!(app_id)
      conn = Bunny.new
      conn.start
      ch = conn.create_channel
      queue = ch.queue(QUEUE_NAME, {:persistent => true})
      @@instance = self.new(conn, ch, queue, app_id)
    #  exchange = ch.topic(TOPIC_NAME, :persistent => true)
    #  @@instance = self.new(conn, ch, queue, exchange)
    #end
    end


    #def initialize(conn, ch, queue, exchange)
    def initialize(conn, ch, queue, app_id)
      @app_id = app_id
      @connection = conn
      @channel = ch
      @queue = queue
      #@exchange = exchange
    end

    def log(name, started, finished, unique_id, data = {})
      byebug
      if data.has_key?(:app_id) || data.has_key?("app_id")
        return
      end
      msg = Acapi::Amqp::OutMessage.new(@app_id, name, finished, finished, unique_id, data)
      @exchange.publish(*msg.to_message_properties)
    end

    def reconnect!
      disconnect!
      @connection = Bunny.new
      @connection.start
      @channel = @connection.create_channel
      @queue = @channel.queue(QUEUE_NAME, {:persistent => true})
    end

    def disconnect!
      @connection.close
    end

    def self.reconnect!
      instance.reconnect!
    end

    def self.log(name, started, finished, unique_id, data)
      instance.log(name, started, finished, unique_id, data)     
    end
  end
end
