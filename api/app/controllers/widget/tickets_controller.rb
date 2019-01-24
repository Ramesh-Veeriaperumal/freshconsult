module Widget
  # Inherits the workflow of ticket create from api tickets_controller
  class TicketsController < ::TicketsController
    include WidgetConcern
    include Recaptcha::Verify
    include Helpdesk::Permission::Ticket

    skip_before_filter :check_privilege
    before_filter :check_ticket_permission, only: :create
    before_filter :set_widget_portal_as_current
    before_filter :check_recaptcha

    private

      def validation_class
        Widget::TicketValidation
      end

      def constants_class
        Widget::TicketConstants
      end

      def render_201_with_location(item_id: @item.id)
        render 'widget/tickets/create', status: 201
      end

      def check_ticket_permission
        if api_current_user.nil? || (api_current_user && api_current_user.customer?)
          render_request_error :invalid_requester, 400 unless can_create_ticket?(params[cname][:email])
        end
      end

      def validate_params
        validate_widget
        return if @error.present?
        super
      end

      def get_additional_params
        additional_params = {}
        additional_params[:is_ticket_fields_form] = @help_widget.ticket_fields_form?
        additional_params
      end

      def set_default_values
        super
        params[cname].delete("g-recaptcha-response") #remove recaptcha parameter
        params[cname][:product_id] = @help_widget.product_id unless params[cname].key?(:product_id)
        params[cname][:source] = TicketConstants::SOURCE_KEYS_BY_TOKEN[:feedback_widget]
      end

      def check_recaptcha
        verified = @help_widget.captcha_enabled? ? verify_recaptcha : true
        render_request_error(:access_restricted, 403) unless verified
      end

      def assign_protected
        super
        meta_info = { "widget_source" => @help_widget.id }
        meta_info.merge!(request.headers.slice(*Widget::TicketConstants::META_INFORMATION)) if params[cname][:meta].present?
        (@item.meta_data ||= {}).merge!(meta_info)
      end
  end
end
