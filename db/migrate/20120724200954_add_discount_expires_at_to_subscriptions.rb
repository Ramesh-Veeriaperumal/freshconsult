class AddDiscountExpiresAtToSubscriptions < ActiveRecord::Migration
  def self.up
    add_column :subscriptions, :discount_expires_at, :datetime
  end

  def self.down
    remove_column :subscriptions, :discount_expires_at
  end
end
