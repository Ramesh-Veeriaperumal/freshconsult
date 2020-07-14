module Freshfone
  class TrackerWorker < BaseWorker
    sidekiq_options :queue => :freshfone_node, :retry => 0, :failures => :exhausted

    attr_accessor :current_account, :current_call, :call_id, :status

    def perform(freshfone_call, tracker_status, enqueued_time)
      Rails.logger.info 'Freshfone Tracker worker'
      Rails.logger.info "Start time :: #{Time.now.strftime('%H:%M:%S.%L')}"

      if enqueued_time
        job_latency = Time.now - Time.parse(enqueued_time)
        return if job_latency > 20
      end
      
      begin

        self.current_account = ::Account.current
        self.call_id = freshfone_call
        self.status  = tracker_status

        #Initiating SQS Push
        $sqs_freshfone_tracker.send_message(message.to_json)

        Rails.logger.info "Tracker job Completion time :: #{Time.now.strftime('%H:%M:%S.%L')}"
      rescue Timeout::Error
        Rails.logger.error "Timeout trying to publish freshfone event for #{tracker_node_uri}. \n#{options.inspect}"
        NewRelic::Agent.notice_error(StandardError.new('Error publishing data to Freshfone node. Timed out.'))
      rescue => e
        Rails.logger.error "Error publishing data to Freshfone Node. \n#{e.message}\n#{e.backtrace.join("\n\t")}"
        NewRelic::Agent.notice_error(e, description: "Timeout trying to publish freshfone event for #{tracker_node_uri}")
      end
      
    end

    private

      def message
        return connect_message if status == 'connect'
        disconnect_message
      end

      def connect_message
        credit = current_account.freshfone_credit
        {
          account: current_account.id,
          current_balance: credit.available_credit.to_f,
          threshold: Freshfone::Credit::CREDIT_LIMIT[:auto_recharge_threshold],
          call: {
            id: call_id,
            created_at: Time.now,
            connected_at: current_call.updated_at,
            status: status,
            pulse_rate: pulse_rate.pulse_charge }
        }
      end

      def disconnect_message
        { 
          account: current_account.id,
          call: {
            id: call_id,
            status: status
          }
        }
      end

      def current_call
        @current_call ||= current_account.freshfone_calls.find call_id
      end

      def pulse_rate
        Freshfone::PulseRate.new(current_call, call_forwarded?)
      end

      #Todo: Better way of identifying if a call is forwarded should be implemented.
      def call_forwarded?
        current_call.direct_dial_number.present? || twilio_forwarded?
      end

      def twilio_forwarded?
        begin
          twilio_call = current_account.freshfone_subaccount.calls.get(current_call.dial_call_sid)
          twilio_call.present? && twilio_call.forwarded_from.present?
        rescue => e
          Rails.logger.error 'Error while finding whether call is forwarded in Trial Worker'
          Rails.logger.error "Exception Message :: #{e.message}\n Exception Stacktrace :: #{e.backtrace.join('\n\t')}"
        end
      end
      ########

      def freshfone_node_session
        Digest::SHA512.hexdigest("#{FreshfoneConfig['secret_key']}::#{current_account.id}")
      end
  end
end