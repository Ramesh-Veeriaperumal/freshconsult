module Search
  module Dashboard
    class Count
      attr_accessor :account_id, :payload, :options

      def initialize(payload = nil, account_id = Account.current.id, options = {})
        @account_id = account_id
        @payload = payload
        @options = options
      end

      def index_es_count_document
        payload.symbolize_keys!
        Time.use_zone('UTC') do
          model_class = payload[:klass_name]
          model_object = model_class.constantize.find_by_id(payload[:document_id])
          return if model_object.nil?

          push_document_update(model_object)
        end
      end

      def remove_es_count_document
        payload.symbolize_keys!
        model_class = payload[:klass_name]
        document_id = payload[:document_id]
        delete_from_analytics_cluster(document_id)
      end

      def alias_name
        if Rails.env.production?
          "es_filters_count_#{es_shard_name}_alias"
        else
          'es_filters_count_alias'
        end
      end

      def document_path(model_class, id, query_params = {})
        path = [host, alias_name, model_class.demodulize.downcase, id].join('/')
        query_params.merge!(query_string)
        query_params.blank? ? path : "#{path}?#{query_params.to_query}"
      end

      def host
        ::COUNT_V2_HOST
      end

      def query_string
        { routing: account_id }
      end

      def aliases(action_name = 'add')
        action_list = []
        action_list << ({ action_name => {
          index: index_name,
          alias: alias_name,
          filter: { term: { account_id: account_id.to_s } }, routing: account_id.to_s
        } })
      end

      def index_name
        if Rails.env.production?
          "es_filters_count_#{es_shard_name}"
        else
          'es_filters_count'
        end
      end

      def fetch_dashboard_shard(query_params = {})
        response = Search::Dashboard::CountClient.new('get', dashboard_shard_path(query_params), nil).response
        return response['_source']['shard_name'] if response.present? && response['_source'].present? && response['_source']['shard_name'].present?
        rescue Exception => e
          Rails.logger.info("Error fetching shard :: #{e.message}")
      end

      def index_new_account_dashboard_shard
        Search::Dashboard::CountClient.new('put', dashboard_shard_path, account_shard_info_data).response
      end

      def account_shard_info_data
        { 'shard_name' => ActiveRecord::Base.current_shard_selection.shard.to_s }.to_json
      end

      def dashboard_shard_path(query_params = {})
        path = [host, dashboard_alias_name, 'dashboard_shard', account_id].join('/')
        query_params.blank? ? path : "#{path}?#{query_params.to_query}"
      end

      def dashboard_alias_name
        'dashboard_shard_alias'
      end

      def es_shard_name
        Account.current.dashboard_shard_name.to_s.gsub('_', '')
      end

      def ticket_delete_or_spam?(model_object)
        model_object.class == Helpdesk::Ticket && (model_object.deleted || model_object.spam)
      end

      def push_document_update(model_object)
        version_stamp = payload[:version].to_i
        version = {
          version_type: 'external',
          version: version_stamp
        }
        write_to_analytics_cluster(model_object, version_stamp)
      end

      def write_to_analytics_cluster(model_object, version_stamp)
        Rails.logger.info "Index to CountClient --- account::: #{@account_id}, #{@payload[:klass_name]}::: #{@payload[:document_id]}, action::: #{@payload[:action]}, version::: #{version_stamp}"
        SearchService::Client.new(@account_id).write_count_object(model_object, version_stamp)
      end

      def delete_from_analytics_cluster(document_id)
        Rails.logger.info "Remove from CountClient --- account::: #{@account_id}, #{@payload[:klass_name]}::: #{@payload[:document_id]}, action::: #{@payload[:action]}"
        SearchService::Client.new(@account_id).delete_object('ticketanalytics', document_id)
      end
    end
  end
end
