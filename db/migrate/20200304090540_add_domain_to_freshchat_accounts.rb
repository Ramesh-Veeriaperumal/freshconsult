class AddDomainToFreshchatAccounts < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    self.send(direction)
  end

  def up
    Lhm.change_table :freshchat_accounts, atomic_switch: true do |m|
      m.add_column :domain, "varchar(255)"
    end
  end

  def down
    Lhm.change_table :freshchat_accounts, atomic_switch: true do |m|
      m.remove_column :domain
    end
  end
end
