module Proactive
  class SimpleOutreachesController < ApiApplicationController
    include ::Proactive::ProactiveJwtAuth
    include ::Proactive::Constants
    include ::Proactive::ProactiveUtil
    include ::Proactive::SimpleOutreachConcern
    include MultipleValidationConcern
    include SimpleOutreachConstants

    before_filter :access_denied, if: :email_outreach_disabled?, except: [:index, :show]
    before_filter :log_cname_params # Added since the action key will not be logged normally
    before_filter :check_proactive_feature, :generate_jwt_token
    skip_before_filter :build_object, only: [:create]
    skip_before_filter :load_object, only: [:destroy, :show, :update, :preview_email]

    def create
      return unless request_multiple_validation(fetch_validation_classes)
      return unless request_multiple_delegator_validation(DELEGATOR_CLASSES)
      service_response = make_http_call(PROACTIVE_SERVICE_ROUTES[:simple_outreaches_route], 'post')
      trigger_user_ids_update if service_response[:status] == 201
      render :create, status: service_response[:status]
    end

    def index
      request_params = ''
      request_params += "per_page=#{params[:per_page]}&" if params[:per_page].present?
      request_params += "page=#{params[:page]}&" if params[:page].present?
      route = request_params == '' ? PROACTIVE_SERVICE_ROUTES[:simple_outreaches_route] : "#{PROACTIVE_SERVICE_ROUTES[:simple_outreaches_route]}?#{request_params.chop}"
      service_response = make_http_call(route, 'get')
      response.api_meta = { next: true } if service_response[:headers].present? && service_response[:headers]['link'].present?
      render :index, status: service_response[:status]
    end

    def show
      make_rud_request('get', 'show', PROACTIVE_SERVICE_ROUTES[:simple_outreaches_route])
    end

    def update
      return unless request_multiple_validation(fetch_validation_classes)
      return unless request_multiple_delegator_validation(DELEGATOR_CLASSES)
      make_rud_request('put', 'update', PROACTIVE_SERVICE_ROUTES[:simple_outreaches_route])
    end

    def destroy
      make_rud_request('delete', 'destroy', PROACTIVE_SERVICE_ROUTES[:simple_outreaches_route])
    end

    def preview_email
      preview = NotificationPreview.new
      message = preview.notification_preview(cname_params[:email_body])
      subject = preview.notification_preview(cname_params[:subject])
      @email_body = { email_body: message, subject: subject }
      render :preview_email, status: :ok
    end

    private

      def fetch_validation_classes
        create? ? VALIDATION_CLASSES : (VALIDATION_CLASSES - ["Proactive::CustomerImportValidation"])
      end

      def trigger_user_ids_update
        create_schedule_import if csv_import?
      end

      def create_schedule_import
        @contact_import = cname_params[:selection][:contact_import]
        @import = current_account.outreach_contact_imports.create!(IMPORT_STARTED)
        @import.attachments = current_account.attachments.where(id: @contact_import[:attachment_id], attachable_type: AttachmentConstants::STANDALONE_ATTACHMENT_TYPE)
        trigger_contact_import(build_proactive_import_args)
      rescue StandardError => e
        Rails.logger.error("Error in scheduling the import for Account: #{current_account.id} User: #{current_user.id} #{e.message}")
      end

      def build_proactive_import_args
        {
          account_id: current_account.id,
          email: current_user.email,
          type: IMPORT_TYPE,
          data_import: @import.id,
          rule_id: @item['id'],
          rule_name: @item['name'],
          customers: {
            file_name: @import.attachments.first.content.original_filename,
            file_location: @import.attachments.first.content.path,
            fields: @contact_import[:fields]
          }
        }
      end

      def log_cname_params
        Rails.logger.info("Processing SimpleOutreachesController : #{action_name}")
        Rails.logger.info("Controller Parameters : #{cname_params.to_json} ")
      end

      def email_outreach_disabled?
        current_account.disable_simple_outreach_enabled?
      end
  end
end
