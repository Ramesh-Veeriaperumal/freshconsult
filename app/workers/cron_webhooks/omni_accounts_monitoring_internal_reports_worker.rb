# frozen_string_literal: true

module CronWebhooks
  class OmniAccountsMonitoringInternalReportsWorker < CronWebhooks::CronWebhookWorker
    include Redis::OthersRedis
    include Redis::Keys::Others
    sidekiq_options queue: :cron_omni_accounts_monitoring_internal_reports, retry: 0, dead: true, backtrace: 10, failures: :exhausted

    MONITORTING_REPORTS_LOGGER_PREFIX = 'OmniAccountsMonitoringInternalReports :: '
    REPORT_FILE_NAME_PREFIX = 'omni_accounts_monitoring_internal_reports_'
    REPORT_SUBJECT_PREFIX = 'Omni Accounts Monitoring Internal Reports - '
    def perform(args)
      perform_block(args) do
        begin
          return 0 if stop_omni_internal_reports_execution?

          start_time = Time.now.utc
          Rails.logger.info "#{MONITORTING_REPORTS_LOGGER_PREFIX} Starting Monitoring Reports Worker :: #{start_time}"
          init
          generate_report_and_send_email
          end_time = Time.now.utc
          Rails.logger.info "#{MONITORTING_REPORTS_LOGGER_PREFIX} Finished Monitoring Reports Worker :: #{end_time} :: #{end_time - start_time}"
        rescue StandardError => e
          Rails.logger.info "#{MONITORTING_REPORTS_LOGGER_PREFIX} An Exception occured :: perform :: #{e.inspect}"
        end
      end
    end

    private

      def init
        @total_bundle_accounts = 0
        @failed_freshchat_accounts = 0
        @failed_freshcaller_accounts = 0
        @time_start = start_time_for_reports
      end

      def generate_report_and_send_email
        csv_string = CSVBridge.generate do |csv_data|
          csv_data << %w[account_id domain bundle_id freshchat_domain freshcaller_domain error]
          generate_omni_accounts_created_reports(csv_data)
        end
        file_path = File.join('/tmp', REPORT_FILE_NAME_PREFIX + "#{Time.now.to_i}.csv")
        File.delete(file_path) if File.exist?(file_path)
        File.open(file_path, 'w+') { |f| f.write(csv_string) }
        email_subject = "#{REPORT_SUBJECT_PREFIX} #{PodConfig['CURRENT_POD']} - #{Time.now.utc.to_datetime.inspect}"
        to_emails = get_all_members_in_a_redis_set(OMNI_ACCOUNTS_MONITORING_MAILING_LIST) || []
        OmniChannel::EmailUtil::Emailer.export_data('supreme@freshdesk.com', to_emails.join(','), email_subject, construct_email_body, [file_path]) if to_emails.present?
        File.delete(file_path) if File.exist?(file_path)
      end

      def generate_omni_accounts_created_reports(csv_data)
        Sharding.select_latest_shard do
          Sharding.run_on_slave do
            plan_ids = SubscriptionPlan.omni_channel_plan.pluck(:id)
            Subscription.where("created_at > ? and state != 'suspended' and subscription_plan_id in (?)", @time_start, plan_ids).find_in_batches(batch_size: 100) do |subscriptions|
              begin
                return 0 if stop_omni_internal_reports_execution?

                subscriptions.each do |subscription|
                  check_account(subscription, csv_data)
                end
              rescue StandardError => e
                Rails.logger.info "#{MONITORTING_REPORTS_LOGGER_PREFIX} An Exception occured :: generate_omni_accounts_created_reports :: #{e.inspect}"
              end
            end
          end
        end
      end

      def check_account(subscription, csv_data)
        selected_account = subscription.account
        check_the_account_status(selected_account, csv_data) if selected_account&.make_current&.omni_bundle_account?
      end

      def check_the_account_status(account, csv_data)
        @total_bundle_accounts += 1
        freshcaller_account_domain = account.freshcaller_account.try(:domain)
        freshchat_account_domain = account.freshchat_account.try(:domain)
        @failed_freshchat_accounts += 1 if freshchat_account_domain.nil?
        @failed_freshcaller_accounts += 1 if freshcaller_account_domain.nil?
        csv_data << [account.id, account.full_domain, account.omni_bundle_id, freshchat_account_domain, freshcaller_account_domain, nil]
      rescue StandardError => e
        Rails.logger.info "#{MONITORTING_REPORTS_LOGGER_PREFIX} An Exception occured :: check_the_account_status :: #{e.inspect}"
        csv_data << [account.id, account.full_domain, account.omni_bundle_id, nil, nil, "Exception :: #{e.message}"]
      ensure
        Account.reset_current_account
      end

      def construct_email_body
        log_bundle_account_info
        body = "<h3> Bundle Account Created From #{@time_start.to_datetime.inspect} to #{Time.now.utc.to_datetime.inspect} Information </h3>"
        body += "<p>Total bundle accounts created - #{@total_bundle_accounts}</p>"
        body += "<p>No. of bundle accounts without freshchat - #{@failed_freshchat_accounts}</p>" if @failed_freshchat_accounts
        body += "<p>No. of bundle accounts without freshcaller - #{@failed_freshcaller_accounts}</p>" if @failed_freshcaller_accounts
        body
      end

      def log_bundle_account_info
        Rails.logger.info "#{MONITORTING_REPORTS_LOGGER_PREFIX} INFO :: Bundle Accounts Created :: #{@total_bundle_accounts}"
        Rails.logger.info "#{MONITORTING_REPORTS_LOGGER_PREFIX} INFO :: Bundle Accounts Without Freshchat :: #{@failed_freshchat_accounts}"
        Rails.logger.info "#{MONITORTING_REPORTS_LOGGER_PREFIX} INFO :: Bundle Accounts Without Freshcaller :: #{@failed_freshcaller_accounts}"
      end

      def start_time_for_reports
        start_time = get_others_redis_key(OMNI_ACCOUNTS_MONITORING_START_TIME).to_i
        if start_time && start_time != 0 && start_time < 720
          Rails.logger.info "#{MONITORTING_REPORTS_LOGGER_PREFIX} Start Time :: start_time_for_reports :: #{start_time}"
          return start_time.hours.ago.utc
        else
          Rails.logger.info "#{MONITORTING_REPORTS_LOGGER_PREFIX} Start Time is greater than 720 Hours or 0 hours (4 Hrs Default) :: start_time_for_reports :: #{start_time}"
          4.hours.ago.utc
        end
      end

      def stop_omni_internal_reports_execution?
        redis_key_exists?(OMNI_ACCOUNTS_MONITORING_STOP_EXECUTION)
      end
  end
end
