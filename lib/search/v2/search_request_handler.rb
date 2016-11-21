module Search
  module V2

    class SearchRequestHandler

      attr_accessor :types, :tenant, :template_name

      def initialize(tenant_id, search_context, types=[], locale='')
        @tenant         = Tenant.fetch(tenant_id)
        @template_name  = Search::Utils::TEMPLATE_BY_CONTEXT[search_context]
        @types          = types
        @locale         = locale
      end

      # Search for hits in ES and send response
      #
      def fetch(search_params)
        request_uuid = search_params.delete(:request_id)

        Utils::EsClient.new(:get, 
                            (@template_name? template_query_path : search_path), 
                            query_params,
                            construct_payload(search_params),
                            Search::Utils::SEARCH_LOGGING[:request],
                            request_uuid,
                            search_params[:account_id],
                            @tenant.home_cluster,
                            @template_name
                          ).response
      end

      private

        # The path to direct search requests
        # Eg: http://localhost:9200/ticket_v1,user_v1/_search
        #
        def search_path
          [@tenant.aliases_path(@types, @locale), '_search'].join('/')
        end

        # The path to direct search requests using templates
        # Eg: http://localhost:9200/ticket_v1,user_v1/_search/template (w) payload
        #
        def template_query_path
          [@tenant.aliases_path(@types, @locale), '_search/template'].join('/')
        end
        
        # The query params to be passed in the url
        # Eg: http://localhost:9200/user_v1/_search?routing=1
        def query_params
          Hash.new.tap do |qparams|
            qparams[:routing] = @tenant.id
          end
        end

        # Params (w) chosen template for request
        # Appending aliases by type to use in indices_query
        #
        def construct_payload(es_params)
          {
            template: {
              id: @template_name
            },
            params: es_params.merge(tenant_aliases)
          }.to_json
        end

        def tenant_aliases
          @types.collect { |type| 
            ["#{type}_alias", @tenant.multilang_alias(type, @locale)]
          }.to_h
        end
    end

  end
end