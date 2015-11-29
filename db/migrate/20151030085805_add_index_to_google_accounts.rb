class AddIndexToGoogleAccounts < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    self.send(direction)
  end

  def up
    Lhm.change_table :google_accounts, :atomic_switch => true do |t|
      t.add_index [:account_id]
    end
  end

  def down
    Lhm.change_table :google_accounts, :atomic_switch => true do |t|
      t.remove_index [:account_id]
    end
  end
end
