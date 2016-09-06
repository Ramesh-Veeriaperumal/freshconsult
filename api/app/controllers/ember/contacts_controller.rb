module Ember
  class ContactsController < ApiContactsController
    include DeleteSpamConcern
    decorate_views

    def index
      super
      response.api_meta = { count: contacts_filter(scoper).count }
      render 'api_contacts/index'
    end

    def self.wrap_params
      ContactConstants::EMBER_WRAP_PARAMS
    end

    private

      def fetch_objects(items = scoper)
        @items = items.find_all_by_id(params[cname][:ids])
      end

      def bulk_action_errors
        @bulk_action_errors ||=
          params[cname][:ids].inject({}) { |a, e| a.merge retrieve_error_code(e) }
      end

      def retrieve_error_code(id)
        if bulk_action_failed_items.include?(id)
          { id => :unable_to_perform }
        elsif !bulk_action_succeeded_items.include?(id)
          { id => :"is invalid" }
        else
          {}
        end
      end

      def bulk_action_succeeded_items
        @succeeded_ids ||= @items.map(&:id) - bulk_action_failed_items
      end

      def bulk_action_failed_items
        @failed_ids ||= @items_failed.map(&:id)
      end

      def render_201_with_location(template_name: "api_contacts/#{action_name}", location_url: 'api_contact_url', item_id: @item.id)
        render template_name, location: send(location_url, item_id), status: 201
      end

      wrap_parameters(*wrap_params)
  end
end
