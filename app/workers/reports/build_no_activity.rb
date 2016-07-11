class Reports::BuildNoActivity < ScheduledTaskBase
  
  include Helpdesk::Ticketfields::TicketStatus

  def execute_task(task = nil)
    run_for_all_accounts(task.nil? ? nil : task.next_run_at)
    return true
  end
  
  def run_for_all_accounts(date = nil)
    date = date || Time.now.utc
    threshold_date = Time.now.utc.to_date - 83.days
    params = {:date => date}
    Sharding.all_shards.each do |shard_name|
      params[:shard_name] = shard_name
      Sharding.run_on_shard(shard_name) do
        Sharding.run_on_slave do
          Account.active_accounts.where("accounts.created_at < ?", threshold_date).select('accounts.id').find_in_batches(:batch_size => 300) do |accounts|
            params[:account_ids] = accounts.collect(&:id)
            Reports::NoActivityWorker.perform_async(params)
          end
        end
      end
    end
  end
  
end
