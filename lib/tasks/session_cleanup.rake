namespace :session_cleanup do
  desc 'This task deletes all the sessions that are stale for more than a month'
  task suspended_accounts_deletion: :environment do
    cutoff_period = 30.days.ago
    Sharding.run_on_all_shards do
      HelpkitSession.where('updated_at < ?', cutoff_period).destroy_all
    end
  end
end
