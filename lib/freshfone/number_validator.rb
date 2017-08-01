module Freshfone::NumberValidator
  extend ActiveSupport::Concern

  TWILIO_ERROR_CODES = {
    not_found: 20404,
    address_invalid: 21628,
    address_suggested: 21629
  }.freeze

  def fetch_country_code(number)
    return unless number.starts_with?('+')
    begin
      response = lookup_client.phone_numbers.get(number)
      response.country_code
    rescue Exception => e
      return if e.code == TWILIO_ERROR_CODES[:not_found]
      Rails.logger.error "Number Lookup Error. Message::#{e.message}"
      country_from_telephone(number)
    end
  end

  def lookup_client
    Account.current.freshfone_account.lookup_client
  end

  def country_from_telephone(number)
    phone_object = TelephoneNumber.parse(number)
    phone_object.phone_data.country_data[:id] if phone_object.valid?
  end
end
