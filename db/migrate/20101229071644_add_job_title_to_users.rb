class AddJobTitleToUsers < ActiveRecord::Migration
  def self.up
    add_column :users, :customer_id,     :integer
    add_column :users, :job_title,       :string
    add_column :users, :second_email,    :string
    add_column :users, :phone,           :string
    add_column :users, :mobile,          :string
    add_column :users, :twitter_id,      :string
    add_column :users, :description,     :text
    
    add_index :users, :customer_id
    
  end

  def self.down
    
    remove_index :users, :customer_id
    
    remove_column :users, :customer_id
    remove_column :users, :job_title
    remove_column :users, :second_email
    remove_column :users, :phone
    remove_column :users, :mobile
    remove_column :users, :twitter_id
    remove_column :users, :description
  end
end
