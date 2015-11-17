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
        path << add_params(version, routing_id, parent_id)
        
        Utils::EsClient.new(:put, path, payload).response
      end

      # Delete individual records from ES
      #
      def remove_from_es
        path = @tenant.document_path(@type, @document_id)
        
        Utils::EsClient.new(:delete, path).response
      end

      # Remove many records based on conditions
      # Eg: DELETE localhost:9200/users_1/_query?q=account_id=1&q=subject:test
      #
      def remove_by_query(query={})
        path = [@tenant.aliases_path([@type]), '_query'].join('/')
        
        if query.present?
          query_params = Array.new.tap do |q_params|
            query.each do |field, value|
              q_params.push("q=#{field}:#{value}")
            end
          end.join('&')
          
          path << "?#{query_params}"
        end

        Utils::EsClient.new(:delete, path).response
      end

      private

        # Pass external version to ES for OCC
        # Pass parent ID to ES for children
        # Parent ID takes precedence over routing key
        #
        def add_params(version, routing_id, parent_id)
          es_query_params = Hash.new.tap do |es_params|
            es_params[:version_type]  = 'external'
            es_params[:version]       = version
            
            if parent_id
              es_params[:parent]        = parent_id
            else
              es_params[:routing]       = routing_id
            end
          end
          
          "?#{es_query_params.to_query}"
        end
    end

  end
end
