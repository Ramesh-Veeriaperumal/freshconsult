class AffiliateDiscount < ActiveRecord::Base

	has_and_belongs_to_many :affiliates, 
		:class_name => 'SubscriptionAffiliate', 
		:join_table => 'affiliate_discount_mappings'

	validates_uniqueness_of :code

	COUPON_TYPES = {
		:free_agent => 1,
		:percentage => 2
	}
	
	named_scope :free_agent_coupons,
		{ :conditions => { :discount_type => COUPON_TYPES[:free_agent] }}
	named_scope :percentage_coupons,  
		{ :conditions => { :discount_type => COUPON_TYPES[:percentage] }}
	
end