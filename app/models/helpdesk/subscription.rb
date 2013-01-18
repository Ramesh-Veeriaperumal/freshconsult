class Helpdesk::Subscription < ActiveRecord::Base
  set_table_name "helpdesk_subscriptions"

  belongs_to_account
  belongs_to :ticket,
    :class_name => 'Helpdesk::Ticket'

  belongs_to :user,
    :class_name => 'User'
    
  attr_protected :ticket_id, :account_id

  validates_uniqueness_of :ticket_id, :scope => :user_id
  validates_numericality_of :ticket_id, :user_id
  before_create :set_account_id

  private
    def set_account_id
      self.account_id = ticket.account_id
    end
end
