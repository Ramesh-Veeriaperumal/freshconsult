class PopulateSolutionMetaTables < ActiveRecord::Migration
	
    shard :all

	COMMON_ATTRIBUTES = {
        "Solution::Category" => ["position", "is_default", "account_id", "created_at"],
        "Solution::Folder" => ["visibility", "position", "is_default", "account_id", "created_at"],
        "Solution::Article" => ["account_id", "art_type", "thumbs_up", "thumbs_down", "position", "created_at"]
    }

    PARENT_KEYS = {
        "PortalSolutionCategory" => ["solution_category_meta_id", "solution_category_id"], 
        "Solution::CustomerFolder" => ["folder_meta_id", "folder_id"],
        "Mobihelp::AppSolution" => ["solution_category_meta_id", "category_id"]
    }

	def migrate(direction)
		self.send(direction)
	end

	def up
		Account.reset_current_account
		Account.find_in_batches(:batch_size => 100) do |accounts|
			accounts.each do |account|
				migrate_to_meta_table(account)
			end
		end
        populate_mapping_tables
	end

    def down
        query_list = []
        query_list << "delete from solution_article_meta;"
        query_list << "delete from solution_folder_meta;"
        query_list << "delete from solution_category_meta;"
        query_list << "update portal_solution_categories set solution_category_meta_id = NULL;"
        query_list << "update solution_customer_folders set folder_meta_id = NULL;"
        query_list << "update mobihelp_app_solutions set solution_category_meta_id = NULL;"
        query_list.each do |query_string| 
            ActiveRecord::Base.connection.execute query_string
        end     
    end

    private

	def migrate_to_meta_table(account)
        meta_read_launched = account.launched?(:meta_read)
        account.rollback(:meta_read) if meta_read_launched
        account.make_current
        ["solution_categories", "solution_folders", "solution_articles"].each do |assoc|
            account.send("#{assoc}_without_association").find_in_batches(:batch_size => 100, 
                :include => ["#{assoc.singularize}_meta"]) do |sol_objects|
                sol_objects.each do |sol_object|
                    migrate_object(sol_object)
                end
            end
        end
        account.launch(:meta_read) if meta_read_launched
        Account.reset_current_account
    end

    def migrate_object(obj)
        begin
            meta_obj = obj.meta_object
            COMMON_ATTRIBUTES[obj.class.name].each do |attrib|
                meta_obj.send("#{attrib}=", obj.send(attrib))
            end
            obj.assign_defaults(meta_obj)
            return false unless meta_obj.save
            print '.'
            return meta_obj
        rescue Exception => e
            return false
        end
    end

    def populate_mapping_tables
        ["PortalSolutionCategory", "Solution::CustomerFolder", "Mobihelp::AppSolution"].each do |klass|
            populate_meta(klass)
        end
    end

    def populate_meta class_name
      current_class = class_name.constantize
      current_class.find_in_batches(:conditions => {PARENT_KEYS[class_name].first.to_sym => nil}, 
        :batch_size => 100) do |batch|
        sql = "UPDATE #{current_class.table_name} SET #{PARENT_KEYS[class_name].first}=#{PARENT_KEYS[class_name].last} WHERE id in (#{batch.map(&:id).join(', ')})"
        ActiveRecord::Base.connection.execute sql
      end
    end
end