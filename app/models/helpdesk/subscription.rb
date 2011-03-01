class Helpdesk::Subscription < ActiveRecord::Base
  set_table_name "helpdesk_subscriptions"

  belongs_to :ticket,
    :class_name => 'Helpdesk::Ticket'

  belongs_to :user,
    :class_name => 'User'
    
  attr_protected :ticket_id, :user_id

  validates_uniqueness_of :ticket_id, :scope => :user_id
  validates_numericality_of :ticket_id, :user_id
end
