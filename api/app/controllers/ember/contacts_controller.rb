module Ember
  class ContactsController < ApiContactsController
    include DeleteSpamConcern
    decorate_views

    before_filter :can_change_password?, :validate_password_change, only: [:update_password]

    def create
      assign_protected
      contact_delegator = ContactDelegator.new(@item, email_objects: @email_objects, custom_fields: params[cname][:custom_field], 
                                                avatar_id: params[cname][:avatar_id])
      if !contact_delegator.valid?
        render_custom_errors(contact_delegator, true)
      else
        build_user_emails_attributes if @email_objects.any?
        if @item.create_contact!
          render :show, location: api_contact_url(@item.id), status: 201
        else
          render_custom_errors
        end
      end
    end

    def show
    end

    def index
      super
      response.api_meta = { count: @items_count }
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

    def update_password
      @item.password = params[cname][:password]
      @item.active = true
      
      if @item.save
        @item.reset_perishable_token!
        head 204
      else
        ErrorHelper.rename_error_fields({ base: :password }, @item)
        render_errors(@item.errors)
      end
    end

    def activities
      @user_activities = case params[:type]
      when 'tickets'
        ticket_activities
      when 'archived_tickets'
        archived_ticket_activities
      when 'forums'
        @item.recent_posts
      else
        combined_activities
      end
    end

    def whitelist
      return head 204 if whitelist_item(@item)
      render_errors(@item.errors) if @item.errors.any?
    end

    def bulk_whitelist
      bulk_action do
        @items_failed = []
        @items.each do |item|
          @items_failed << item unless whitelist_item(item)
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

      def render_201_with_location(template_name: "api_contacts/#{action_name}", location_url: 'api_contact_url', item_id: @item.id)
        render template_name, location: send(location_url, item_id), status: 201
      end

      def send_activation_mail(item)
        @contact_delegator = ContactDelegator.new(item)
        valid = @contact_delegator.valid?(:send_invite)
        item.deliver_activation_instructions!(current_portal, true) if valid && item.has_email?
        valid
      end

      def can_change_password?
        render_errors({ :password => :"Not allowed to change." }) unless @item.allow_password_update?
      end

      def validate_password_change
        params[cname].permit(:password)
        contacts_validation = ContactValidation.new(params, @item)
        return true if contacts_validation.valid?(action_name.to_sym)
        render_errors contacts_validation.errors, contacts_validation.error_options
        false
      end

      def ticket_activities
        @user_tickets = current_account.tickets.permissible(api_current_user).
          requester_active(@item).visible.newest(11).find(:all,
            include: [:ticket_states, :ticket_status, :responder, :requester])
        @user_tickets.take(10)
      end

      def archived_ticket_activities
        return [] unless current_account.features_included?(:archive_tickets)
        @user_archived_tickets = current_account.archive_tickets.permissible(api_current_user).
          requester_active(@item).newest(11).find(:all, include: [:responder, :requester])
        @user_archived_tickets.take(10)
      end

      def combined_activities
        user_activities = ticket_activities + (current_account.features?(:forums) ? @item.recent_posts : [])
        user_activities.sort_by { |item| - item.created_at.to_i }.take(10)
      end

      def whitelist_item(item)
        unless item.blocked
          item.errors.add(:blocked, 'is false. You can whitelist only blocked users.')
          return false
        end
        item.blocked = false
        item.whitelisted = true
        item.deleted = false
        item.blocked_at = nil
        item.save
      end

      wrap_parameters(*wrap_params)
  end
end
