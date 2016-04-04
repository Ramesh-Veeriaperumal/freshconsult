class AddWebhookLimitToAccAdditionalSettings < ActiveRecord::Migration
  shard :all
  def up
    Lhm.change_table :account_additional_settings, :atomic_switch => true do |t|
      t.add_column :webhook_limit, "integer DEFAULT '1000'"
    end
  end

  def down
    Lhm.change_table :account_additional_settings, :atomic_switch => true do |t|
      t.remove_column :webhook_limit
    end
  end
end
