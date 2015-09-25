class Ecommerce::Ebay::TransactionalUser

  include Ecommerce::Ebay::Util

  def initialize(args)
    @account = ::Account.current
    @ebay_account = @account.ebay_accounts.find_by_external_account_id(args["body"]["EIASToken"])
    @transaction_array = Array.wrap(args["body"]["TransactionArray"])
  end

  def update_user_details
    @transaction_array.each do |obj|
      next if  obj.fetch("Transaction",{}).fetch("Buyer",{}).fetch("UserID",nil).blank?
      user_details = obj["Transaction"]["Buyer"]
      user = @account.all_users.find_by_external_id(ebay_user(user_details['UserID']))

      if user.blank?
        user = @account.contacts.new
        user.active = true
        user.signup!({ :user => { :name => user_details['UserID'], :external_id => ebay_user(user_details['UserID']) }}, nil, false)
        tag_ecommerce_user(user, @ebay_account.name)
      end

      user.email = user_details["Email"] if user.email.blank? && user_details["Email"].present?
      shipping_address = user_details.fetch("BuyerInfo",{}).fetch("ShippingAddress",nil)

      if shipping_address.present?
        user.name = shipping_address["Name"] if shipping_address["Name"].present?
        user.address = "#{shipping_address['Street1']},#{shipping_address['CityName']},#{shipping_address['StateOrProvince']},#{shipping_address['CountryName']},#{shipping_address['PostalCode'] }"
        user.mobile = shipping_address["Phone"] if user.mobile.blank? and  shipping_address["Phone"].present?
      end

      user.save

    end
  end


end