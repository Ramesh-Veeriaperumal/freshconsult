class Search::UpdateSearchIndex
  extend Resque::AroundPerform
  include Tire::Model::Search if ES_ENABLED
  @queue = "es_index_queue"

  def self.perform(args)
    args.symbolize_keys!
    @update_item = args[:klass_name].constantize.find_by_id(args[:id])
    unless @update_item.blank?
      Search::EsIndexDefinition.es_cluster(@update_item.account_id)
      @update_item.class.index_name @update_item.search_alias_name
      @update_item.tire.update_index_es if Tire.index(@update_item.search_alias_name).exists?
    end
    ensure
      key = Redis::RedisKeys::SEARCH_KEY % { :account_id => args[:account_id], :klass_name => args[:klass_name], :id => args[:id] }
      Search::Job.remove_job_key(key)
  end
end