class SubscriptionAddress
  include ActiveMerchant::Validateable
  
  attr_accessor :address1, :address2, :city, :state, :zip, :country, :first_name, :last_name, :phone
  
  def to_activemerchant
    [:address1, :address2, :city, :state, :zip, :country, :first_name, :last_name, :phone].inject({}) do |h, field|
      h[field] = self.send(field)
      h
    end
  end
  
  def validate
    [ :state, :zip, :first_name, :last_name,:address1, :city, :country].each do |field|
      errors.add field, "cannot be blank" if self.send(field).blank?
    end
  end
end