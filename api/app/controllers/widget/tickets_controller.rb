module Widget
  # Inherits the workflow of ticket create from api tickets_controller
  class TicketsController < ::TicketsController
    include WidgetConcern
    include Recaptcha::Verify
    include Helpdesk::Permission::Ticket

    skip_before_filter :check_privilege
    before_filter :check_feature
    before_filter :check_ticket_permission, only: :create
    before_filter :set_widget_portal_as_current
    before_filter :check_recaptcha, unless: :predictive_ticket?
    before_filter :validate_attachment_ids, if: :attachment_ids?

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
        @attachment_ids = cname_params.delete(:attachment_ids)
        validate_widget
        return if @error.present?
        return render_request_error(:ticket_creation_not_allowed, 400, id: @widget_id) unless @help_widget.ticket_creation_enabled?
        super
      end

      def attachment_ids?
        @attachment_ids.present?
      end

      def validate_attachment_ids
        @delegator_klass = 'WidgetAttachmentDelegator'
        validate_delegator(@item,
                            attachment_ids: @attachment_ids,
                            widget_id: @widget_id,
                            widget_client_id: @client_id)
      end

      def remove_ignore_params
        @meta = params[cname][:meta]
        @predictive = params[cname][:predictive]
        params[cname].except!(*constants_class::PARAMS_TO_REMOVE)
        super
      end

      def get_additional_params
        additional_params = {}
        additional_params[:is_ticket_fields_form] = @help_widget.ticket_fields_form?
        additional_params[:is_predictive] = predictive_ticket?
        additional_params
      end

      def set_default_values
        super
        params[cname][:product_id] = @help_widget.product_id unless params[cname].key?(:product_id)
        params[cname][:source] = TicketConstants::SOURCE_KEYS_BY_TOKEN[:feedback_widget]
      end

      def check_recaptcha
        verified = @help_widget.captcha_enabled? ? verify_recaptcha : true
        render_request_error(:access_restricted, 403) unless verified
      end

      def assign_protected
        super
        @item.meta_data ||= {}
        constants_class::META_KEY_MAP.keys.each do |meta_key|
          @item.meta_data[meta_key] = (@meta && @meta[meta_key]) || request.env[constants_class::META_KEY_MAP[meta_key]]
        end
        add_attachments
      end

      def predictive_ticket?
        @predictive && @help_widget.predictive?
      end
  end
end
