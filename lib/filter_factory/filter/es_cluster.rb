module FilterFactory::Filter
  class ESCluster < FilterFactory::Filter::Base
    include FilterFactory::Filter::EsClusterHelperMethods

    attr_accessor :scoper, :query_payload

    def initialize(scoper, args)
      super(args)
      @scoper = scoper
    end

    def execute
      query = build_encoded_fql_query
      payload = construct_es_payload(query)
      fetch_records(payload)
    end

    private

      def build_encoded_fql_query
        conditions = fetch_and_conditions
        conditions << process_or_conditions if or_conditions.present?
        query = conditions.join(' AND ')
        Rails.logger.info(" Constructed FQL query :: #{query.inspect}")
        query
      end

      def construct_es_payload(query)
        fql_response = fetch_fql_runner_response(query)
        payload = construct_search_payload(fql_response)
        Rails.logger.info "Search service payload for filtering :: #{payload.inspect}"
        payload
      end

      # Return counts as well
      def fetch_records(payload)
        es_response = SearchService::Client.new(Account.current.id).query(payload, Thread.current[:message_uuid].try(:first), search_type: scoper[:context]).records
        object_ids = es_response['results'].map { |rec| rec['id'] }
        fetch_ar_records(object_ids)
      end
  end
end
