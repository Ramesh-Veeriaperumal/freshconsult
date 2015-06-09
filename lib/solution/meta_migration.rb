class Solution::MetaMigration

	class << self

		def perform(shard_name)
			problematic_objects_by_account = {}
			ShardMapping.find_in_batches(:conditions => {:shard_name => shard_name}) do |smaps|
				smaps.each do |smap|
					problematic_objects = perform_for_account(smap.account_id)
					problematic_objects_by_account[account.id] = problematic_objects unless problematic_objects.values.flatten.blank?
				end
			end
			
			problematic_objects_by_account
		end

		def perform_for_account(account_id)
			Sharding.select_shard_of(account_id) do
				account = Account.find_by_id(account_id)
				return {} unless account
				migrate_to_meta_table(account)
			end
		end

		def migrate_to_meta_table(account)
			account.make_current
			problematic_objects = {} 
			problematic_objects[:categories] = migrate_categories
			problematic_objects[:folders] = migrate_folders if problematic_objects[:categories].blank?
			problematic_objects[:articles] = migrate_articles if problematic_objects[:folders].blank?
			Account.reset_current_account
			problematic_objects
		end

		def migrate_categories
			problematic_categories = []
			Account.current.solution_categories.find_in_batches(:batch_size => 100) do |categories|
				categories.each do |category|
					unless category.solution_category_meta
						problematic_categories unless migrate_object(category)
					end
				end
			end
			problematic_categories
		end

		def migrate_folders
			problematic_folders = []
			Account.current.folders.find_in_batches(:batch_size => 100) do |folders|
				folders.each do |folder|
					unless folder.solution_folder_meta
						problematic_folders unless migrate_object(folder)
					end
				end
			end
			problematic_folders
		end

		def migrate_articles
			problematic_articles = []
			Account.current.solution_articles.find_in_batches(:batch_size => 100) do |articles|
				articles.each do |article|
					unless article.solution_article_meta
						problematic_articles unless migrate_object(article)
					end
				end
			end
			problematic_articles
		end

		def migrate_object(obj)
			begin
				meta_obj = obj.build_meta
				return false unless meta_obj.save
				print '.'
				return meta_obj
			rescue Exception => e
				p "***** Exception caught while migrating #{obj.class.name} ##{obj.id} for account ##{Account.current.id} *****"
				p "***** All underlying objects won't be migrated *****"
				p "\n#{e.message}\n#{e.backtrace.join("\n")}"
				return false
			end
		end
	end
end