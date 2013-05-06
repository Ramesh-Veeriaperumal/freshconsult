class EsEnabledAccount < ActiveRecord::Base

  include MemcacheKeys

  belongs_to :account
  validates_presence_of :account_id, :index_name
  after_destroy :disable_elastic_search

  def self.all_es_indices
    all.inject({}) { |result, es_ea| result[es_ea.account_id] = es_ea.imported; result }
  end

  def disable_elastic_search
    EsEnabledAccount.delete(self.id)
    MemcacheKeys.delete_from_cache(ES_ENABLED_ACCOUNTS)
  end

  def switch_to_sphinx
    self.update_attribute(:imported, false)
    MemcacheKeys.cache(ES_ENABLED_ACCOUNTS, EsEnabledAccount.all_es_indices)
  end

  def switch_to_es
    self.update_attribute(:imported, true)
    MemcacheKeys.cache(ES_ENABLED_ACCOUNTS, EsEnabledAccount.all_es_indices)
  end
end
