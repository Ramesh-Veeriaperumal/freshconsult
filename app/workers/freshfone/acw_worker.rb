module Freshfone
  class AcwWorker < BaseWorker
    include Freshfone::AcwUtil

    sidekiq_options queue: :freshfone_trial_worker, retry: 0,
                    failures: :exhausted

    attr_accessor :params, :agent, :current_account

    def perform(params, agent)
      Rails.logger.info 'Freshfone acw worker'
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
          freshfone_user       =  current_account.freshfone_users.find_by_user_id(agent)
          current_call         =  current_account.freshfone_calls.find(params[:call_id])
          return if freshfone_user.blank? || current_call.blank? ||
                    call_work_time_updated?(current_call)

          current_call.update_acw_duration if call_metrics_enabled?(account)
          freshfone_user.reset_presence.save if freshfone_user.acw?
        end
      rescue => e
        Rails.logger.error "Error on acw worker for account #{params[:account_id]} for User #{agent}. \n#{e.message}\n#{e.backtrace.join("\n\t")}"
        NewRelic::Agent.notice_error(e, {description: "Error on Acw Worker for account #{params[:account_id]} for User #{agent}. \n#{e.message}\n#{e.backtrace.join("\n\t")}"})
        notify_error(e, params, agent)
      ensure
        ::Account.reset_current_account
      end
    end

    def notify_error(exception, params, agent)
      return if current_account.blank?
      Rails.logger.info "ACW worker account additional settings :
        #{params[:account_id]} : #{current_account.id} :
        #{current_account.account_additional_settings.present?}"
      return if current_account.account_additional_settings.blank?
      FreshfoneNotifier.freshfone_ops_notifier(current_account,
        subject: 'ACW Worker failure',
        message: "Account :: #{params[:account_id]} <br>
        User Id :: #{agent}<br>
        Params :: #{params.inspect}<br><br>
        Exception Message : #{exception.message}<br><br>
        Stacktrace :: #{exception.backtrace.join("\n\t")}<br>")
    end
  end
end
