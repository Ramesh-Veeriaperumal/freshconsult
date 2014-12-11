class CreateMobihelpTicketInfo < ActiveRecord::Migration

  shard :all

  def self.up
    create_table :mobihelp_ticket_infos do |t|
      t.column    :account_id, "bigint unsigned",         :null => false
      t.column    :ticket_id, "bigint unsigned",          :null => false
      t.column    :device_id, "bigint unsigned",          :null => false
      t.text      :app_name,                              :null => false
      t.text      :app_version,                           :null => false
      t.text      :os,                                    :null => false
      t.text      :os_version,                            :null => false
      t.text      :sdk_version,                           :null => false
      t.text      :device_make,                           :null => false
      t.text      :device_model,                          :null => false
      t.timestamps
    end
    add_index :mobihelp_ticket_infos, [:account_id, :ticket_id], :unique => true
    add_index :mobihelp_ticket_infos, [:account_id, :device_id]
  end

  def self.down
    drop_table :mobihelp_ticket_infos
  end
end
