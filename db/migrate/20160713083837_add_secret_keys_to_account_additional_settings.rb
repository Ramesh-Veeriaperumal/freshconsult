class AddSecretKeysToAccountAdditionalSettings < ActiveRecord::Migration

  shard :all

  def migrate(direction)
    self.send(direction)
  end

  def up
    Lhm.change_table :account_additional_settings, :atomic_switch => true do |t|
      t.add_column :secret_keys, :text
    end
  end

  def down
    Lhm.change_table :account_additional_settings, :atomic_switch => true do |t|
      t.remove_column :secret_keys
    end
  end

end
