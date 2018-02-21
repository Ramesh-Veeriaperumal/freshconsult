module Search::ElasticSearchIndex

  include Redis::RedisKeys
  include Redis::OthersRedis

  def self.included(base)
    base.class_eval do

      include Tire::Model::Search if ES_ENABLED

      def update_es_index
        SearchSidekiq::UpdateSearchIndex.perform_async({ :klass_name => self.class.name, 
                                                          :id => self.id }) if Account.current.esv1_enabled?
        add_to_es_count if add_to_count_esv2?
      end

      def remove_es_document
        SearchSidekiq::RemoveFromIndex::Document.perform_async({ :klass_name => self.class.name, 
                                                                  :id => self.id }) if Account.current.esv1_enabled?

        remove_from_es_count if add_to_count_esv2?
      end

      def search_alias_name
        if self.class == ScenarioAutomation
          "scenario_automations_#{self.account_id}"
        else
          "#{self.class.table_name}_#{self.account_id}"
        end
      end

      def add_to_count_esv2?
        (self.is_a?(Helpdesk::TicketTemplate)) || (es_v2_models? && redis_key_exists?(COUNT_ESV2_WRITE_ENABLED))
      end

      def es_v2_models? 
        ["ScenarioAutomation", "Admin::CannedResponses::Response"].include?(self.class.name)
      end

      def es_highlight(item)
        self.safe_send("highlight_#{item}") || h(truncate(self.safe_send("#{item}"), :length => 250))
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
        SearchSidekiq::CountActions::DocumentAdd.perform_async(esv2_default_args)
      end

      def remove_from_es_count
       SearchSidekiq::CountActions::DocumentRemove.perform_async(esv2_default_args)
      end

      def esv2_default_args
        { :klass_name => self.class.name, :document_id => self.id, :account_id => Account.current.id, :version => Search::Job.es_version}
      end
    end
  end
end
