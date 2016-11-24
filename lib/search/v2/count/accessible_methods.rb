module Search
  module V2
    module Count
	
      class AccessibleMethods
        include Search::Filters::QueryHelper
        include Helpdesk::Accessible::ElasticSearchMethods
        include HelperMethods

        attr_accessor :model_class, :options, :visibility
        ES_PAGINATION_SIZE = 10

        MULTI_MATCH_STRING_SEARCH = {
          "Helpdesk::TicketTemplate"          => ["name"],
          "Admin::CannedResponses::Response"  => ["title"]
        }

        def initialize model_class, options = {}, visible_options = {}
          self.model_class = model_class
          self.options     = options
          self.visibility  = visible_options.present? ? visible_options : default_visiblity
        end

        def es_request(query_options={})
          error_handle do
            model_name = form_model_class_name model_class
            deserialized_params = es_query(query_options)
            response = Search::V2::Count::CountClient.new(:get,
                              query_path(model_name),
                              query_string,
                              deserialized_params.to_json,
                              Search::Utils::SEARCH_LOGGING[:request],
                              nil
                            ).response
            parse_db_options(model_class)
            Rails.logger.info "ES count-others response:: Account -> #{Account.current.id}, Took:: #{response["took"]}"
            records(response)
          end
        end

        def ca_folders_es_request(query_options={})
          error_handle do
            model_name = form_model_class_name model_class
            deserialized_params = ca_folders_es_query(query_options)
            response = Search::V2::Count::CountClient.new(:get,
                              query_path(model_name),
                              query_string,
                              deserialized_params.to_json,
                              Search::Utils::SEARCH_LOGGING[:request],
                              nil
                            ).response
            parse_db_options(model_class)
            Rails.logger.info "ES count-others response:: Account -> #{Account.current.id}, Took:: #{response["took"]}"
            response
          end
        end

        private

        def ca_folders_es_query(query_options)
          condition_block = default_condition_block
          condition_block[:should].push(es_filter_query(es_user_groups, visibility))
          condition_block[:must] << account_id_filter
          bool_filter_block = bool_filter(condition_block)
          query = filtered_query({}, bool_filter_block)
          query.merge(ca_folder_agg_query)
        end

        def es_query(query_options)
          folder_id     = query_options[:folder_id]
          id_data       = query_options[:id_data]
          excluded_ids  = query_options[:excluded_ids]
          type_ids      = query_options[:type_ids]
          search_string = query_options[:query_params][:search_string]

          condition_block = default_condition_block
          condition_block[:should].push(es_filter_query(es_user_groups, visibility))
          condition_block[:must].push(folder_id_query(folder_id)) if folder_id
          condition_block[:must].push(id_data_query(id_data)) if id_data
          condition_block[:must_not].push(excluded_ids_query(excluded_ids)) if excluded_ids.present?
          condition_block[:must].push(type_ids_query(type_ids)) if type_ids.present?
          condition_block[:must].push(account_id_filter)

          query = filtered_query({:must => partial_match_query(model_class, search_string)}, bool_filter(condition_block))
          query.merge(parse_es_options(options))
        end

        def folder_id_query folder_id
          term_filter("folder_id", folder_id)
        end

        def id_data_query ids
          ids_filter(ids)
        end

        def excluded_ids_query ids
          ids_filter(ids)
        end

        def type_ids_query type_ids
          terms_filter("association_type", type_ids)
        end

        def partial_match_query model_klass, search_term
          return [] if search_term.blank?
          fields = MULTI_MATCH_STRING_SEARCH[model_klass]
          condition_block = default_condition_block
          condition_block.tap do |cblock|
            cblock[:must].push(multi_match_query(search_term, MULTI_MATCH_STRING_SEARCH[model_klass]))
            cblock[:should].push(multi_match_query(search_term, MULTI_MATCH_STRING_SEARCH[model_klass], 'AND'))
          end
          [bool_filter(condition_block)]
        end

        def query_path model_name
          [host, index_alias(model_name), "_search"].join('/')
        end

        def query_string
          {routing: Account.current.id}
        end

        def index_alias name
          "#{name}_alias"
        end

        def records(response)
          args    = {:current_account_id => Account.current.id}
          preload = options[:preload] || []
          model_name = form_model_class_name model_class
          model_and_assoc = {
            model_name => {
              :model        => model_class,
              :associations => preload
            }
          }
          Search::Utils.load_records(response, model_and_assoc, args)
        end

        def parse_db_options model_class
          options[:preload] = options[:load][model_class.constantize][:include] if options[:load] && options[:load][model_class.constantize]
        end

        def parse_es_options options
          return {} if options.blank?
          {
            :size => (options[:size] || ES_PAGINATION_SIZE)
          }
        end

        def error_handle(&block)
          begin
            yield
          rescue => e
            Rails.logger.error "Exception in count-others :: #{e.message}"
            NewRelic::Agent.notice_error(e)
            nil
          end
        end

        def ca_folder_agg_query
          size = options[:size] || ES_PAGINATION_SIZE
          {
            "aggs" =>
            {
              "ca_folders" => {
                "terms" => {
                  "field"  => "folder_id",
                  "size"   => size
                }
              }
            }
          }
        end

      end

    end
  end
end