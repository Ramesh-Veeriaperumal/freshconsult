class AddDataExportCleanupToScheduledTasks < ActiveRecord::Migration
  shard :none
  def up
    Helpdesk::ScheduledTask.create(
      :schedulable_type => 'DataExportCleanup',
      :next_run_at      => "#{Date.tomorrow.strftime('%Y-%m-%d')} 00:30:00".to_datetime,
      :frequency        => 1,
      :start_date       => Time.now.utc,
      :minute_of_day    => 360
    )
  end

  def down
    Helpdesk::ScheduledTask.find_by_schedulable_type('DataExportCleanup').delete
  end
end
