module CronWebhooks
  class DelayedJobsWatcher < CronWebhooks::CronWebhookWorker
    sidekiq_options queue: :cron_delayedjobs_watcher, retry: 0, dead: true, failures: :exhausted

    include Redis::RedisKeys
    include Redis::OthersRedis
    include CronWebhooks::Constants

    DELAYED_JOBS_MSG = "Queue's jobs needs your attention!".freeze

    def perform(args)
      perform_block(args) do
        safe_send(@args[:task_name])
      end
    end

    private

      def delayedjobs_watcher_failed_jobs
        delayedjobs_watcher_failed
      end

      def delayedjobs_watcher_total_jobs
        delayedjobs_watcher_total
      end

      def delayedjobs_watcher_scheduled_jobs
        delayedjobs_watcher_scheduled
      end

      def delayedjobs_watcher_move_delayed_jobs
        delayedjobs_watcher_move_delayed
      end

      def delayedjobs_watcher_failed
        DelayedJobsWatcherConfig::DELAYED_JOB_QUEUES.each do |queue, config|
          queue = queue.capitalize
          failed_jobs_count = Object.const_get("#{queue}::Job").where(['last_error is not null and attempts > 1']).count

          if failed_jobs_count >= config['failed']
            FreshdeskErrorsMailer.deliver_error_email(nil, nil, nil,
                                                      subject: "#{queue} #{DELAYED_JOBS_MSG} #{failed_jobs_count} failed jobs in #{PodConfig['CURRENT_POD']}")
          end

          # For every 5 hours we will init the alert
          if (config['pg_duty_failed'] <= failed_jobs_count) &&
             $redis_others.perform_redis_op('get', "#{queue.upcase}_FAILED_JOBS_ALERTED").blank?

            Monitoring::PagerDuty.trigger_incident("delayed_jobs/#{Time.now}",
                                                   description: "#{queue} #{DELAYED_JOBS_MSG} #{failed_jobs_count} failed jobs")
            $redis_others.perform_redis_op('setex', "#{queue.upcase}_FAILED_JOBS_ALERTED", DelayedJobsWatcherConfig::PAGER_DUTY_FREQUENCY_SECS, true)
          end
        end
      end

      def delayedjobs_watcher_total
        DelayedJobsWatcherConfig::DELAYED_JOB_QUEUES.each do |queue, config|
          queue = queue.capitalize
          total_jobs_count = Object.const_get("#{queue}::Job").where(['created_at = run_at and attempts=0']).count

          if total_jobs_count >= config['total']
            FreshdeskErrorsMailer.deliver_error_email(nil, nil, nil,
                                                      subject: "#{queue} #{DELAYED_JOBS_MSG} #{total_jobs_count} enqueued jobs are in queue in #{PodConfig['CURRENT_POD']}")
          end

          # For every 5 hours we will init the alert
          if (config['pg_duty_total'] <= total_jobs_count) &&
             $redis_others.perform_redis_op('get', "#{queue.upcase}_TOTAL_JOBS_ALERTED").blank?

            Monitoring::PagerDuty.trigger_incident("delayed_jobs/#{Time.now}",
                                                   description: "#{queue} #{DELAYED_JOBS_MSG} #{total_jobs_count} enqueued jobs are in queue")
            $redis_others.perform_redis_op('setex', "#{queue.upcase}_TOTAL_JOBS_ALERTED", DelayedJobsWatcherConfig::PAGER_DUTY_FREQUENCY_SECS, true)
          end
        end
      end

      def delayedjobs_watcher_scheduled
        DelayedJobsWatcherConfig::DELAYED_JOB_QUEUES.each do |queue, config|
          queue = queue.capitalize
          total_jobs_count = Object.const_get("#{queue}::Job").where(['created_at != run_at and attempts=0']).count

          if total_jobs_count >= config['total']
            FreshdeskErrorsMailer.deliver_error_email(nil, nil, nil,
                                                      subject: "#{queue} #{DELAYED_JOBS_MSG} #{total_jobs_count} scheduled jobs are in queue in #{PodConfig['CURRENT_POD']}")
          end

          # For every 5 hours we will init the alert
          if (config['pg_duty_total'] <= total_jobs_count) &&
             $redis_others.perform_redis_op('get', "#{queue.upcase}_TOTAL_JOBS_ALERTED").blank?

            Monitoring::PagerDuty.trigger_incident("delayed_jobs/#{Time.now}",
                                                   description: "#{queue} #{DELAYED_JOBS_MSG} #{total_jobs_count} scheduled jobs are in queue")
            $redis_others.perform_redis_op('setex', "#{queue.upcase}_TOTAL_JOBS_ALERTED", DelayedJobsWatcherConfig::PAGER_DUTY_FREQUENCY_SECS, true)
          end
        end
      end

      def delayedjobs_watcher_move_delayed
        count = Delayed::Job.count
        total = 0
        while count > 250
          ActiveRecord::Base.connection.execute('UPDATE delayed_jobs SET run_at= NOW() + INTERVAL 1 WEEK ORDER BY ID LIMIT 500;')
          ActiveRecord::Base.connection.execute('INSERT INTO delayed_jobs3 SELECT * FROM delayed_jobs WHERE run_at > NOW() + INTERVAL 5 DAY ORDER BY ID LIMIT 500;')
          ActiveRecord::Base.connection.execute('DELETE FROM delayed_jobs WHERE run_at > NOW() + INTERVAL 5 DAY ORDER BY ID LIMIT 500;')
          total += (count > 500 ? 500 : count)
          count = Delayed::Job.count
        end
        if total > 0
          FreshdeskErrorsMailer.deliver_error_email(nil, nil, nil,
                                                    subject: "Moved #{total} delayed jobs to backup queue in #{PodConfig['CURRENT_POD']}",
                                                    recipients: 'mail-alerts@freshdesk.com')
        end
      end
  end
end
