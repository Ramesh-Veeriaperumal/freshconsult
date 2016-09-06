module Ember
  class TicketsController < ::TicketsController
    before_filter :ticket_permission?, only: [:spam]
    INDEX_PRELOAD_OPTIONS = [:ticket_old_body, :schema_less_ticket, :flexifield, { requester: [:avatar, :flexifield, :default_user_company] }].freeze

    def index
      super
      response.api_meta = { count: tickets_filter.count }
      # TODO-EMBERAPI Optimize the way we fetch the count
    end

    def spam
      @item.spam = true
      store_dirty_tags(@item)
      @item.save
      head 204
    end

    private

      def decorate_objects
        return if @error_ticket_filter.present?
        decorator, options = decorator_options
        @requester_collection = @items.collect(&:requester).uniq
        @requesters = @requester_collection.map { |contact| ContactDecorator.new(contact, name_mapping: contact_name_mapping) }

        @items.map! { |item| decorator.new(item, options) }
      end

      def contact_name_mapping
        # will be called only for index and show.
        # We want to avoid memcache call to get custom_field keys and hence following below approach.
        custom_field = index? ? @requester_collection.first.try(:custom_field) : @requester.custom_field
        custom_field.each_with_object({}) { |(name, value), hash| hash[name] = CustomFieldDecorator.display_name(name) } if custom_field
      end

      def tickets_filter
        return if @error_ticket_filter.present?
        current_account.tickets.permissible(api_current_user).filter(params: params, filter: 'Helpdesk::Filters::CustomTicketFilter')
      end

      def validate_filter_params
        # This is a temp filter validation.
        # Basically overriding validation and fetching any filter available
        # This is going to handle Default ticket filters and custom ticket filters.
        # ?email=** or ?requester_id=*** are NOT going to be supported as of now.
        # Has to be taken up post sprint while cleaning this up and writing a proper validator for this
        params.permit(*ApiTicketConstants::INDEX_FIELDS, *ApiConstants::DEFAULT_INDEX_FIELDS)

        if params[:filter].to_i.to_s == params[:filter] # Which means it is a string
          @ticket_filter = current_account.ticket_filters.find_by_id(params[:filter])
          if @ticket_filter.nil? || !@ticket_filter.has_permission?(api_current_user)
            render_filter_errors
          else
            params.merge!(@ticket_filter.attributes['data'])
          end
        elsif !Helpdesk::Filters::CustomTicketFilter::DEFAULT_FILTERS.keys.include?(params[:filter])
          render_filter_errors
        else
          @ticket_filter = current_account.ticket_filters.new(Helpdesk::Filters::CustomTicketFilter::MODEL_NAME).default_filter(params[:filter])
        end
      end

      def render_filter_errors
        # This is just force filter errors
        # Always expected to render errors
        @error_ticket_filter = ::TicketFilterValidation.new(params, nil, string_request_params?)
        render_errors(@error_ticket_filter.errors, @error_ticket_filter.error_options) unless @error_ticket_filter.valid?
      end

      def conditional_preload_options
        INDEX_PRELOAD_OPTIONS
      end

      def sideload_options
        [:requester, :stats]
      end
  end
end
