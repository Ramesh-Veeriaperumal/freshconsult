# Run it using 
# rake db:migrate:up VERSION=20170515122708
class CreateCollabSettings < ActiveRecord::Migration
  
  shard :all
  
  def migrate(direction)
    self.send(direction)
  end

  def up
    create_table :collab_settings do |t|
      t.integer :account_id, :limit => 8 
      t.string  :key
      t.timestamps
      t.integer :group_collab,  :limit => 1, :default => 0
    end
    add_index :collab_settings, :account_id, :name => "index_collab_settings_on_account_id"
  end

  def down
    drop_table :collab_settings
  end
end
