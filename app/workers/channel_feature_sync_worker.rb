# frozen_string_literal: true

class ChannelFeatureSyncWorker < BaseWorker
  sidekiq_options queue: :channel_feature_sync, retry: 0, failures: :exhausted

  def perform(args)
    args.symbolize_keys!
    begin
      start_syncing(args)
    rescue StandardError => e
      Rails.logger.info("Something went wrong, error => #{e.inspect}, args => #{args.inspect}")
      NewRelic::Agent.notice_error(e, args: args)
    end
  end

  private

    def start_syncing(args)
      retry_count = args[:retry_count] || 0
      if retry_count < 2
        unless Account.current.safe_send("#{args[:channel]}_account_present?")
          Rails.logger.info "#{args[:channel]} is not present, so retrying after #{(retry_count + 1) * 30} seconds"
          self.class.perform_in(((retry_count + 1) * 30).seconds.from_now, args.merge(retry_count: retry_count + 1))
          return
        end
        perform_channel_ops(args)
      else
        error_message = "Retry count exhausted, class_name => #{self.class.name}, args => #{args.inspect}"
        Rails.logger.info error_message
        NewRelic::Agent.notice_error(Exception.new(error_message))
      end
    end

    def perform_channel_ops(args)
      channel_sync_obj = "Omni::#{args[:channel].capitalize}CommonSync".constantize.new(args)
      channel_sync_obj.sync_channel
      if channel_sync_obj.response_success?
        Rails.logger.info "Feature got enabled successfully in #{args[:channel]}, response => #{channel_sync_obj.response_body.inspect}"
        if args[:enable_feature]
          business_calendar = Account.current.business_calendar.where(is_default: true).first
          business_calendar.safe_send('omni_business_calendar_sync', :create, args[:channel], Account.current.technicians.try(:first).try(:id)) if business_calendar.present?
        end
      elsif channel_sync_obj.service_unavailable_response?
        self.class.perform_in(((retry_count + 1) * 30).seconds.from_now, args.merge(retry_count: retry_count + 1))
      else
        Rails.logger.info "Problem in client data, class_name => #{self.class.name}, args => #{args.inspect}, response => #{channel_sync_obj.response.inspect}"
      end
    end
end
