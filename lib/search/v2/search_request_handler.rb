module Search
  module V2

    class SearchRequestHandler

      attr_accessor :types, :tenant, :template_name

      def initialize(tenant_id, search_context, types=[])
        @tenant         = Tenant.fetch(tenant_id)
        @template_name  = Search::Utils::TEMPLATE_BY_CONTEXT[search_context]
        @types          = types
      end

      # Search for hits in ES and send response
      #
      def fetch(search_params)
        Utils::EsClient.new(:get, 
                            (@template_name? template_query_path : search_path), 
                            construct_payload(search_params),
                            Search::Utils::SEARCH_LOGGING[:request]
                          ).response
      end

      private

        # The path to direct search requests
        # Eg: http://localhost:9200/ticket_v1,user_v1/_search
        #
        def search_path
          [@tenant.aliases_path(@types), '_search'].join('/')
        end

        # The path to direct search requests using templates
        # Eg: http://localhost:9200/ticket_v1,user_v1/_search/template (w) payload
        #
        def template_query_path
          [@tenant.aliases_path(@types), '_search/template'].join('/')
        end

        # Params (w) chosen template for request
        #
        def construct_payload(es_params)
          {
            template: {
              id: @template_name
            },
            params: es_params
          }.to_json
        end
    end

  end
end