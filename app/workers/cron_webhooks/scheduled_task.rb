module CronWebhooks
  class ScheduledTask < CronWebhooks::CronWebhookWorker
    TASK_DISTRIBUTION = {
      # :scheduled_report => { :min_delay        => 15.seconds,
      #                        :max_delay        => 15.minute,
      #                        :offset           => 15.seconds,
      #                        :task_per_offset  => 5
      #                      }
    }
    sidekiq_options queue: :cron_scheduled_task, retry: 0, dead: true, backtrace: 10, failures: :exhausted

    def perform(args)
      perform_block(args) do
        safe_send(@args[:task_name])
      end
    end

    private

      def scheduled_task_trigger_upcoming(_account_type = 'paid')
        base_time = Time.now.utc.beginning_of_hour + Helpdesk::ScheduledTask::CRON_FREQUENCY_IN_HOURS
        process('upcoming_tasks', base_time)
      end

      def scheduled_task_trigger_dangling(_account_type = 'paid')
        process('dangling_tasks')
      end

      def scheduled_task_calculate_next_run_at(_account_type = 'paid')
        base_time = Time.now.utc
        Sharding.run_on_all_shards do
          Helpdesk::ScheduledTask.dead_tasks(base_time).find_in_batches(batch_size: 500) do |tasks|
            tasks.each do |task|
              task.mark_available unless task.available?
              task.save!
            end
          end
        end
      end

      def process(task_type, base_time = Time.now.utc)
        log "Trigger Scheduler(#{task_type}) | base_time: #{base_time}"
        @distribution_counter = {}
        task_count = 0
        Sharding.run_on_all_slaves do
          Helpdesk::ScheduledTask.current_pod.safe_send(task_type.to_s, base_time).find_in_batches(batch_size: 500) do |tasks|
            tasks.each do |task|
              task_count += 1
              enqueue_task(task)
            end
          end
        end
        subject = "Scheduler(#{task_type}) | processed #{task_count} task"
        message = subject + " | base_time: #{base_time}"
        log(message)
      end

      def log(message, error = nil, task = nil)
        message = "#{message} | Account - #{task.account_id} | Task - #{task.as_json({}, false).inspect}" if task
        if error
          level = 'ERROR'
          NewRelic::Agent.notice_error(error, description: message)
          message = "#{message}\n#{error.message}\n#{error.backtrace.join("\n\t")}"
          DevNotification.publish(SNS['reports_notification_topic'], "Error :: Scheduler | #{error.message}", message)
        else
          level = 'INFO'
        end
        Rails.logger.info "[#{Time.now.utc}]::[#{level}]::[Scheduler] | #{message}"
      end

      def enqueue_task(task)
        Account.reset_current_account
        User.reset_current_user
        task.account.make_current if task.account
        task.user.make_current if task.user

        schedule_time = task.next_run_at
        if task.next_run_at > Time.now.utc
          schedule_time += task_distribute_lag(task)
        end
        Sharding.run_on_master do
          task.trigger(schedule_time)
        end
      rescue Exception => e
        log('Failed on scheduling task', e, task)
      ensure
        Account.reset_current_account
        User.reset_current_user
      end

      def task_distribute_lag(task)
        return 0 unless dist_prop = TASK_DISTRIBUTION[task.schedulable_name]
        dist_key = "#{task.account_id}:#{task.next_run_at}"
        count = @distribution_counter[dist_key] = @distribution_counter[dist_key].to_i + 1
        delay = dist_prop[:min_delay] + (dist_prop[:offset] * (count / dist_prop[:task_per_offset])).seconds
        delay > dist_prop[:max_delay] ? dist_prop[:max_delay] : delay
      end
  end
end
