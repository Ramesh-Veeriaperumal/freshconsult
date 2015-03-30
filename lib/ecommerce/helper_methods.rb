module Ecommerce::HelperMethods
  include Ecommerce::Ebay::Util
  include Ecommerce::Constants
  include ParserUtil

  def ebay_user?(email)
    return true if parse_email_with_domain(email)[:domain] =~ /\Amembers.ebay\.[a-z]*(\.[a-z]*)?\z/
  end

  def active_ecommerce_account(to_email)
    Account.current.email_configs.find_by_to_email(to_email).ecommerce_account.present?
  end

  def ecommerce?(from_email, to_email)
    @is_ecommerce_ticket = (Account.current.features?(:ecommerce) and ebay_user?(from_email) and active_ecommerce_account(to_email))
  end

end 