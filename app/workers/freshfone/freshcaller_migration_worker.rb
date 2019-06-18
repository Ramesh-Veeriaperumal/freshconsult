module Freshfone
  class FreshcallerMigrationWorker < BaseWorker
    include Freshcaller::Migration

    sidekiq_options queue: :freshcaller_migration_worker, retry: 0,  failures: :exhausted

    attr_accessor :params, :current_account

    def perform(params)
      Rails.logger.info "Freshcaller migrations:: #{params.inspect}"

      begin
        params.symbolize_keys!
        self.current_account = ::Account.current
        raise ActiveRecord::RecordNotFound if self.current_account.blank?
        self.params = params
        migrate_account
      rescue => e
        FreshdeskErrorsMailer.error_email(
          nil, nil, e.to_s,
          additional_info: { trace: e.backtrace, message: e.message },
          recipients: [FreshfoneConfig['ops_alert']['mail']['to']],
          subject: "Error in freshcaller migration for account :: #{self.current_account.try(:id)}"
        )
      ensure
        ::Account.reset_current_account
      end
    end
  end
end
