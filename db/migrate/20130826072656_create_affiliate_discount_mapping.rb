class CreateAffiliateDiscountMapping < ActiveRecord::Migration
  shard :none

  def self.up
    create_table :affiliate_discount_mappings, :id => false do |t|
      t.column :subscription_affiliate_id, "bigint unsigned"
      t.column :affiliate_discount_id, "bigint unsigned"
    end
  end

  def self.down
    drop_table :affiliate_discount_mappings
  end
end