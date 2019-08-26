class Notifications::Email::BccController < ApiApplicationController
  include HelperConcern
  decorate_views

  private

    def load_object
      @item = current_account.account_additional_settings
    end

    def validate_params
      validate_body_params
    end

    def sanitize_params
      bcc_email_string = cname_params[:emails].map(&:downcase).uniq.reject(&:blank?).join(',')
      cname_params.delete(:emails)
      cname_params[:bcc_email] = bcc_email_string
    end

    def constants_class
      Notifications::Email::BccConstants.to_s.freeze
    end

    def set_custom_errors(item = @item)
      ErrorHelper.rename_error_fields(Notifications::Email::BccConstants::FIELD_MAPPING, item)
    end
end
