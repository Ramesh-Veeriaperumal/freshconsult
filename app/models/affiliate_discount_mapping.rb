class AffiliateDiscountMapping < ActiveRecord::Base
	not_sharded
	
	belongs_to :subscription_affiliate
	belongs_to :affiliate_discount

end