class StatusGroup < ActiveRecord::Base
  self.primary_key = :id
  
  belongs_to_account

  belongs_to :status, :class_name =>'Helpdesk::TicketStatus', :foreign_key => :status_id
end