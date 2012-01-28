class CreateDayPassUsages < ActiveRecord::Migration
  def self.up
    create_table :day_pass_usages do |t|
      t.column :account_id, "bigint unsigned"
      t.column :user_id, "bigint unsigned"
      t.text :usage_info
      t.datetime :granted_on

      t.timestamps
    end
  end

  def self.down
    drop_table :day_pass_usages
  end
end
