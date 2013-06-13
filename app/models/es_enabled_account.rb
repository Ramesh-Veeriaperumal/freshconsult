class EsEnabledAccount < ActiveRecord::Base

  include MemcacheKeys

  belongs_to :account
  belongs_to :elasticsearch_index, :class_name => "ElasticsearchIndex"
  validates_presence_of :account_id

  after_commit_on_create :set_cache
  after_commit_on_update :set_cache
  after_commit_on_destroy :clear_cache

  def self.all_es_indices
    all.inject({}) { |result, es_ea| result[es_ea.account_id] = es_ea.imported; result }
  end

  private
    def set_cache
     MemcacheKeys.cache(ES_ENABLED_ACCOUNTS, EsEnabledAccount.all_es_indices) 
    end

    def clear_cache
      MemcacheKeys.delete_from_cache(ES_ENABLED_ACCOUNTS)
      key = ES_INDEX_NAME % { :account_id => self.account_id }
      MemcacheKeys.delete_from_cache(key)
    end
end
