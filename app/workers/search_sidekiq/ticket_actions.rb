#encoding: utf-8
class SearchSidekiq::TicketActions < SearchSidekiq::BaseWorker

  sidekiq_options :queue => :new_es_index, :retry => 2, :backtrace => true, :failures => :exhausted

  class DocumentAdd < SearchSidekiq::TicketActions
    def perform(args)
      args.symbolize_keys!
      response = Search::Filters::Docs.new.index_document(args[:klass_name], args[:id], args[:version_value])
      (custom_logger.info(formatted_log(:es_upsert, "es_filters_#{Account.current.id}", args[:id], response.code, response.body))) rescue true
    end
  end

  class DocumentRemove < SearchSidekiq::TicketActions
    def perform(args)
      args.symbolize_keys!
      response = Search::Filters::Docs.new.remove_document(args[:klass_name], args[:id])
      (custom_logger.info(formatted_log(:es_delete, "es_filters_#{Account.current.id}", args[:id], response.code, response.body))) rescue true
    end
  end
end