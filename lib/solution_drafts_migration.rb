module SolutionDraftsMigration
	class << self

		def perform
			ShardMapping.find_in_batches(:batch_size => 300, :conditions => ['status = ?', 200]) do |shard_mappings|
				shard_mappings.each do |shard_mapping|
					migrate_for_account(shard_mapping.account_id)
				end
			end
		end

		def migrate_for_account(account_id)
			Sharding.select_shard_of(account_id) do
				begin
					Account.find(account_id).make_current
					p "*"*50
					p "Migration started for account_id #{Account.current.id}"
					default_folder = current_account.solution_folders.select{|f| f.is_default?}.first
					default_folder.articles.update_all(:status => Solution::Constants::STATUS_KEYS_BY_TOKEN[:draft])
				rescue Exception => e
					puts "-" * 50
					puts "Error while migrating drafts for Account: #{Account.current.id}"
					puts e.message
					puts "-" * 50
				end
			end
		end

	end
end