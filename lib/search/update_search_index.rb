class Search::UpdateSearchIndex
  extend Resque::AroundPerform
  include Tire::Model::Search if ES_ENABLED
  @queue = "es_index_queue"

  def self.perform(args)
    args.symbolize_keys!
    @update_item = args[:klass_name].constantize.find_by_id(args[:id])
    unless @update_item.blank?
      @update_item.class.index_name @update_item.search_alias_name
      @update_item.tire.update_index_es
    end
  end
end