class AffiliateDiscount < ActiveRecord::Base
  self.primary_key = :id
	not_sharded

	has_many :affiliate_discount_mappings
	has_many :affiliates,
		class_name: "SubscriptionAffiliate",
		through: :affiliate_discount_mappings,
		foreign_key: 'subscription_affiliate_id'

	validates_uniqueness_of :code

	COUPON_TYPES = {
		free_agent: 1,
		percentage: 2
	}

	COUPON_TYPES.each do |name, value|
		scope :"#{name}_coupons", -> { where(discount_type: COUPON_TYPES[name]) }
	end

	def self.retrieve_discounts(discount_ids)
		where(id: discount_ids)
	end

	def self.retrieve_discount_with_type(affiliate, discount_type)
		affiliate.discounts.find_by_discount_type(COUPON_TYPES[discount_type])
	end

end