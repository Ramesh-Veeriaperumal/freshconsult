module CronWebhooks::SchedulerHelper
  include CronWebhooks::Constants
  include SchedulerSemaphoreMethods

  def empty_queue?(queue_name)
    queue_length = Sidekiq::Queue.new(queue_name).size
    Rails.logger.info "#{queue_name} queue length is #{queue_length}"
    # queue_length === 0 and !Rails.env.staging?
    if queue_length < 1
      true
    else
      subject = "Scheduler skipped for #{queue_name} at #{Time.now.utc} in #{Rails.env}"
      message = "Queue Name = #{queue_name}\nQueue Length = #{queue_length}"
      DevNotification.publish(SNS['dev_ops_notification_topic'], subject, message)
      false
    end
  end

  def enqueue_automation(name, task_name, premium_constant = 'non_premium_accounts')
    automation = case name
                 when 'supervisor'
                   SUPERVISOR_TASKS
                 when 'sla_reminder'
                   SLA_REMINDER_TASKS
                 when 'sla_escalation'
                   SLA_TASKS
                 end
    return if automation.nil?

    class_constant = automation[task_name][:class_name].constantize
    queue_name = class_constant.get_sidekiq_options['queue']
    Rails.logger.info "::::queue_name:::#{queue_name}"
    premium_constant = 'premium_accounts' if task_name.eql?('premium')

    if empty_queue?(queue_name)
      Rails.logger.info "rake=#{task_name} #{name}"
      accounts_queued = 0
      Sharding.run_on_all_slaves do
        Account.safe_send(automation[task_name][:account_method]).current_pod.safe_send(premium_constant).each do |account|
          begin
            account.make_current
            if scheduler_semaphore_exists?(account.id, class_constant)
              Rails.logger.info "[#{Time.now.utc}]It should be skipped since #{name} job for this account_id = #{account.id} has been already enqueued. Semaphore Lock Exists"
            else
              set_scheduler_semaphore(account.id, class_constant)
            end
            if name.eql?('supervisor')
              account_shard_name = ShardMapping.find_by_account_id(account.id).shard_name
              current_shard_name = ActiveRecord::Base.current_shard_selection.shard.to_s
              if account_shard_name != current_shard_name
                puts "Skipping supervisor for account #{account.id} #{account.full_domain} #{account_shard_name} #{current_shard_name}"
                next
              end
              class_constant.perform_async if account.supervisor_enabled? &&
                                              account.supervisor_rules.count > 0
            else
              class_constant.perform_async if account.sla_management_enabled?
            end
            accounts_queued += 1
          rescue StandardError => e
            NewRelic::Agent.notice_error(e)
          ensure
            Account.reset_current_account
          end
        end
      end
    end
  end
end
