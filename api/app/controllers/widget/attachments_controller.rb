module Widget
  class AttachmentsController < Ember::AttachmentsController
    include WidgetConcern
    include HelperConcern
    include AttachmentsValidationConcern

    before_filter :validate_params
    before_filter :sanitize_params
    before_filter :build_object

    decorate_views

    def create
      return render_request_error(:contact_form_not_enabled, 400, id: @widget_id) unless @help_widget.contact_form_enabled?
      render_custom_errors unless @item.save
    end

    private

      def sanitize_params
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

      def auth_token_required?
        current_account.help_widget_login_enabled? && @help_widget.contact_form_require_login?
      end
  end
end
