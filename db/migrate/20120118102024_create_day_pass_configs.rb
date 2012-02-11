class CreateDayPassConfigs < ActiveRecord::Migration
  def self.up
    create_table :day_pass_configs do |t|
      t.column :account_id, "bigint unsigned"
      t.integer :available_passes
      t.boolean :auto_recharge
      t.integer :recharge_quantity

      t.timestamps
    end
  end

  def self.down
    drop_table :day_pass_configs
  end
end
