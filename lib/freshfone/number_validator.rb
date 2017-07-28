module Freshfone::NumberValidator
  extend ActiveSupport::Concern

  def fetch_country_code(number)
    return unless number.starts_with?('+')
    begin
      response = lookup_client.phone_numbers.get(number)
      response.country_code
    rescue Exception => e
      return if e.code == 20404
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
