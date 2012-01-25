
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
  GROUP_BY_ARR = [["Ticket",:ticket], ["Customer" , :customer_name] , ["Agent" , :agent_name] , ["Executed Date" , :group_by_day_criteria]]
  REPORT_LIST_VIEW = {:ticket => I18n.t('helpdesk.time_sheets.ticket') , :customer_name => I18n.t('helpdesk.time_sheets.customer') , 
                      :agent_name =>  I18n.t('helpdesk.time_sheets.agent') , :note =>  I18n.t('helpdesk.time_sheets.note') ,
                       :group_by_day_criteria =>I18n.t('helpdesk.time_sheets.executed_at') , :hours => I18n.t('helpdesk.time_sheets.hours')}

  def hours 
    seconds = time_spent
    sprintf( "%0.02f", seconds/3600)
  end

  def running_time
    total_time = time_spent
    if timer_running
      from_time = start_time
      to_time = Time.zone.now
      from_time = from_time.to_time if from_time.respond_to?(:to_time)
      to_time = to_time.to_time if to_time.respond_to?(:to_time)
      total_time += ((to_time - from_time).abs).round 
    end  
    total_time
  end

  def agent_name
    user.name
  end
  
  def ticket_display
    "#{ticket.display_id} - #{ticket.subject}"
  end
  
  def customer_name
    ticket.requester.customer ? ticket.requester.customer.name : ticket.requester.name
  end
  
  def group_by_day_criteria
    executed_at.to_date.to_s(:db)
  end
  
end
