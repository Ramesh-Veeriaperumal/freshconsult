module AccountAdminTestHelper
  include Redis::HashMethods
  def account_admin_response(params)
    response = {
      first_name: params[:first_name],
      last_name: params[:last_name],
      email: params[:email],
      phone: params[:phone]
    }
    response.merge!(company_name: params[:company_name]) if params[:company_name]
    response.merge!(invoice_emails: params[:invoice_emails]) if params[:invoice_emails]
  end

  def account_admin_bad_request_error_patterns(field, error_message, params = {})
    {
      description: 'Validation failed',
      errors: [
        {
          field: field.to_s,
          message: error_message,
          code: params[:code] || ErrorConstants::API_ERROR_CODES_BY_VALUE[params[:value]] || ErrorConstants::DEFAULT_CUSTOM_CODE
        }
      ]
    }
  end

  def preferences_response(params)
    response = {
      skip_mandatory_checks: params[:skip_mandatory_checks]
    }
  end

  def restricted_preferences_response(redis_hash, params)
    preferences = redis_hash
    preferences[:agent_availability_refresh_time] = params[:agent_availability_refresh_time] if params[:agent_availability_refresh_time].present?
    preferences
  end
end
