class Subscription::Currency < ActiveRecord::Base
  self.primary_key = :id
  not_sharded

  has_many :subscriptions,
		:class_name => "Subscription",
		:foreign_key => :subscription_currency_id

  scope :currency_by_name, -> (code) { where(name: code) }

  after_commit :clear_cache

  def self.currency_names_from_cache
    MemcacheKeys.fetch(MemcacheKeys::CURRENCY_NAMES) do
      self.all.collect(&:name)
    end
  end

  private

    def clear_cache
      MemcacheKeys.delete_from_cache(MemcacheKeys::CURRENCY_NAMES)
    end
end