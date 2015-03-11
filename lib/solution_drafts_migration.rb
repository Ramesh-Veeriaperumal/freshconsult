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
					unpublished_articles = Account.current.solution_articles.find(:all, 
									:joins => %(LEFT JOIN solution_folders ON solution_folders.id = solution_articles.folder_id), 
									:conditions => ['`solution_folders`.is_default is true'])
					unpublished_articles.each do |article|
						unless article.draft
							create_draft(article)
						end
					end
				rescue Exception => e
					puts "-" * 50
					puts "Error while migrating drafts for Account: #{Account.current.id}"
					puts e.message
					puts "-" * 50
				end
			end
		end

		def create_draft(article)
			draft = article.create_draft_from_article( 
									:current_author => article.user,
									:created_author => article.user)
			if draft.save
				p "."
			else
				p "******** Error while creating draft for article #{article.id} ********"
			end
		end
	end
end