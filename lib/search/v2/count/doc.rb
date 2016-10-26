module Search
  module V2
    module Count

      class Doc
        include Search::V2::Count::HelperMethods
        attr_accessor :account_id, :payload, :options

        def initialize(payload = nil, account_id = Account.current.id, options = {})
          @account_id= account_id
          @payload = payload
          @options = options
        end

        def index_es_count_document
          payload.symbolize_keys!
          Time.use_zone('UTC') do
            model_class = payload[:klass_name]
            document_id = payload[:document_id]
            model_object  = model_class.constantize.find_by_id(document_id)
            return if model_object.nil?
            version       = {
              :version_type => 'external',
              :version      => payload[:version].to_i
            }
            Search::V2::Count::CountClient.new("put",document_path(model_class, document_id, version), query_params.merge(version), model_object.to_count_es_json)
          end
        end

        def remove_es_count_document
          payload.symbolize_keys!
          model_class = payload[:klass_name]
          document_id = payload[:document_id]
          Search::V2::Count::CountClient.new(:delete, document_path(model_class, document_id), query_params, nil, Search::Utils::SEARCH_LOGGING[:response]).response
        end

        def document_path(model_class, id, query_params={})
          model_class_name = form_model_class_name model_class
          path    = [host, index_alias(model_class_name), model_class_name, id].join('/')
        end

        def query_params
          { :routing => Account.current.id}
        end

        def index_alias name 
          "#{name}_alias"
        end

      end
    end
  end
end
