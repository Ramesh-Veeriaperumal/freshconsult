class AddRewardliCouponToAffiliateDiscounts < ActiveRecord::Migration
	shard :all

	def self.up
		execute <<-SQL
			INSERT INTO affiliate_discounts (code, description, discount_type) VALUES
			("AFF_ALLPLANS_20P1YEAR", "20 % off in all plans for a year", 2);
		SQL
	end

	def self.down
		execute <<-SQL
			DELETE FROM affiliate_discounts where code = "AFF_ALLPLANS_20P1YEAR";
		SQL
	end
end
