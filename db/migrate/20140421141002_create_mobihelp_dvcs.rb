class CreateMobihelpDvcs < ActiveRecord::Migration
  shard :all
  def self.up
    create_table :mobihelp_devices do |t|
      t.column    :account_id, "bigint unsigned",       :null => false
      t.column    :user_id, "bigint unsigned",          :null => false
      t.column    :app_id, "bigint unsigned",           :null => false
      t.string    :device_uuid,                         :null => false
      t.text      :info,                                :null => true
      t.timestamps
    end

    add_index :mobihelp_devices, [ :account_id, :app_id, :device_uuid ], :unique => true
    add_index :mobihelp_devices, [ :account_id, :user_id, :device_uuid ]
  end

  def self.down
    drop_table :mobihelp_devices
  end
end
