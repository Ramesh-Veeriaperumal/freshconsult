module ScheduledTaskHelper

  def add_scheduled_task(account, options={})
    report_filter = FactoryGirl.build(:report_filters,
      account_id: account.id,
      filter_name: options[:filter_name],
      report_type: options[:report_type],
      user_id: options[:agents][:agent1].id
      )
    report_filter.save!
    scheduled_task = FactoryGirl.build(:scheduled_tasks,
      account_id: account.id,
      user_id: options[:agents][:agent1].id,
      schedulable_type: options[:scheduled_type],
      schedulable_id: report_filter.id,
      next_run_at: (Time.now + 2*60).to_datetime.utc,
      frequency: options[:frequency],
      day_of_frequency: 0,
      minute_of_day: 360,
      start_date: Time.now.utc
      )
    scheduled_task.save!
    scheduled_config = scheduled_task.schedule_configurations.build(
      notification_type: 1,
      config_data: { emails: {options[:agents][:agent1].email => options[:agents][:agent1].id, 
        options[:agents][:agent2].email => options[:agents][:agent2].id} }
    )
    scheduled_config.save!
    scheduled_task
  end

end
