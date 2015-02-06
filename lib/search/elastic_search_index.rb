module Search::ElasticSearchIndex
  def self.included(base)
    base.class_eval do

      include Tire::Model::Search if ES_ENABLED

      def update_es_index
        Resque.enqueue(Search::UpdateSearchIndex, { :klass_name => self.class.name,
                                                    :id => self.id,
                                                    :account_id => self.account_id }) if ES_ENABLED and !queued?
      end

      def remove_es_document
        Resque.enqueue(Search::RemoveFromIndex::Document, { :klass_name => self.class.name,
                                                            :id => self.id,
                                                            :account_id => self.account_id }) if ES_ENABLED
      end

      def search_alias_name
        if self.class == ScenarioAutomation
          "scenario_automations_#{self.account_id}"
        else
          "#{self.class.table_name}_#{self.account_id}"
        end
      end

      def es_highlight(item)
        self.send("highlight_#{item}") || h(truncate(self.send("#{item}"), :length => 250))
      end

      def queued?
        key = self.search_job_key
        Search::Job.check_in_queue key
      end

      def search_job_key
        Redis::RedisKeys::SEARCH_KEY % { :account_id => self.account_id, :klass_name => self.class.name, :id => self.id }
      end
      
    end
  end
end