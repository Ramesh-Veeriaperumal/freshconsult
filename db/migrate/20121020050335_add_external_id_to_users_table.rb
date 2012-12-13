class AddExternalIdToUsersTable < ActiveRecord::Migration
  def self.up
  	add_column :users, :external_id, :string
  	add_column :users, :string_uc01, :string
  	add_column :users, :text_uc01, :text
  	execute("alter table `users` add unique index `index_users_on_account_id_and_external_id` (`account_id`,`external_id`(20))")
  end

  def self.down
    execute("alter table `users` drop index `index_users_on_account_id_and_external_id`")
  	remove_column :users, :external_id
    remove_column :users, :string_uc01
    remove_column :users, :text_uc01
  end
end
