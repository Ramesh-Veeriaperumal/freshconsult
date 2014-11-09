class Helpdesk::TicketIssue < ActiveRecord::Base
  self.table_name =  "helpdesk_ticket_issues"
  self.primary_key = :id

  belongs_to :issue, 
    :class_name => 'Helpdesk::Issue',
    :foreign_key => 'issue_id',
    :counter_cache => true

  belongs_to :ticket, 
    :class_name => 'Helpdesk::Ticket',
    :foreign_key => 'ticket_id'

  validates_uniqueness_of :issue_id, :scope => :ticket_id
  validates_numericality_of :issue_id, :ticket_id

end
