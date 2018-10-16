module Ember
  module Search
    class AutocompleteController < ApiApplicationController
      include ::Search::V2::AbstractController

      around_filter :run_on_slave

      def requesters
        @klasses        = ['User']
        @search_context = :requester_autocomplete
        @items = []
        
        if skip_auto_complete? && !@search_key.match(ApiConstants::EMAIL_REGEX).present?
          response.api_meta = { count: 0 }
        else
          @exact_match = true if skip_auto_complete?
          search(esv2_autocomplete_models) do |results|
            response.api_meta = { count: results.total_entries }
            results.each do |result|
              @items.concat(result.search_data)
            end
          end
        end
        response.api_root_key = :contacts
      end

      def agents
        @klasses        = ['User']
        @search_context = :agent_autocomplete
        @items = []

        search(esv2_autocomplete_models) do |results|
          response.api_meta = { count: results.total_entries }
          results.each do |result|
            @items.concat([{
                            id: result.email,
                            value: result.name,
                            user_id: result.id,
                            profile_img: result.avatar.nil? ? false : result.avatar.expiring_url(:thumb, 300)
                          }])
          end
        end

        response.api_root_key = :agents
      end

      def companies
        @klasses        = ['Company']
        @search_context = :company_autocomplete
        @items = []

        search(esv2_autocomplete_models) do |results|
          response.api_meta = { count: results.total_entries }
          results.each do |result|
            @items.concat([{
                            id: result.id,
                            value: result.name
                          }])
          end
        end

        response.api_root_key = :companies
      end

      def tags
        @klasses        = ['Helpdesk::Tag']
        @search_context = :tag_autocomplete
        @items = []

        search(esv2_autocomplete_models) do |results|
          response.api_meta = { count: results.total_entries }
          results.each do |result|
            @items.concat([{
                            id: result.id, value: result.name
                          }])
          end
        end

        response.api_root_key = :tags
      end

      def company_users
      end

      def skip_auto_complete?
          current_account.auto_complete_off_enabled? && !api_current_user.privilege?(:view_contacts)
      end

      private

        def esv2_autocomplete_models
          @@esv2_agent_autocomplete ||= {
            'user'    => { model: 'User',           associations: [{ account: :features }, :user_emails] },
            'company' => { model: 'Company',        associations: [] },
            'tag'     => { model: 'Helpdesk::Tag',  associations: [] }
          }
        end
    end
  end
end
