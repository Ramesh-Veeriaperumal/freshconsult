class AddUniqueIndexToUserCompanies < ActiveRecord::Migration
  
  def self.up
    Lhm.change_table :user_companies, :atomic_switch => true do |m|
      m.remove_index [:account_id, :user_id, :company_id], 
                     "index_user_companies_on_account_id_user_id_company_id"
      m.add_unique_index [:account_id, :user_id, :company_id], 
                         "index_user_companies_on_acc_id_user_id_company_id"
    end
  end

  def self.down
    Lhm.change_table :user_companies, :atomic_switch => true do |m|
      m.remove_index [:account_id, :user_id, :company_id], 
                     "index_user_companies_on_acc_id_user_id_company_id"
      m.add_index [:account_id, :user_id, :company_id],
                  "index_user_companies_on_account_id_user_id_company_id"
    end
  end
end
