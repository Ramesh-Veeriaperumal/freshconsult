class AccountAdminsController < ApiApplicationController
  before_filter :load_object
  before_filter :validate_params, only: [:update]

  def load_object
    @item = current_account.account_configuration
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
end
