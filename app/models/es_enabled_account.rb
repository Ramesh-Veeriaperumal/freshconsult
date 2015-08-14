class EsEnabledAccount < ActiveRecord::Base
  self.primary_key = :id

  include MemcacheKeys

  belongs_to :account
  validates_presence_of :account_id

  after_commit :create_aliases, on: :create
  after_commit :clear_cache, on: :destroy

  private

    def clear_cache
      #Remove as part of Search-Resque cleanup
      if Search::Job.sidekiq?
        SearchSidekiq::RemoveFromIndex::AllDocuments.perform_async
      else
        Resque.enqueue(Search::RemoveFromIndex::AllDocuments, { :account_id => self.account_id })
      end if ES_ENABLED
    end

    def create_aliases
      Search::EsIndexDefinition.create_aliases(self.account_id)
    end
end
