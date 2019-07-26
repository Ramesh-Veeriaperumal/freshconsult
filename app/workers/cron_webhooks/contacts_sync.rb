module CronWebhooks
  class ContactsSync < CronWebhooks::CronWebhookWorker
    sidekiq_options queue: :cron_contacts_sync, retry: 0, dead: true, backtrace: 10, failures: :exhausted

    include CronWebhooks::Constants

    def perform(args)
      perform_block(args) do
        safe_send(@args[:task_name])
      end
    end

    private

      def contacts_sync_trial
        execute_sync 'trial'
      end

      def contacts_sync_paid
        execute_sync 'paid'
      end

      def contacts_sync_free
        execute_sync 'free'
      end

      def log_file_contact_sync
        @log_file_path = "#{Rails.root}/log/rake.log"
      end

      def custom_logger_contact_sync(path)
        @custom_logger_contact_sync ||= CustomLogger.new(path)
      end

      def execute_sync(task_name)
        begin
          Rails.logger.info "Contacts Sync initialized at #{Time.zone.now}"
          path = log_file_contact_sync
          rake_logger = custom_logger_contact_sync(path)
        rescue StandardError => e
          Rails.logger.info "Error --- \n#{e.message}\n#{e.backtrace.join("\n")}"
          FreshdeskErrorsMailer.error_email(nil, nil, e,
                                            subject: 'Splunk logging Error for contacts_sync.rake', recipients: 'integrations@freshesk.com')
        end

        class_constant = CONTACTS_SYNC_TASKS[task_name][:class_name].constantize
        queue_name = class_constant.get_sidekiq_options['queue']
        Rails.logger.info "::::queue_name:::#{queue_name}"

        rake_logger.info "rake=contacts_sync #{task_name}" unless rake_logger.nil?
        accounts_queued = 0
        Sharding.run_on_all_slaves do
          Account.current_pod.safe_send(CONTACTS_SYNC_TASKS[task_name][:account_method]).each do |account|
            begin
              installed_application = account.installed_applications.joins(:application).where(
                'name in (?)', Integrations::Constants::CONTACTS_SYNC_APPS
              ).last
              next if installed_application.nil?

              app_name = installed_application.application.name
              account.make_current
              class_constant.perform_async(app_name, :sync_contacts)
              accounts_queued += 1
            rescue StandardError => e
              Rails.logger.info "Error --- \n#{e.message}\n#{e.backtrace.join("\n")}"
              NewRelic::Agent.notice_error(e, custom_params: { account_id: Account.current.id, installed_application: installed_application.to_json })
            ensure
              Rails.logger.info "\n#{accounts_queued} accounts have been queued\n"
              Account.reset_current_account
            end
          end
        end
      end
  end
end
