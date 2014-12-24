class PopulateMobihelpAppSolutions < ActiveRecord::Migration
  shard :all
  include MemcacheKeys
  def self.up
    Mobihelp::App.all.each do |app|
      if app.app_solutions.blank?
        begin
          account_id = app.account_id
          account = Account.find(account_id)
          account.make_current
          category_id = app.config[:solutions].to_i
          category = Solution::Category.find_by_id_and_account_id(category_id, account_id)
          if category
            app.app_solutions.create(:category_id => category_id, :position => 1)
            
            #This deletes the previous version of the Memcache Key depending on category_id
            MemcacheKeys.delete_from_cache("MOBIHELP_SOLUTION_UPDATED_TIME:%{account_id}:%{category_id}" % { :account_id => account_id, :category_id => category_id })
            MemcacheKeys.delete_from_cache("MOBIHELP_SOLUTIONS:%{account_id}:%{category_id}" % { :account_id => account_id, :category_id => category_id })
          end
        rescue Exception => e
          puts "Mobihelp App Solutions Migration failed for app_id => #{app_id} :: Exception => #{e}"
        ensure
          Account.reset_current_account
        end
      end
    end
  end

  def self.down
    Mobihelp::AppSolution.delete_all
  end
end
