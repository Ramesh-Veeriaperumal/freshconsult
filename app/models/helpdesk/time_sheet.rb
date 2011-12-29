class Helpdesk::TimeSheet < ActiveRecord::Base
  set_table_name "helpdesk_time_sheets"
  belongs_to :ticket , :class_name =>'Helpdesk::Ticket', :foreign_key =>'ticket_id'
  belongs_to :user

  def hours
   [time_spent.to_i.div(60*60), (time_spent.to_i.div(60) % 60)*(1.667).round].map{ |t| t.to_s.rjust(2, '0') }.join(".")
  end
  
end
