class CreateAffiliateDiscounts < ActiveRecord::Migration
  shard :none

  def self.up
  	create_table :affiliate_discounts do |t|
      t.string :code
      t.string :description
      t.integer :discount_type
    end
  end

  def self.down
  	drop_table :affiliate_discounts
  end
end
