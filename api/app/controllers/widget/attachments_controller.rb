module Widget
  class AttachmentsController < Ember::AttachmentsController
    include WidgetConcern
    include HelperConcern
    include AttachmentsValidationConcern

    skip_before_filter :check_privilege
    before_filter :set_widget_portal_as_current

    decorate_views

    def create
      return render_request_error(:contact_form_not_enabled, 400, id: @widget_id) unless @help_widget.contact_form_enabled?
      render_custom_errors unless @item.save
    end

    private

      def sanitize_params
        check_anonymous_tickets
        return if @error.present?

        validate_widget
        params[cname][:attachable_type] = AttachmentConstants::ATTACHABLE_TYPES['widget_draft']
        params[cname][:attachable_id] = @widget_id
        params[cname][:description] = @client_id
        ParamsHelper.assign_and_clean_params(AttachmentConstants::PARAMS_MAPPINGS, params)
        ParamsHelper.clean_params(AttachmentConstants::PARAMS_TO_REMOVE, params)
      end

      def validate_params
        cname_params.permit(*AttachmentConstants::WIDGET_ATTACHMENT_FIELDS)
        super
      end
  end
end
