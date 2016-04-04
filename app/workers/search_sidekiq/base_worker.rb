class SearchSidekiq::BaseWorker
  include Tire::Model::Search if ES_ENABLED
  include Sidekiq::Worker

  sidekiq_options :queue => :es_index_queue, :retry => 2, :backtrace => true, :failures => :exhausted

  private
    ### Methods to bypass thread-safety issues for ES ###

    def send_to_es(object, alias_name=nil)
      alias_name = (alias_name.presence || object.search_alias_name)
      if index_present?(alias_name, Account.current.id)
        url = Search::EsIndexDefinition.document_url(
                                                    Account.current.id, 
                                                    alias_name, 
                                                    object.class.name, 
                                                    object.id)
        response = Tire::Configuration.client.post(url, object.to_indexed_json)
        
        (custom_logger.info(formatted_log(:es_upsert, alias_name, object.id, response.code, response.body))) rescue true
      end
    end

    def remove_from_es(alias_name, klass_name, object_id)
      if index_present?(alias_name, Account.current.id)
        url = Search::EsIndexDefinition.document_url(
                                                    Account.current.id, 
                                                    alias_name, 
                                                    klass_name, 
                                                    object_id)
        response = Tire::Configuration.client.delete(url)
        
        (custom_logger.info(formatted_log(:es_delete, alias_name, object_id, response.code, response.body))) rescue true
      end
    end

    def remove_by_query(alias_name, query)
      if index_present?(alias_name, Account.current.id)
        query_params  = { :source => query.to_hash[:query].to_json }
        request_url   = [Search::EsIndexDefinition.index_url(alias_name, Account.current.id), '_query'].join('/')
        
        response = Tire::Configuration.client.delete("#{request_url}?#{query_params.to_params}")

        (custom_logger.info(formatted_log(:es_query_remove, alias_name, nil, response.code, response.body))) rescue true
      end
    end

    def index_present?(alias_name, account_id)
      Search::EsIndexDefinition.index_exists?(alias_name, account_id)
    end    

    ### Methods to log for ES ###

    def log_path
      @@log_file_path ||= "#{Rails.root}/log/search_sidekiq.log"
    end 

    def custom_logger
      begin
        @@es_logger ||= CustomLogger.new(log_path)
      rescue Exception => e
        NewRelic::Agent.notice_error(e)
      end
    end

    def formatted_log(op_type, alias_name, id, res_code, response)
      @@log_file_format = "#{op_type} index=#{alias_name}, doc_id=#{id}, response_code=#{res_code}, es_response=#{response.inspect}"
    end
end