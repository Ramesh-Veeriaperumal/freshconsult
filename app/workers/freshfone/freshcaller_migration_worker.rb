module Freshfone
  class FreshcallerMigrationWorker < BaseWorker
    include Freshcaller::Migration

    sidekiq_options queue: :freshcaller_migration_worker, retry: 0, backtrace: true, failures: :exhausted

    attr_accessor :params, :current_account

    def perform(params)
      Rails.logger.info "Freshcaller migrations:: #{params.inspect}"

      begin
        params.symbolize_keys!
        return if params[:account_id].blank?
        ::Account.reset_current_account
        account = ::Account.find params[:account_id]
        raise ActiveRecord::RecordNotFound if account.blank?
        account.make_current

        self.params = params
        self.current_account = account
        migrate_account
      rescue => e
        FreshdeskErrorsMailer.error_email(
          nil, nil, e.to_s,
          additional_info: { trace: e.backtrace, message: e.message },
          recipients: [FreshfoneConfig['ops_alert']['mail']['to']],
          subject: "Error in freshcaller migration for account :: #{account_id}"
        )
      ensure
        ::Account.reset_current_account
      end
    end
  end
end
