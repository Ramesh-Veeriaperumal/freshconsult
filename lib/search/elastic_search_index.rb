module Search::ElasticSearchIndex

  include Redis::RedisKeys
  include Redis::OthersRedis

  def self.included(base)
    base.class_eval do

      include Tire::Model::Search if ES_ENABLED

      def update_es_index
        # dead code. did not remove as it has lots of references. wil do later.
      end

      def remove_es_document
        # dead code. did not remove as it has lots of references. wil do later.
      end

      def remove_from_es_count
        # dead code. did not remove as it has lots of references. wil do later.
      end

      def add_to_es_count
        # dead code. did not remove as it has lots of references. wil do later.
      end      

      def search_alias_name
        if self.class == ScenarioAutomation
          "scenario_automations_#{self.account_id}"
        else
          "#{self.class.table_name}_#{self.account_id}"
        end
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
    end
  end
end
