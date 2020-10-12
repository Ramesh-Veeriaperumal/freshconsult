# frozen_string_literal: true

class Admin::BusinessCalendar::OmniSyncWorker < BaseWorker
  sidekiq_options queue: :omni_business_calendar_sync, retry: 2, failures: :exhausted
  include Helpdesk::IrisNotifications
  include ApiBusinessCalendarConstants

  sidekiq_retries_exhausted do |message, error|
    NewRelic::Agent.notice_error(message['error_message'], description: 'Exception while sync of Business Calendar')
    Rails.logger.error("Failed #{message['class']} with #{message['args']}: #{message['error_message']}")
    args = message['args'][0]
    args.symbolize_keys!
    failure_notifications(args)
  end
  
  def perform(args)
    args.symbolize_keys!
    begin
      if args[:action].to_sym == :delete
        handle_business_calendar_destroy(args)
      else
        sync_to_channel(args)
      end
    rescue StandardError => e
      Rails.logger.info("Going to be retried as #{args[:channel]} calendar #{args[:action]} failed for id - #{args[:id]}")
      raise e
    end
  end

  def handle_business_calendar_destroy(args)
    id = args[:id]
    channel = args[:channel]
    channel_sync_obj = Omni::SyncFactory.fetch_bc_sync(channel: channel, resource_id: id, action: :delete, performed_by_id: args[:performed_by_id])
    channel_sync_obj.sync_channel
    if channel_sync_obj.service_unavailable_response?
      raise "#{args[:channel]} calendar #{args[:action]} failed for id - #{args[:id]} due to 5xx"
    elsif channel_sync_obj.response_success?
      Rails.logger.info("#{channel} calendar Destroy successful for ID - #{id}")
    else
      Rails.logger.info "#{args[:channel]} calendar #{args[:action]} failed for id - #{args[:id]} due to 4xx "
    end
  end

  def sync_to_channel(args)
    channel_sync_obj = Omni::SyncFactory.fetch_bc_sync(
                                                        channel: args[:channel],
                                                        resource_id: args[:id],
                                                        action: args[:action],
                                                        params: args[:params],
                                                        performed_by_id: args[:performed_by_id]
                                                      )
    channel_sync_obj.sync_channel
    if channel_sync_obj.response_success?
      self.class.update_sync_status(args[:id], args[:channel], args[:action], BusinessCalenderConstants::OMNI_SYNC_STATUS[:success])
      Rails.logger.info("#{args[:channel]} calendar #{args[:action]} successful for id - #{args[:id]}")
    elsif !channel_sync_obj.service_unavailable_response?
      self.class.failure_notifications(args)
    else
      raise "#{args[:channel]} calendar #{args[:action]} failed for id - #{args[:id]}"
    end
  end

  def self.failure_notifications(args)
    # sidekiq_retries_exhausted can call only class methods
    update_sync_status(args[:id], args[:channel], args[:action], BusinessCalenderConstants::OMNI_SYNC_STATUS[:failed]) if args[:action].to_sym != :delete
    Class.new.extend(Helpdesk::IrisNotifications).push_data_to_service(IrisNotificationsConfig['api']['collector_path'], iris_payload(args, BusinessCalenderConstants::OMNI_SYNC_STATUS[:failed]))
    send_status_mail(args)
  end

  def self.update_sync_status(business_calendar_id, channel, action, status)
    business_calendar = business_calendar_obj(business_calendar_id)
    business_calendar.safe_send("set_sync_channel_status", channel, action, status)
    business_calendar.save
    business_calendar.reload
  end

  def self.business_calendar_obj(business_calendar_id)
    Account.current.business_calendar.where(id: business_calendar_id).first
  end

  def self.send_status_mail(args)
    Rails.logger.info "performed_by_id is not present in the args" && return unless args[:performed_by_id]
    user = Account.current.users.where(id: args[:performed_by_id]).first
    Admin::BcOmniSyncStatusMailer.send_sync_status_email(user, business_calendar_obj(args[:id]), args[:action])
  end

  def self.iris_payload(args, status)
    {
        payload: {
            channel: ApiBusinessCalendarConstants::API_PRODUCT_TO_CHANNEL[args[:channel].to_s].to_s,
            resource_id: args[:id],
            resource_type: BusinessCalenderConstants::RESOURCE_NAME,
            name: business_calendar_obj(args[:id]).try(:name),
            action: args[:action],
            params: args[:params],
            status: status,
            user_id: args[:performed_by_id]
        },
        payload_type: BusinessCalenderConstants::IRIS_NOTIFICATION_TYPE,
        account_id: Account.current.id.to_s
    }
  end
end
