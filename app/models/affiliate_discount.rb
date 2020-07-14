class AffiliateDiscount < ActiveRecord::Base
  self.primary_key = :id
	not_sharded

	has_many :affiliate_discount_mappings
	has_many :affiliates,
		:class_name => "SubscriptionAffiliate",
		:through => :affiliate_discount_mappings,
		:foreign_key => 'subscription_affiliate_id'

	validates_uniqueness_of :code

	COUPON_TYPES = {
		:free_agent => 1,
		:percentage => 2
	}
	
	
	scope :free_agent_coupons,
		{ :conditions => { :discount_type => COUPON_TYPES[:free_agent] }}
	scope :percentage_coupons,  
		{ :conditions => { :discount_type => COUPON_TYPES[:percentage] }}

	
	def self.retrieve_discounts(discount_ids)
		find_all_by_id(discount_ids)
	end

	def self.retrieve_discount_with_type(affiliate, discount_type)
		affiliate.discounts.find_by_discount_type(COUPON_TYPES[discount_type])
	end

end