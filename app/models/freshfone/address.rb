class Freshfone::Address < ActiveRecord::Base
  self.table_name = "freshfone_number_addresses"
  belongs_to_account
  belongs_to :freshfone_account, :class_name => "Freshfone::Account"
  before_create :create_address_in_twilio
  validates_presence_of :business_name, :address, :city, :state, :postal_code, :country

  def create_address_in_twilio
    begin
      @address = freshfone_account.freshfone_subaccount.addresses.create(
        :friendly_name => self.business_name,
        :customer_name => self.business_name,
        :street => self.address,
        :city => self.city,
        :region => self.state,
        :postal_code => self.postal_code,
        :iso_country => self.country
      )
      self.address_sid = @address.sid
    rescue Exception => e
      Rails.logger.error "Address creation failed in twilio for #{account.id} \n#{e.message}\n#{e.backtrace.join("\n\t")}"
      return false
    end
  end

end