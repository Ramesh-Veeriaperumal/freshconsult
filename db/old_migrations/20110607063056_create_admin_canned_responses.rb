class CreateAdminCannedResponses < ActiveRecord::Migration
  def self.up
    create_table :admin_canned_responses do |t|
      t.string  :title
      t.text    :content , :limit => 16777215      
      t.integer :account_id , :limit => 8
      
      t.timestamps      
    end
    add_index :admin_canned_responses, [:account_id, :created_at], :name => 'index_admin_canned_responses_on_account_id_and_created_at'
    
  end

  def self.down       
    drop_table :admin_canned_responses
  end
end
