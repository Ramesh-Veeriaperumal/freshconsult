class Helpdesk::TimeSheet < ActiveRecord::Base
  set_table_name "helpdesk_time_sheets"
  belongs_to :ticket , :class_name =>'Helpdesk::Ticket', :foreign_key =>'ticket_id'
  belongs_to :user
  
  has_many :integrated_resources, 
    :class_name => 'Integrations::IntegratedResource',
    :as => 'local_integratable',
    :dependent => :destroy

  named_scope :created_at_inside, lambda { |start, stop|
          { :conditions => [" helpdesk_time_sheets.start_time >= ? and helpdesk_time_sheets.start_time <= ?", start, stop] }
        }
  named_scope :hour_billable , lambda {|hr_billable| {:conditions =>{:billable => hr_billable} } }
        
  named_scope :by_agent , lambda { |created_by|
                                    { :conditions => {:user_id => created_by } } unless created_by.blank?
                                  }
  
  named_scope :for_customers, lambda{ |customers|
      {
        :joins    => {:ticket =>:requester},
        :conditions => {:users => {:customer_id => customers}},
        :select     => "DISTINCT `helpdesk_time_sheets`.*"
      } unless customers.blank?}
      
  BILLABLE_HASH = { true =>"Billable", false => "Non-Billable"}

  def hours
   hour_val = time_spent.div(60*60)
   remaining_sec = time_spent - (60 * 60 *hour_val)
   [hour_val,  remaining_sec * ((100/3600).to_f)].map{ |t| t.round.to_s }.join(".")
  end
  
  def agent_name
    user.name
  end
  
  def ticket_display
    "#{ticket.display_id} - #{ticket.subject}"
  end
  
  def group_by_day_criteria
    created_at.to_date.to_s(:db)
  end
  
end
