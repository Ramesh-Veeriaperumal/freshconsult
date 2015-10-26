class AddIndexesToAuthorizations < ActiveRecord::Migration

  shard :all

  def migrate(direction)
    self.send(direction)
  end

  def up
    Lhm.change_table :authorizations, :atomic_switch => true do |m|
      m.add_index [:account_id, :user_id], 'index_authorizations_on_account_id_and_user_id'
      m.add_index [:account_id, :uid, :provider], 'index_authorizations_on_account_id_uid_and_provider'
    end
  end

  def down
    Lhm.change_table :authorizations, :atomic_switch => true do |m|
      m.remove_index [:account_id, :user_id], 'index_authorizations_on_account_id_and_user_id'
      m.remove_index [:account_id, :uid, :provider], 'index_authorizations_on_account_id_uid_and_provider'
    end
  end
end