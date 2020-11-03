module ApiSearch
  class AutocompleteController < ApiApplicationController
    include HelperConcern
    include ::Search::V2::AbstractController
    include ApiSearch::AutocompleteConstants

    before_filter :validate_query_params, only: [:companies], unless: :private_api?
    before_filter :validate_body_params, only: [:agents], if: :private_api?
    decorate_views(decorate_objects: [:companies, :companies_search])
    SLAVE_ACTIONS = %w[requesters agents companies tags].freeze

    SEARCH_AUTOCOMPLETE_CONSTANTS_CLASS = 'ApiSearch::AutocompleteConstants'.freeze

    def requesters
      @klasses        = ['User']
      @search_context = :requester_autocomplete
      @items = []
      if skip_auto_complete? && @search_key.match(ApiConstants::EMAIL_REGEX).blank?
        response.api_meta = { count: 0 } if private_api?
      else
        @exact_match = true if skip_auto_complete?
        search(esv2_autocomplete_models) do |results|
          response.api_meta = { count: results.total_entries }
          results.each do |result|
            @items.concat(result.search_data)
          end
        end
      end
      response.api_root_key = :contacts if private_api?
    end

    def agents
      @klasses        = ['User']
      @search_context = :agent_autocomplete
      @query = params[:query]
      @items = []
      search(esv2_autocomplete_models) do |results|
        response.api_meta = { count: results.total_entries } if private_api?
        agents_list = current_account.all_agents.preload(:freshcaller_agent).where(user_id: results.map(&:id)).group_by { |item| item.user_id }
        results.each do |result|
          @items.concat([{
                          id: result.email,
                          value: result.name,
                          user_id: result.id,
                          role_ids: result.role_ids,
                          profile_img: result.avatar.nil? ? false : result.avatar.expiring_url(:thumb, 300)
                        }.merge(agent_channel_information(agents_list[result.id].first))])
        end
      end
      response.api_root_key = :agents if private_api?
    end

    def companies
      fetch_company_results
    end

    def companies_search
      fetch_company_results
      response.api_root_key = :companies
    end

    def tags
      @klasses        = ['Helpdesk::Tag']
      @search_context = :tag_autocomplete
      @items = []

      search(esv2_autocomplete_models) do |results|
        response.api_meta = { count: results.total_entries } if private_api?
        results.each do |result|
          @items.concat([{
                          id: result.id, value: result.name
                        }])
        end
      end

      response.api_root_key = :tags if private_api?
    end

    def skip_auto_complete?
      current_account.auto_complete_off_enabled? && !api_current_user.privilege?(:view_contacts)
    end

    def self.decorator_name
      'ApiSearch::AutocompleteDecorator'.constantize
    end

    private

      def fetch_company_results
        @klasses        = ['Company']
        @search_context = :company_autocomplete
        @items = []
        search(esv2_autocomplete_models) do |results|
          response.api_meta = { count: results.total_entries } if private_api?
          @items = results
        end
      end

      def construct_es_params
        super.tap do |es_params|
          es_params[:query] = @query if @search_context == :agent_autocomplete && @query.present?
        end
      end

      def agent_channel_information(agent_info)
        {}.tap do |hash_body|
          hash_body[:freshchat_agent] = agent_info.agent_freshchat_enabled? if current_account.freshchat_linked?
          hash_body[:freshcaller_agent] = agent_info.freshcaller_agent.presence.try(:fc_enabled) & true if current_account.freshcaller_enabled?
        end
      end

      def constants_class
        SEARCH_AUTOCOMPLETE_CONSTANTS_CLASS
      end

      def esv2_autocomplete_models
        AUTOCOMPLETE_MODELS
      end
  end
end
