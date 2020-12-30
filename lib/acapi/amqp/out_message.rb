require 'securerandom'

module Acapi
  module Amqp
    class OutMessage
      AMQP_MESSAGE_PROPERTIES = [:correlation_id, :reply_to, :user_id, :content_type, :timestamp]

      def initialize(a_id, e_name, s_time, e_time, m_id, p = {})
        @app_id = a_id
        @event_name = e_name
        @start_time = s_time
        @end_time = e_time
        @message_id = m_id
        @message_id ||= SecureRandom.uuid.gsub("-","")
        @payload = p
      end

      def extract_event_properties(message_data)
        other_amqp_props = {}
        AMQP_MESSAGE_PROPERTIES.each do |prop_sym|
          if message_data.has_key?(prop_sym)
            prop_val = message_data.delete(prop_sym)
            other_amqp_props[prop_sym] = prop_val
          end
          if message_data.has_key?(prop_sym.to_s)
            prop_val = message_data.delete(prop_sym.to_s)
            other_amqp_props[prop_sym] = prop_val
          end
        end
        if (!other_amqp_props.has_key?(:correlation_id)) && (!other_amqp_props.has_key?("correlation_id"))
          other_amqp_props[:correlation_id] = SecureRandom.uuid.gsub("-","")
        end
        other_amqp_props
      end

      def to_message_properties
        message_data = @payload.dup
        body_data = message_data.delete(:body)
        if (!message_data.has_key?(:workflow_id)) && (!message_data.has_key?("workflow_id"))
          message_data[:workflow_id] = SecureRandom.uuid.gsub("-","")
        end
        body_data = body_data.nil? ? "" : body_data.to_s
        @end_time ||= Time.now
        message_props = {
          :routing_key => @event_name.sub(/\Aacapi\./, ""),
          :app_id => @app_id,
          :timestamp => @end_time.to_i,
          :headers => ({
            :submitted_timestamp => @end_time
          }).merge(message_data)
        }.merge(extract_event_properties(message_data))
        [body_data, message_props]
      end

      def to_request_properties(timeout = 1)
        message_data = @payload.dup
        body_data = message_data.delete(:body)
        body_data = body_data.nil? ? "" : body_data.to_s
        message_props = {
          :routing_key => @event_name,
          :app_id => @app_id,
          :timestamp => @end_time.to_i,
          :headers => ({
            :submitted_timestamp => @end_time
          }).merge(message_data)
        }
        [message_props, body_data, timeout]
      end
    end
  end
end
