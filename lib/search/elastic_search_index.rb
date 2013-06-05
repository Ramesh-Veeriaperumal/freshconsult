module Search::ElasticSearchIndex
  def self.included(base)
    base.class_eval do

      include Tire::Model::Search if ES_ENABLED

      def update_es_index
        Resque.enqueue(Search::UpdateSearchIndex, { :klass_name => self.class.name, :id => self.id,
                                                    :account_id => self.account_id }) if es_available? and ES_ENABLED
      end

      def remove_es_document
        Resque.enqueue(Search::RemoveFromIndex, { :klass_name => self.class.name, :id => self.id,
                                                  :account_id => self.account_id }) if es_available? and ES_ENABLED
      end

      def es_available?
          es_enable_status = MemcacheKeys.fetch(MemcacheKeys::ES_ENABLED_ACCOUNTS) { EsEnabledAccount.all_es_indices }
          es_enable_status.key?(self.account_id)
      end
    end
  end
end