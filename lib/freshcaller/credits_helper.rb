module Freshcaller::CreditsHelper
  def fetch_freshcaller_credit_info
    response = freshcaller_request({},
                                   "#{protocol}#{current_account.freshcaller_account.domain}/credits",
                                   :get).parsed_response
    response.key?('data') ? credit_info_hash(response['data']['attributes']) : nil
  end

  def credit_info_hash(data_attributes)
    currency = Subscription::Currencies::Constants::CURRENCY_UNITS[current_account.currency_name]
    { phone_credits: data_attributes['available-credit'],
      recharge_quantity: data_attributes['recharge-quantity'],
      auto_recharge: data_attributes['auto-recharge'],
      currency_name: currency,
      freshcaller_domain: current_account.freshcaller_account.domain }
  end

  def protocol
    Rails.env.development? ? 'http://' : 'https://'
  end
end
