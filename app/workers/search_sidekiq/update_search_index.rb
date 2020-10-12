class SearchSidekiq::UpdateSearchIndex < SearchSidekiq::BaseWorker

  def perform(args)
    return unless Account.current.esv1_enabled?

    args.symbolize_keys!
    return if Account.current && $redis_others.sismember("DISABLE_ES_WRITES", Account.current.id)
    @update_item = args[:klass_name].constantize.find_by_id(args[:id])
    unless @update_item.blank?
      send_to_es(@update_item)
      handle_multiplexing if @update_item.is_a?(Solution::Article) and @update_item.account.es_multilang_solutions_enabled?
    end
    ensure
      key = Redis::RedisKeys::SEARCH_KEY % { :account_id => Account.current.id, :klass_name => args[:klass_name], :id => args[:id] }
      Search::Job.remove_job_key(key)
  end

  # Hack for multiplexing to old and new indices
  # Can be removed when dynamic solutions support goes live
  def handle_multiplexing
    lang = @update_item.solution_folder_meta.solution_category_meta.portals.last.try(:language)
    locale_alias = Search::EsIndexDefinition.searchable_aliases([Solution::Article], 
                                                                  @update_item.account_id, 
                                                                  { :language => lang })
    send_to_es(@update_item, locale_alias) if (locale_alias != @update_item.search_alias_name)
  end

end
