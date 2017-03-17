module Ember
  module Search
    class AutocompleteController < ApiApplicationController
      include ::Search::V2::AbstractController

      def requesters
        @klasses        = ['User']
        @search_context = :requester_autocomplete
        @items = []
        search(esv2_autocomplete_models) do |results|
          results.each do |result|
            @items.push(*result.search_data)
          end
        end
        response.api_root_key = :requesters
        response.api_meta = { count: @items.count }
      end

      def agents
        @klasses        = ['User']
        @search_context = :agent_autocomplete
        @items = []

        search(esv2_autocomplete_models) do |results|
          results.each do |result|
            @items.push(*[{
              id: result.email,
              value: result.name,
              user_id: result.id,
              profile_img: result.avatar.nil? ? false : result.avatar.expiring_url(:thumb, 300)
            }])
          end
        end

        response.api_root_key = :agents
        response.api_meta = { count: @items.count }
      end

      def companies
        @klasses        = ['Company']
        @search_context = :company_autocomplete
        @items = []

        search(esv2_autocomplete_models) do |results|
          results.each do |result|
            @items.push(*[{
              id: result.id,
              value: result.name
            }])
          end
        end

        response.api_root_key = :companies
        response.api_meta = { count: @items.count }
      end

      def tags
        @klasses        = ['Helpdesk::Tag']
        @search_context = :tag_autocomplete
        @items = []

        search(esv2_autocomplete_models) do |results|
          results.each do |result|
            @items.push(*[{
              id: result.id, value: result.name
            }])
          end
        end

        response.api_root_key = :tags
        response.api_meta = { count: @items.count }
      end

      def company_users

      end

      private

        def esv2_autocomplete_models
          @@esv2_agent_autocomplete ||= {
            'user'    => { model: 'User',           associations: [{ :account => :features }, :user_emails] },
            'company' => { model: 'Company',        associations: [] },
            'tag'     => { model: 'Helpdesk::Tag',  associations: [] }
          }
        end

    end
  end
end
