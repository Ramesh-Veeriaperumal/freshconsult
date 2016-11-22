class EsEnabledAccount < ActiveRecord::Base
  self.primary_key = :id

  include MemcacheKeys

  belongs_to :account
  validates_presence_of :account_id

  after_commit :create_aliases, on: :create
  after_commit :clear_cache, on: :destroy

  private

    def clear_cache
      SearchSidekiq::RemoveFromIndex::AllDocuments.perform_async if self.account.esv1_enabled?
    end

    def create_aliases
      Search::EsIndexDefinition.create_aliases(self.account_id) if self.account.esv1_enabled?
    end
end
