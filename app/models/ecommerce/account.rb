class Ecommerce::Account < ActiveRecord::Base

  include Cache::Memcache::Ecommerce

  self.table_name = :ecommerce_accounts
  serialize :configs, Hash
  attr_accessible :name, :group_id, :product_id
  belongs_to_account
  belongs_to :product
  belongs_to :group
  after_commit :clear_cache

  scope :reauth_required, -> { where(reauth_required: true) }

  STATUS_TYPES = [
  	[:inactive, "inactive", 1],
  	[:active, "active", 2],
  	[:deleted, "deleted", 3]
  ]

  ACCOUNT_STATUS = Hash[*STATUS_TYPES.map { |i| [i[0], i[2]] }.flatten]

  ACCOUNT_STATUS.each_pair do |k, v|
    define_method("#{k}?") do
      status == v
    end
  end

end