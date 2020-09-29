namespace :archive_automation_old do
  desc 'This task archives all closed tickets with no activities in the last n days'
  task archive_automation_tickets: :environment do
    include Redis::ArchiveRedis
    shards = archive_automation_shards
    return if shards.blank?

    shards.each do |shard_name|
      Sharding.run_on_shard(shard_name) do
        current_archive_shard = ActiveRecord::Base.current_shard_selection.shard.to_s + '_archive'
        account_ids = account_ids_in_shard(current_archive_shard)
        account_ids.each do |account_id|
          begin
            account = Account.find(account_id).make_current
            next if account.disable_archive_enabled?

            Archive::AccountTicketsWorker.perform_async(account_id: account_id, ticket_status: :closed)
          rescue Exception => e
            Rails.logger.debug "Error in Archive automation :: #{e.message}"
          end
        end
      end
    end
  end
end
