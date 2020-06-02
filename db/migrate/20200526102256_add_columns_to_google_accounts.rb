class AddEncryptedColumnToGoogleAccount < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    send(direction)
  end

  def up
    Lhm.change_table :google_accounts, atomic_switch: true do |a|
      a.add_column :encrypted_secret, 'varchar(512)'
      a.add_column :encrypted_token, 'varchar(512)'
    end
  end

  def down
    Lhm.change_table :google_accounts do |a|
      a.remove_column :encrypted_secret
      a.remove_column :encrypted_token
    end
  end
end
