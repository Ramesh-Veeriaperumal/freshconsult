module Search::ElasticSearchIndex
  def self.included(base)
    base.class_eval do

      include Tire::Model::Search if ES_ENABLED

      def update_es_index
        SearchSidekiq::UpdateSearchIndex.perform_async({ :klass_name => self.class.name, 
                                                          :id => self.id }) if ES_ENABLED #and !queued?

        # For multiplexing to the cluster that count is fetched from
        add_to_es_count if self.is_a?(Helpdesk::Ticket)
      end

      def remove_es_document
        SearchSidekiq::RemoveFromIndex::Document.perform_async({ :klass_name => self.class.name, 
                                                                  :id => self.id }) if ES_ENABLED

        # For multiplexing to the cluster that count is fetched from
        remove_from_es_count if self.is_a?(Helpdesk::Ticket)
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

      ### Write methods for count cluster ###

      def add_to_es_count
        SearchSidekiq::TicketActions::DocumentAdd.perform_async({ 
                                                    :klass_name => self.class.name, 
                                                    :id => self.id,
                                                    :version_value => Search::Job.es_version
                                                  }) if Account.current.launched?(:es_count_writes)
      end

      def remove_from_es_count
        SearchSidekiq::TicketActions::DocumentRemove.perform_async({ 
                                                    :klass_name => self.class.name, 
                                                    :id => self.id 
                                                  }) if Account.current.launched?(:es_count_writes)
      end
      
    end
  end
end