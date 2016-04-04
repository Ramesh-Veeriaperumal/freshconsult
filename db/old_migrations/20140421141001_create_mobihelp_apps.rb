class CreateMobihelpApps < ActiveRecord::Migration
  shard :all
  def self.up
    create_table :mobihelp_apps do |t|
      t.column    :account_id, "bigint unsigned", :null => false
      t.string    :name,            :null => false
      t.integer   :platform,        :null => false
      t.string    :app_key,         :null => false
      t.string    :app_secret,      :null => false
      t.text      :config
      t.timestamps
    end
    add_index :mobihelp_apps, [ :account_id ]
    add_index :mobihelp_apps, [ :account_id, :app_key , :app_secret ], :unique => true
    add_index :mobihelp_apps, [ :account_id, :name, :platform], :unique => true
  end

  def self.down
    drop_table :mobihelp_apps
  end
end
