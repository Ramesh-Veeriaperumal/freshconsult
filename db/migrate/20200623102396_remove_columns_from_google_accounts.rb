class RemoveNonencryptedColumnFromGoogleAccount < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    send(direction)
  end

  def up
    Lhm.change_table :google_accounts, atomic_switch: true do |a|
      a.remove_column :secret
      a.remove_column :token
    end
  end

  def down
    Lhm.change_table :google_accounts do |a|
      a.add_column :secret, 'varchar(255)'
      a.add_column :token, 'varchar(255)'
    end
  end
end
