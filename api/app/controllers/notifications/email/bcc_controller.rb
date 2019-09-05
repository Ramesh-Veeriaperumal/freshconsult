class Notifications::Email::BccController < ApiApplicationController
  include HelperConcern
  include BccConcern
  decorate_views

  private

    def load_object
      @item = current_account.account_additional_settings
    end

    def validate_params
      validate_body_params
    end

    def sanitize_params
      cname_params[:bcc_email] = build_bcc_params(cname_params.delete(:emails))
    end

    def constants_class
      Notifications::Email::BccConstants.to_s.freeze
    end

    def set_custom_errors(item = @item)
      ErrorHelper.rename_error_fields(Notifications::Email::BccConstants::FIELD_MAPPING, item)
    end
end
