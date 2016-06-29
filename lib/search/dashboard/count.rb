module Search
  module Dashboard

    class Count
      attr_accessor :account_id, :payload

      def initialize(payload = nil, account_id = Account.current.id)
        @account_id= account_id
        @payload = payload
      end

      def index_es_count_document
        payload.symbolize_keys!
        Time.use_zone('UTC') do
          model_class = payload[:klass_name]
          document_id = payload[:document_id]
          model_object  = model_class.constantize.find_by_id(document_id)
          version       = {
            :version_type => 'external',
            :version      => payload[:version].to_i
          }
          Search::V2::Utils::EsClient.new("put",document_path(model_class, document_id, version), model_object.to_count_es_json)
        end
      end

      def remove_es_count_document
        payload.symbolize_keys!
        model_class = payload[:klass_name]
        document_id = payload[:document_id]
        Search::V2::Utils::EsClient.new(:delete, document_path(model_class, document_id), nil, Search::Utils::SEARCH_LOGGING[:response]).response
      end

      def create_alias
        Search::V2::Utils::EsClient.new(:post, 
                            [host, '_aliases'].join('/'), 
                            ({ actions: aliases }.to_json),
                            Search::Utils::SEARCH_LOGGING[:all]
                          ).response
      end

      def remove_alias
        Search::V2::Utils::EsClient.new(:post, 
                            [host, '_aliases'].join('/'), 
                            ({ actions: aliases("remove") }.to_json),
                            Search::Utils::SEARCH_LOGGING[:all]
                          ).response
      end

      def alias_name
        "es_count_#{account_id}"
      end

      def document_path(model_class, id, query_params={})
        path    = [host, alias_name, model_class.demodulize.downcase, id].join('/')
        query_params.blank? ? path : "#{path}?#{query_params.to_params}"
      end

      def host
        ::COUNT_V2_HOST
      end

      def aliases(action_name = "add")
        action_list = []
        action_list << ({action_name=>{"index"=>index_name,"alias"=>alias_name,"filter"=>{"term"=>{"account_id"=>account_id.to_s}}, "routing"=>account_id.to_s}})
      end

      def index_name
        "es_filters_count"
      end

    end
  end
end