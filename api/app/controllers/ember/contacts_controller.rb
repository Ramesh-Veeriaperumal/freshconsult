module Ember
  class ContactsController < ApiContactsController
    include ControllerMethods::BulkActionMethods
    decorate_views

    def index
      super
      response.api_meta = { :count => @items.count }
      render 'api_contacts/index'
    end

    def bulk_delete
      return unless validate_bulk_action_params
      sanitize_bulk_action_params
      fetch_objects
      destroy
      render_bulk_action_response(bulk_action_succeeded_items, bulk_action_errors)
    end

    def self.wrap_params
      ContactConstants::EMBER_WRAP_PARAMS
    end

    private

      def validate_bulk_action_params
        params[cname].permit(*ContactConstants::BULK_ACTION_FIELDS)
        contact_validation = ContactValidation.new(params[cname], nil)
        return true if contact_validation.valid?(:bulk_delete)

        render_errors contact_validation.errors, contact_validation.error_options
        false
      end

      def sanitize_bulk_action_params
        prepare_array_fields ContactConstants::BULK_ACTION_ARRAY_FIELDS.map(&:to_sym)
      end

      def fetch_objects(items = scoper)
        id_list = params[cname][:ids] || Array.wrap(params[cname][:id])
        @items = items.find_all_by_id(id_list)
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

      def render_201_with_location(template_name: "api_contacts/#{action_name}", location_url: "api_contact_url", item_id: @item.id)
        render template_name, location: send(location_url, item_id), status: 201
      end

      wrap_parameters(*wrap_params)
  end
end
