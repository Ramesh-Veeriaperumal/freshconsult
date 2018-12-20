class CreateSocialFbUserIdMapping < ActiveRecord::Migration
  shard :all
  def migrate(direction)
    self.send(direction)
  end
  def up
    create_table :social_fb_user_id_mapping do |t|
      t.column  :account_id, "bigint unsigned", :null => false
      t.column  :user_id, "bigint unsigned", :null => false
      t.column  :fb_page_id, "bigint unsigned", :null => false
      t.column  :page_scope_id, "bigint unsigned", :null => false
      t.column  :app_scope_id, "bigint unsigned"
      t.timestamps
    end
    add_index :social_fb_user_id_mapping, [:account_id, :page_scope_id], :name => 'index_social_fb_user_id_mapping_on_account_id_page_scope_id', :unique => true
    add_index :social_fb_user_id_mapping, [:account_id, :fb_page_id, :app_scope_id], :name => 'index_fb_user_id_mapping_account_id_fb_page_id_app_scope_id'
    add_index :social_fb_user_id_mapping, [:account_id, :user_id], :name => 'index_social_fb_user_id_mapping_on_account_id_user_id'
  end

  def down
    drop_table :social_fb_user_id_mapping
  end
end
