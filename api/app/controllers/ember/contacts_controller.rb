module Ember
  class ContactsController < ApiContactsController
    include DeleteSpamConcern
    decorate_views

    def index
      super
      response.api_meta = { count: @items_count }
      render 'api_contacts/index'
    end

    def send_invite
      send_activation_mail(@item) ? (head 204) : render_errors(@contact_delegator.errors, @contact_delegator.error_options)
    end

    def bulk_send_invite
      bulk_action do
        @items_failed = []
        @items.each do |item|
          @items_failed << item unless send_activation_mail(item)
        end
      end
    end

    def self.wrap_params
      ContactConstants::EMBER_WRAP_PARAMS
    end

    private

      def scoper
        if !params[:tag].blank?
          tag = current_account.tags.find_by_name(params[:tag])
          return (tag || Helpdesk::Tag.new).contacts
        end
        super
      end

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

      def send_activation_mail(item)
        @contact_delegator = ContactDelegator.new(item)
        valid = @contact_delegator.valid?(:send_invite)
        item.deliver_activation_instructions!(current_portal, true) if valid && item.has_email?
        valid
      end

      wrap_parameters(*wrap_params)
  end
end
