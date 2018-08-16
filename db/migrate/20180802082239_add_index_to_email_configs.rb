class AddIndexToEmailConfigs < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    send(direction)
  end

  def up
    Lhm.change_table :email_configs, atomic_switch: true do |m|
      m.add_index([:account_id, :active, :primary_role], 'index_email_configs_on_account_id_active_and_primary_role')
    end
  end

  def down
    Lhm.change_table :email_configs, atomic_switch: true do |m|
      m.remove_index([:account_id, :active, :primary_role], 'index_email_configs_on_account_id_active_and_primary_role')
    end
  end
end
