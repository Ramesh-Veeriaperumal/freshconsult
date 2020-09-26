module Freshcaller
  class AccountDeleteWorker < BaseWorker

    sidekiq_options queue: :freshcaller_account_delete, retry: 0,  failures: :exhausted

    def perform(params)
      begin
        params.symbolize_keys!
        return if params[:account_id].blank?
        ::Account.reset_current_account
        Sharding.select_shard_of(params[:account_id]) do
          account = ::Account.find params[:account_id]
          raise ActiveRecord::RecordNotFound if account.blank?
          account.make_current
          @current_account = account
          freshcaller_calls_delete = "DELETE from freshcaller_calls where account_id = #{account.id}"
          ActiveRecord::Base.connection.execute(freshcaller_calls_delete)
          freshcaller_agents_delete = "DELETE from freshcaller_agents where account_id = #{account.id}"
          ActiveRecord::Base.connection.execute(freshcaller_agents_delete)
          account.freshcaller_account.destroy if account.freshcaller_account.present?

        end
      rescue Exception => e
        Rails.logger.error "Error on AccountDeleteWorker for account #{params[:account_id]} \n#{e.message}\n#{e.backtrace.join("\n\t")}"
        NewRelic::Agent.notice_error(e, {description: "Error on AccountDeleteWorker for account : #{params[:account_id]} \n#{e.message}\n#{e.backtrace.join("\n\t")}"})
        notify_error(e, params, @current_account)
      ensure
        ::Account.reset_current_account
      end
    end

    def notify_error(exception, params, account)
      return if account.blank?
      Rails.logger.info "AccountDeleteWorker :
      #{params[:account_id]} : #{account.id}"
      FreshfoneNotifier.freshfone_ops_notifier(account,
        subject: 'Freshcaller AccountDeleteWorker failure',
        message: "Account :: #{params[:account_id]} <br>
        Params :: #{params.inspect}<br><br>
        Exception Message : #{exception.message}<br><br>
        Stacktrace :: #{exception.backtrace.join("\n\t")}<br>")
    end

  end
end