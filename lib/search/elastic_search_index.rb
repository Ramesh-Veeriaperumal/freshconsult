module Search::ElasticSearchIndex
  def self.included(base)
    base.class_eval do

      include Tire::Model::Search

      def update_es_index
        Resque.enqueue(Search::UpdateSearchIndex, { :klass_name => self.class.name, :id => self.id }) if es_available?
      end

      def es_available?
          es_enable_status = MemcacheKeys.fetch(MemcacheKeys::ES_ENABLED_ACCOUNTS) { EsEnabledAccount.all_es_indices }
          es_enable_status.key?(self.account_id)
      end
    end
  end
end