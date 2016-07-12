class AddBuildNoActivityToScheduledTasks < ActiveRecord::Migration
  shard :none
  def up
    Helpdesk::ScheduledTask.create(
      :schedulable_type => 'Reports::BuildNoActivity',
      :schedulable_id   => 1,
      :next_run_at      => "#{Date.today.sunday.strftime('%Y-%m-%d')} 00:30:00".to_datetime,
      :frequency        => 2,
      :day_of_frequency => 0,
      :minute_of_day    => 360,
      :start_date       => Time.now.utc
    )
  end

  def down
    Helpdesk::ScheduledTask.find_by_schedulable_type('Reports::BuildNoActivity').delete
  end
end
