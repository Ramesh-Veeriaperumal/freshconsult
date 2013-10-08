module Search::ElasticSearchIndex
  def self.included(base)
    base.class_eval do

      include Tire::Model::Search if ES_ENABLED

      def update_es_index
        Resque.enqueue(Search::UpdateSearchIndex, { :klass_name => self.class.name, :id => self.id,
                                                    :account_id => self.account_id }) if ES_ENABLED
      end

      def remove_es_document
        Resque.enqueue(Search::RemoveFromIndex::Document, { :klass_name => self.class.name, :id => self.id,
                                                  :account_id => self.account_id }) if ES_ENABLED
      end

      def search_alias_name
        "#{self.class.table_name}_#{self.account_id}"
      end

      def es_highlight(item)
        self.send("highlight_#{item}") || h(self.send("#{item}"))
      end
      
    end
  end
end