module Aloha::Validations
  include Aloha::Constants

  def seeder_product_validations
    response = {}
    render json: response, status: 500 and return unless validate_bundle_details(response) && validate_seeder_account_details(response) &&  validate_organisation_details(response)
  end

  def validate_bundle_details(response)
    bundle_id = params['bundle_id']
    bundle_name = params['bundle_name']
    account_bundle_info = { bundle_id: @current_account.omni_bundle_id, bundle_name: @current_account.omni_bundle_name }
    if bundle_id.to_s != account_bundle_info[:bundle_id].to_s || bundle_name != account_bundle_info[:bundle_name]
      response[:message] = BUNDLE_DATA_MISMATCH
      bundle_validation_error_logs BUNDLE_DATA_MISMATCH_CODE
    end
    response[:message].nil?
  end

  def validate_seeder_account_details(response)
    table_name = "#{params['product_name'].downcase}_account"
    account_details = params['account']
    if SEEDER_PRODUCTS_ALLOWED.exclude? params['product_name']
      if params['product_name'].include? "freshchat"
        params['product_name'] = "freshchat"
      else
        response[:message] = INVALID_SEEDER_PRODUCT
        bundle_validation_error_logs INVALID_SEEDER_PRODUCT_CODE
      end
    elsif current_account.safe_send(table_name).present?
      response[:message] = "#{params['product_name']} entry is already present for this freshdesk account"
      bundle_validation_error_logs ENTRY_ALREADY_EXISTS_CODE
    elsif account_details.blank?
      response[:message] = "#{params['product_name']} account details value is missing"
      bundle_validation_error_logs ACCOUNT_DETAILS_MISSING_CODE
    elsif account_details.present? && account_details['domain'].nil?
      bundle_validation_error_logs ACCOUNT_DOMAIN_MISSING_CODE
      response[:message] = "#{params['product_name']} account domain is missing"
    end
    response[:message].nil?
  end

  def validate_organisation_details(response)
    organisation_id = params['organisation']['id']
    if organisation_id != current_account.organisation.try(:organisation_id).to_s
      response[:message] = ORG_ID_MISMATCH
      bundle_validation_error_logs ORG_ID_MISMATCH_CODE
    end
    response[:message].nil?
  end

  def bundle_validation_error_logs(errorcode)
    Rails.logger.info "Aloha - Bundle Linking API error - #{errorcode} :: #{@current_account.id} :: #{@current_account.omni_bundle_id}"
  end
end
