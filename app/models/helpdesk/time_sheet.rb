class Helpdesk::TimeSheet < ActiveRecord::Base
  set_table_name "helpdesk_time_sheets"
  belongs_to :ticket , :class_name =>'Helpdesk::Ticket',:foreign_key =>'ticket_id'
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
  
  def hours_spent
    hours = time_spent.div(60*60)
    minutes_as_percent = (time_spent.div(60) % 60)*(1.667).round
    hour_time = hours.to_s()+"."+ minutes_as_percent.to_s()
    hour_time
  end
  
  def agent_name
    user.name
  end
  
  def ticket_display
    "#{ticket.display_id} - #{ticket.subject}"
  end
  
end
