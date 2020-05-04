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
    response[:message] = BUNDLE_DATA_MISMATCH if bundle_id.to_s != account_bundle_info[:bundle_id].to_s || bundle_name != account_bundle_info[:bundle_name]
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
      end
    elsif current_account.safe_send(table_name).present?
      response[:message] = "#{params['product_name']} entry already present for this freshdesk account"
    elsif account_details.blank?
      response[:message] = "#{params['product_name']} account details is not given"
    elsif account_details.present? && account_details['domain'].nil?
      response[:message] = "#{params['product_name']} account domain is not given"
    end
    response[:message].nil?
  end

  def validate_organisation_details(response)
    organisation_id = params['organisation']['id']
    response[:message] = ORG_ID_MISMATCH if organisation_id != current_account.organisation.try(:organisation_id).to_s
    response[:message].nil?
  end
end
