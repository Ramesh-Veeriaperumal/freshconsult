class Reports::ScheduledReportsCleanup < BaseWorker

  include HelpdeskReports::Helper::PlanConstraints

  sidekiq_options :queue => :scheduled_reports_cleanup, :retry => 0, :backtrace => true, :failures => :exhausted

  def perform(args)
    begin
      Sharding.select_shard_of(args[:account_id]) do
        account = Account.find_by_id(args[:account_id])
        account.make_current
        unless enable_schedule_report?
          tasks = account.scheduled_tasks.by_schedulable_type("Helpdesk::ReportFilter")
          tasks.destroy_all
        end
      end
    rescue Exception => e
      puts e.inspect, account.inspect
      NewRelic::Agent.notice_error(e, {:account => account})
    end
  end
end
