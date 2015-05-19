#to be performed only after successful mirroring of data from solution tables to meta tables
class Solution::PopulateMetaColumn

	class << self

		def perform(shard_name)
			problematic_objects_by_account = { :portal_categories => {}, :mobihelp_solutions => {}, :customer_folders => {}}
			ShardMapping.find_in_batches(:conditions => {:shard_name => shard_name}) do |smaps|
				smaps.each do |smap|
					account_id = smap.account_id
					problematic_categories = populate_portal_solution_categories(account_id)
					problematic_objects_by_account[:portal_categories][account_id] = problematic_categories unless problematic_categories.blank?
					problematic_mobihelp_solutions = populate_mobihelp_app_solutions(account_id)
					problematic_objects_by_account[:mobihelp_solutions][account_id] = problematic_mobihelp_solutions unless problematic_mobihelp_solutions.blank?
					problematic_customer_folders = populate_solution_customer_folders(account_id)
					problematic_objects_by_account[:customer_folders][account_id] = problematic_customer_folders unless problematic_customer_folders.blank?
				end
			end
			
			problematic_objects_by_account
		end

		def populate_portal_solution_categories(account_id)
			Sharding.select_shard_of account_id do
				account = Account.find_by_id(account_id)
				return [] unless account
				populate_meta(account, "portal_solution_categories", :solution_category_meta_id, "solution_category_id")
			end
		end

		def populate_mobihelp_app_solutions(account_id)
			Sharding.select_shard_of account_id do
				account = Account.find_by_id(account_id)
				return [] unless account
				populate_meta(account, "mobihelp_app_solutions", :solution_category_meta_id, "category_id")
			end
		end

		def populate_solution_customer_folders(account_id)
			Sharding.select_shard_of account_id do
				account = Account.find_by_id(account_id)
				return [] unless account
				populate_meta(account, "solution_customer_folders", :folder_meta_id, "folder_id")
			end
		end

		private
		def populate_meta(account, assoc, column, value_attr)
			problematic_objects = []
			account.make_current
			account.send(assoc).find_in_batches(:batch_size => 30) do |objects|
				objects.each do |obj|
					if obj.send(column).blank?
						begin
							problematic_objects << obj.id  unless obj.update_column(column, obj.send(value_attr))
						rescue Exception => e
							problematic_objects << obj.id
							p "***** Exception caught while migrating #{obj.class.name} ##{obj.id} for account ##{Account.current.id} *****"
							p "\n#{e.message}\n#{e.backtrace.join("\n")}"
							sleep(3)					
						end
					end
				end
			end
			Account.reset_current_account
			problematic_objects
		end
	end
end