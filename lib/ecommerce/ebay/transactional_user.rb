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
      
      external_id_user = @account.all_users.find_by_external_id(ebay_user(user_details['UserID']))
      email_user = @account.user_emails.user_for_email(user_details["Email"])
      
      if external_id_user.blank? && email_user.blank?
        user = create_user(user_details)
        tag_ecommerce_user(user, @ebay_account.name)
      elsif external_id_user.present? && email_user.blank?
        update_user(external_id_user, false,  true, user_details)
      elsif external_id_user.blank? && email_user.present?
        update_user(email_user, true, false, user_details)
      elsif external_id_user.present? && email_user.present?
        update_user(external_id_user, false,  false, user_details)
        return if external_id_user.id == email_user.id
        update_user(email_user, false, false, user_details)
      end
    end
  end

  private

  def update_user(user, update_external_id=false, update_email=false, user_details)
    shipping_address = user_details.fetch("BuyerInfo",{}).fetch("ShippingAddress",nil)
    if shipping_address.present?
      user.name = shipping_address["Name"] if user.name.blank? && shipping_address["Name"].present?
      if user.address.blank?
        user.address = "#{shipping_address['Street1']},#{shipping_address['CityName']},#{shipping_address['StateOrProvince']},#{shipping_address['CountryName']},#{shipping_address['PostalCode'] }"
      end
      user.mobile = shipping_address["Phone"] if user.mobile.blank? && shipping_address["Phone"].present?
    end
    user.email = user_details["Email"] if update_email && user.email.blank? && user_details["Email"].present?
    user.external_id = ebay_user(user_details['UserID']) if update_external_id && user.external_id.blank? && user_details['UserID'].present?
    user.active = true
    user.save!
  end

  def create_user(user_details)
    user = @account.contacts.new
    user.active = true
    params = { :user => { :name => user_details['UserID'], :external_id => ebay_user(user_details['UserID']) }}
    params[:user][:email] = user_details["Email"] if user_details["Email"].present?
    shipping_address = user_details.fetch("BuyerInfo",{}).fetch("ShippingAddress",nil)
    if shipping_address.present?
      params[:user][:name] = shipping_address["Name"] if shipping_address["Name"].present?
      params[:user][:address] = "#{shipping_address['Street1']},#{shipping_address['CityName']},#{shipping_address['StateOrProvince']},#{shipping_address['CountryName']},#{shipping_address['PostalCode'] }"
      params[:user][:mobile] = shipping_address["Phone"] if shipping_address["Phone"].present?
    end
    user.signup!(params, nil, false)
    user
  end

end