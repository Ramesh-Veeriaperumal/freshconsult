class AccountAdminsController < ApiApplicationController
  before_filter :load_object
  before_filter :validate_params, only: [:update]

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

  private

  def validate_params
    account_admin_validation = AccountAdminValidation.new(params[cname], nil, true)
    if account_admin_validation.invalid?
      render_errors(account_admin_validation.errors, account_admin_validation.error_options)
    end
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
