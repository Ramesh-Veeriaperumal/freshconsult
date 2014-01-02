class EsEnabledAccount < ActiveRecord::Base

  include MemcacheKeys

  belongs_to :account
  validates_presence_of :account_id

  after_commit_on_create :create_aliases
  after_commit_on_destroy :clear_cache

  private

    def clear_cache
      Resque.enqueue(Search::RemoveFromIndex::AllDocuments, { :account_id => self.account_id })
      Resque.enqueue(Search::RemoveFromIndex::AllDocuments, { :account_id => self.account_id,
                                                              :aws_cluster => true })
    end

    def create_aliases
      Search::EsIndexDefinition.create_aliases(self.account_id)
      Search::EsIndexDefinition.create_aliases(self.account_id, true)
    end
end
