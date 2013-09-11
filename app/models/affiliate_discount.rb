class AffiliateDiscount < ActiveRecord::Base
    not_sharded
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

	
	def self.retrieve_discounts(discount_ids)
		find_all_by_id(discount_ids)
	end

	def self.retrieve_discount_with_type(affiliate, discount_type)
		affiliate.discounts.find_by_discount_type(COUPON_TYPES[discount_type])
	end

end