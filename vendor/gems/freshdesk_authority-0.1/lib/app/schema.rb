# Setup the db
ActiveRecord::Schema.define(:version => 1) do
  create_table :accounts, :force => true do |t|
    t.column :name, :string
  end
  
  create_table :users, :force => true do |t|
    t.column :name, :string
    t.column :account_id, :integer
    t.column :privileges, :string
  end

  create_table :projects, :force => true do |t|
    t.column :name, :string
    t.column :account_id, :integer
    t.column :user_id, :integer
  end
  
  create_table :follow, :force => true do |t|
    t.column :user_id, :integer
    t.column :project_id, :integer
  end
end
