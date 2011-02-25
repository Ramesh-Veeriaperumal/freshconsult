class CreateEmailConfigs < ActiveRecord::Migration
  def self.up
    create_table :email_configs do |t|
      t.integer :account_id
      t.string :to_email
      t.string :reply_email
      t.integer :group_id

      t.timestamps
    end
  end

  def self.down
    drop_table :email_configs
  end
end
