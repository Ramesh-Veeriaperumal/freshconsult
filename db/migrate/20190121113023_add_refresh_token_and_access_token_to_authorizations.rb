class AddRefreshTokenAndAccessTokenToAuthorizations < ActiveRecord::Migration
  shard :all
  def up
     Lhm.change_table :authorizations, :atomic_switch => true do |m|
      m.add_column :refresh_token, :text
      m.add_column :access_token, :text
    end
  end

  def down
    Lhm.change_table :authorizations do |m|
      m.remove_column :refresh_token
      m.remove_column :access_token
    end
  end
end