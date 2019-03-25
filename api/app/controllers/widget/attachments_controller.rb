module Widget
  class AttachmentsController < Ember::AttachmentsController
    include WidgetConcern
    include HelperConcern
    include AttachmentsValidationConcern

    skip_before_filter :check_privilege
    before_filter :check_feature
    before_filter :validate_widget
    before_filter :set_widget_portal_as_current

    decorate_views

    def create
      return render_request_error(:contact_form_not_enabled, 400, id: @widget_id) unless @help_widget.contact_form_enabled?
      render_custom_errors unless @item.save
    end

    private

      def sanitize_params
        params[cname][:attachable_type] = AttachmentConstants::ATTACHABLE_TYPES['user_draft']
        params[cname][:attachable_id] = current_account.id
        params[cname][:description] = 'fresh_widget'
        ParamsHelper.assign_and_clean_params(AttachmentConstants::PARAMS_MAPPINGS, params[cname])
        ParamsHelper.clean_params(AttachmentConstants::PARAMS_TO_REMOVE, params[cname])
      end

      def validate_params
        cname_params.permit(*AttachmentConstants::WIDGET_ATTACHMENT_FIELDS)
        super
      end
  end
end
