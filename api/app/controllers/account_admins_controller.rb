class AccountAdminsController < ApiApplicationController
  before_filter :load_object
  before_filter :validate_params, only: [:update, :preferences=]

  def load_object
    @item = current_account.account_configuration
  end

  def update
    set_invoice_emails
    super
    current_account.rollback(:update_billing_info)
  end

  def disable_billing_info_updation
    current_account.rollback(:update_billing_info)
    head 204
  end

  def preferences
    @preferences = current_account.account_additional_settings.additional_settings
    response.api_root_key = :preferences
  end

  def preferences=
    if params.key? :skip_mandatory_checks
      if params[:skip_mandatory_checks]
        current_account.account_additional_settings.enable_skip_mandatory
      else
        current_account.account_additional_settings.disable_skip_mandatory
      end
    end
    head 204
  end

  private

  def validate_params
    account_admin_validation = AccountAdminValidation.new(params[cname], nil, true)
    render_errors(account_admin_validation.errors, account_admin_validation.error_options) if account_admin_validation.invalid?(params[:action].to_sym)
  end

  def sanitize_params
    params[cname].permit(*AccountAdminConstants::PERMITTED_PARAMS)
  end

  def set_invoice_emails
    return unless params[cname][:invoice_emails]

    params[cname][:billing_emails] = @item.billing_emails || {}
    params[cname][:billing_emails][:invoice_emails] = params[cname].delete(:invoice_emails)
  end
end
