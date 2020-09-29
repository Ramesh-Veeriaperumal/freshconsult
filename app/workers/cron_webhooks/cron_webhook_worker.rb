module CronWebhooks
  class CronWebhookWorker < BaseWorker
    sidekiq_options queue: :cron_webhook, retry: 0, dead: true, backtrace: 10, failures: :exhausted

    include ::CronWebhooks::CronHelper
    include CronWebhooks::Constants
    include Redis::Semaphore

    protected

      def perform_block(args)
        @args = HashWithIndifferentAccess.new(args)

        lock_and_run(get_semaphore_key(@args), expiry) do
          Rails.logger.info "cron job enqueued successfully :: #{@args.inspect}" if dry_run_mode?(@args[:mode])
          return if !validate_args || (dry_run_mode?(@args[:mode]) && !dry_run_supported?)

          yield
        end
      rescue StandardError => e
        Rails.logger.info "Error occured while processing #{@args[:task_name]}::#{@args[:type]}"
        NewRelic::Agent.notice_error(e, args: @args)
      ensure
        del_semaphore get_semaphore_key(@args, CronWebhooks::Constants::CONTROLLER)
      end

      def validate_args
        return TASKS.include? @args[:task_name] unless @args[:type]

        TASKS.include?(@args[:task_name]) && TYPES.include?(@args[:type])
      end

      def expiry
        TASK_MAPPING[@args[:task_name].to_sym][:semaphore_expiry] || nil
      end

      def dry_run_supported?
        DRYRUN_SUPPORTED_TASKS.include?(@args[:task_name])
      end
  end
end
