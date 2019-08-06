module CronWebhooks
  class SidekiqDeadSetMailer < CronWebhooks::CronWebhookWorker
    sidekiq_options queue: :cron_sidekiq_dead_set_mailer, retry: 0, dead: true, backtrace: 10, failures: :exhausted

    def perform(args)
      perform_block(args) do
        send_deadset_mailer
      end
    end

    private

      def send_deadset_mailer
        dead_set = Sidekiq::DeadSet.new
        max_dead_jobs_count = $redis_others.get('MAX_DEAD_JOBS_ALERT_COUNT') || 5000
        if dead_set.size.to_i > max_dead_jobs_count.to_i
          jobs = dead_set.each_with_object({}) { |element, result| result[element.klass.to_sym] = result[element.klass.to_sym].to_i + 1; }
          deliver_dead_jobs_list(jobs.sort_by { |_key, value| value }.reverse.to_h, dead_set.size.to_i)
        end
      end

      def deliver_dead_jobs_list(queues_list, jobs_size)
        FreshdeskErrorsMailer.deliver_sidekiq_dead_job_alert(
          subject: 'Sidekiq Dead jobs list',
          to_email: 'freshdesk-core-dev@freshdesk.com',
          from_email: 'venky@freshworks.com',
          additional_info: {
            pod_info: PodConfig['CURRENT_POD'],
            queues_list: queues_list.inspect,
            dead_jobs_size: jobs_size
          }
        )
      end
  end
end
