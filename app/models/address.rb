class Address < ActiveRecord::Base
  
  belongs_to :addressable, :polymorphic => true
  
  belongs_to :account
  
  validates_presence_of :state, :zip, :first_name, :last_name,:address1, :city, :country
  
  def humanize
    "#{first_name} #{last_name} \n#{address1} #{address2} \n#{state} #{city} \n#{country} #{zip}"
  end
  
  
  def self.required_fields
    [:state, :zip, :first_name, :last_name,:address1, :city, :country]
  end
end