class AddCouponToAffiliateDiscounts < ActiveRecord::Migration
  shard :none
  
  def self.up
  	execute <<-SQL
  		INSERT INTO affiliate_discounts (code, description, discount_type) VALUES
  		("AFF_ALLPLANS_15P", "15 % off in all plans", 2);
  	SQL
  end

  def self.down
  	execute <<-SQL
  		DELETE FROM affiliate_discounts where code = "AFF_ALLPLANS_15P";
  	SQL
  end
end
