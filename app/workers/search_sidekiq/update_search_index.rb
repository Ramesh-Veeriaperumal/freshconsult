class SearchSidekiq::UpdateSearchIndex < SearchSidekiq::BaseWorker

  def perform(args)
    args.symbolize_keys!
    @update_item = args[:klass_name].constantize.find_by_id(args[:id])
    unless @update_item.blank?
      Search::EsIndexDefinition.es_cluster(@update_item.account_id)
      @update_item.class.index_name @update_item.search_alias_name
      @update_item.tire.update_index_es if Tire.index(@update_item.search_alias_name).exists?

      handle_multiplexing if @update_item.is_a?(Solution::Article) and @update_item.account.features_included?(:es_multilang_solutions)
    end
    ensure
      key = Redis::RedisKeys::SEARCH_KEY % { :account_id => Account.current.id, :klass_name => args[:klass_name], :id => args[:id] }
      Search::Job.remove_job_key(key)
  end

  # Hack for multiplexing to old and new indices
  # Can be removed when dynamic solutions support goes live
  def handle_multiplexing
    lang = @update_item.folder.category.portals.last.try(:language)
    locale_alias = Search::EsIndexDefinition.searchable_aliases([Solution::Article], 
                                                                  @update_item.account_id, 
                                                                  { :language => lang })
    if(locale_alias != @update_item.search_alias_name)
      @update_item.class.index_name locale_alias
      @update_item.tire.update_index_es if Tire.index(locale_alias).exists?
    end
  end

end