module Search
  module V2

    class IndexRequestHandler

      attr_accessor :type, :tenant, :document_id

      def initialize(type, tenant_id, document_id)
        @type           = type
        @tenant         = Tenant.fetch(tenant_id)
        @document_id    = document_id
      end

      # Upsert individual records in ES
      #
      def send_to_es(version, routing_id, parent_id, payload)
        path = @tenant.document_path(@type, @document_id)

        send_request(path, version, routing_id, parent_id, payload)
      end
      
      # Method majorly used for pinnacle sports for duplexing request
      #
      def send_to_multilang_es(version, routing_id, parent_id, payload, locale)
        return unless @tenant.multilang_available?(@type, locale)
        
        path = @tenant.multilang_document_path(@type, @document_id, locale)

        send_request(path, version, routing_id, parent_id, payload)
      end

      # Delete individual records from ES
      #
      def remove_from_es
        path = @tenant.document_path(@type, @document_id)

        remove_request(path)
      end
      
      # Method majorly used for pinnacle sports for duplexing request
      #
      def remove_from_multilang_es(locale)
        return unless @tenant.multilang_available?(@type, locale)

        path = @tenant.multilang_document_path(@type, @document_id, locale)

        remove_request(path)
      end

      # Remove many records based on conditions
      # Eg: DELETE localhost:9200/users_1/_query?q=account_id=1 AND subject:test
      #
      def remove_by_query(query={})
        return unless query.present?
        path = [@tenant.aliases_path([@type]), '_query'].join('/')
        
        query_params = Array.new.tap do |q_params|
          query.each do |field, value|
            q_params.push("#{field}:#{value}")
          end
        end.join(' AND ')

        Utils::EsClient.new(:delete,
                            path,
                            { routing: @tenant.id, q: query_params },
                            nil,
                            Search::Utils::SEARCH_LOGGING[:response]).response
      end

      private
      
        def send_request(path, version, routing_id, parent_id, payload)
          Utils::EsClient.new(:put,
                              path,
                              add_params(version, @tenant.id, parent_id),
                              payload,
                              Search::Utils::SEARCH_LOGGING[:response]).response
        end
        
        def remove_request(path)
          Utils::EsClient.new(:delete,
                              path,
                              { routing: @tenant.id },
                              nil,
                              Search::Utils::SEARCH_LOGGING[:response]).response
        end

        # Pass external version to ES for OCC
        # Pass parent ID to ES for children
        # Parent ID takes precedence over routing key
        #
        def add_params(version, routing_id, parent_id)
          Hash.new.tap do |es_params|
            es_params[:version_type]  = 'external'
            es_params[:version]       = version
            es_params[:routing]       = routing_id
            
            # Need both parent and routing as otherwise
            # exception is raised in ES due to alias
            #
            es_params[:parent]        = parent_id if parent_id
          end
        end
    end

  end
end
