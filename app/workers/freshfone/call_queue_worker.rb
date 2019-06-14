module Freshfone
  class CallQueueWorker < BaseWorker
    include Freshfone::FreshfoneUtil
    include Freshfone::Queue

    sidekiq_options :queue => :freshfone_notifications, :retry => 0, :failures => :exhausted

    attr_accessor :params, :agent, :current_account

    def perform(params, agent)
      Rails.logger.info "Freshfone call queue worker"
      Rails.logger.info "JID #{jid} - TID #{Thread.current.object_id.to_s(36)}"
      Rails.logger.info "Start time :: #{Time.now.strftime('%H:%M:%S.%L')}"
      Rails.logger.info "#{params.inspect}, agent :: #{agent}"

      begin
        params.symbolize_keys!
        return if params[:account_id].blank? || agent.blank?
        ::Account.reset_current_account
        Sharding.select_shard_of(params[:account_id]) do
          
          account = ::Account.find params[:account_id]
          raise ActiveRecord::RecordNotFound if account.blank?
          account.make_current
          
          self.current_account = account
          self.params          = params
          current_user         =  current_account.users.technicians.visible.find(agent)
          freshfone_user       =  current_user.freshfone_user if current_user.present?
          return if current_user.blank? || freshfone_user.blank? || !freshfone_user.online?
          
          bridge_queued_call agent
        end
      rescue => e
         Rails.logger.error "Error on call queue worker for account #{params[:account_id]} for User #{agent}. \n#{e.message}\n#{e.backtrace.join("\n\t")}"
         NewRelic::Agent.notice_error(e, {description: "Error in Call Queue Worker for account #{params[:account_id]} for User #{agent}. \n#{e.message}\n#{e.backtrace.join("\n\t")}"})
         notify_error(e, params, agent)
      ensure
        ::Account.reset_current_account
      end
    end

    def notify_error(exception, params, agent)
      return if current_account.blank?
      Rails.logger.info "Call queue worker account additional settings : #{params[:account_id]} : #{current_account.id} : #{current_account.account_additional_settings.present?}"
      if current_account.account_additional_settings.present?
        FreshfoneNotifier.freshfone_email_template(current_account,{
            :recipients => FreshfoneConfig['ops_alert']['mail']['to'],
            :from       => FreshfoneConfig['ops_alert']['mail']['from'],
            :subject    => "Call Queue Worker failure",
            :message    => "Account :: #{params[:account_id]} <br>
            User Id :: #{agent}<br>
            Params :: #{params.inspect}<br><br>
            Exception Message : #{exception.message}<br><br>
            Stacktrace :: #{exception.backtrace.join("\n\t")}<br>" })
      end
    end

  end
end