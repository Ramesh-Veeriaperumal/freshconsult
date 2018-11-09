class DataExportCleanup < ScheduledTaskBase
  
  def execute_task(task = nil)
    Sharding.run_on_all_shards do
      DataExport.old_data_backup.find_each do |data_export|
        begin
          account = data_export.account
          account.make_current
          data_export.destroy
        rescue Exception => e
          NewRelic::Agent.notice_error(e, 
            {:description => "Error on executing DataExportCleanup scheduled task"})
        ensure
          Account.reset_current_account
        end
      end
    end 
    true
  end
  
end