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
      def send_to_es(version, payload)
        path = @tenant.document_path(@type, @document_id)
        path << add_versioning(version)
        
        Utils::EsClient.new(:put, path, payload).response
      end

      # Delete individual records from ES
      #
      def remove_from_es
        path = @tenant.document_path(@type, @document_id)
        
        Utils::EsClient.new(:delete, path).response
      end

      # To-Do: To add support for delete by query
      # Remove many records based on condition
      #
      def remove_by_query(query)
        path = # Alias path

        Utils::EsClient.new(:delete, path, query).response
      end

      private

        # Pass external version to ES for OCC
        #
        def add_versioning(version)
          "?#{{ :version_type => 'external', :version => version }.to_query}"
        end
    end

  end
end
