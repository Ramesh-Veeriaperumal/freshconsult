#encoding: utf-8
class SearchSidekiq::CountActions < SearchSidekiq::BaseWorker

  sidekiq_options :queue => :esv2_count_index, :retry => 2, :backtrace => true, :failures => :exhausted

  class DocumentAdd < SearchSidekiq::CountActions
    def perform(args)
      return unless Account.current.launched?(:countv2_template_write)
      args.symbolize_keys!      
      Search::V2::Count::Doc.new(args).index_es_count_document
      (custom_logger.info(formatted_log(:es_upsert, "#{args[:klass_name].demodulize.downcase}_#{Account.current.id}", args[:id], response.code, response.body))) rescue true
    end
  end

  class DocumentRemove < SearchSidekiq::CountActions
    def perform(args)
      return unless Account.current.launched?(:countv2_template_write)
      args.symbolize_keys!
      Search::V2::Count::Doc.new(args).remove_es_count_document
      (custom_logger.info(formatted_log(:es_delete, "#{args[:klass_name].demodulize.downcase}_#{Account.current.id}", args[:id], response.code, response.body))) rescue true
    end
  end
end