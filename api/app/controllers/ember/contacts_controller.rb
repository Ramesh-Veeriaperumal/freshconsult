module Ember
  class ContactsController < ApiContactsController
    decorate_views

    def index
      super
      response.api_meta = { :count => @items.count }
      render 'api_contacts/index'
    end

    def bulk_delete
      return unless validate_deletion_params
      sanitize_deletion_params
      fetch_contacts
      delete_contacts
    end

    def self.wrap_params
      ContactConstants::EMBER_WRAP_PARAMS
    end

    private

      def delete_contacts
        @contacts_not_deleted = []
        @items.each do |item|
          @contacts_not_deleted << item.id unless item.update_attribute(:deleted, 'true')
        end

        if bulk_delete_errors.any?
          render_partial_success(deleted_contact_ids, bulk_delete_errors)
        else
          head 205
        end
      end

      def bulk_delete_errors
        @bulk_delete_errors ||=
          params[cname][:ids].inject({}) { |a, e| a.merge deletion_error(e) }
      end

      def invalid_contact_ids
        @invalid_ids ||= params[cname][:ids] - @items.map(&:id)
      end

      def deleted_contact_ids
        @deleted_ids ||= @items.map(&:id) - @contacts_not_deleted
      end

      def deletion_error(id)
        if invalid_contact_ids.include?(id)
          { id => :"is invalid" }
        elsif @contacts_not_deleted.include?(id)
          { id => :unable_to_delete }
        else
          {}
        end
      end

      def fetch_contacts(items = scoper)
        @items = items.find_all_by_id(params[cname][:ids])
      end

      def validate_deletion_params
        params[cname].permit(*ContactConstants::BULK_DELETE_FIELDS)
        contact_validation = ContactValidation.new(params[cname], nil)
        return true if contact_validation.valid?(action_name.to_sym)

        render_errors contact_validation.errors, contact_validation.error_options
        false
      end

      def sanitize_deletion_params
        prepare_array_fields ContactConstants::BULK_DELETE_ARRAY_FIELDS.map(&:to_sym)
      end

      def render_201_with_location(template_name: "api_contacts/#{action_name}", location_url: "api_contact_url", item_id: @item.id)
        render template_name, location: send(location_url, item_id), status: 201
      end

      wrap_parameters(*wrap_params)
  end
end
