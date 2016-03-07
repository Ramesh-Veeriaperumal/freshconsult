class OutgoingEmailDomainCategory < ActiveRecord::Base
  belongs_to_account

  validates_uniqueness_of :email_domain, :scope => :account_id

  scope :active, :conditions => { :enabled => true }
end
