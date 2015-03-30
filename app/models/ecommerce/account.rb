class Ecommerce::Account < ActiveRecord::Base

  self.table_name = :ecommerce_accounts
  serialize :configs, Hash
  attr_protected :account_id
  belongs_to_account
    
  belongs_to :email_config

  validates :email_config_id, :uniqueness => { :scope => :account_id }

  accepts_nested_attributes_for :email_config

  def inactive?
    !active
  end

end