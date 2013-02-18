class Helpdesk::TimeSheet < ActiveRecord::Base

  include Va::ObserverUtil

  set_table_name "helpdesk_time_sheets"
  belongs_to :ticket , :class_name =>'Helpdesk::Ticket', :foreign_key =>'ticket_id'
  belongs_to :user
  
  before_validation :set_default_values 

  after_create :create_new_activity
  after_update :update_timer_activity , :if => :timer_running_changed?
  before_save :update_observer_events
  after_commit :filter_observer_events, :if => :current_user?

  has_many :integrated_resources, 
    :class_name => 'Integrations::IntegratedResource',
    :as => 'local_integratable',
    :dependent => :destroy
    
  named_scope :timer_active , :conditions =>["timer_running=?" , true]

  named_scope :created_at_inside, lambda { |start, stop|
          { :conditions => [" helpdesk_time_sheets.executed_at >= ? and helpdesk_time_sheets.executed_at <= ?", start, stop] }
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
      
  named_scope :for_contacts, lambda{|contact_email|
      {
        :include =>{:ticket =>:requester},
        :conditions =>{:users => {:email => contact_email}},
      } unless contact_email.blank?}
    
  BILLABLE_HASH = { "Billable" => true, "Non-Billable" => false}
  GROUP_BY_ARR = [["Customer" , :customer_name] , ["Ticket",:ticket] , ["Agent" , :agent_name] , ["Date" , :group_by_day_criteria]]
  REPORT_LIST_VIEW = {:ticket => I18n.t('helpdesk.time_sheets.ticket') , :customer_name => I18n.t('helpdesk.time_sheets.customer') , 
                      :agent_name =>  I18n.t('helpdesk.time_sheets.agent') , :note =>  I18n.t('helpdesk.time_sheets.note') ,
                       :group_by_day_criteria =>I18n.t('helpdesk.time_sheets.executed_at') , :hours => I18n.t('helpdesk.time_sheets.hours')}

  def hours 
    seconds = time_spent
    sprintf( "%0.02f", seconds/3600)
  end

  def running_time
    p "running time"
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
  
  def stop_timer
    p "stop timer"
     self.timer_running=false
     self.time_spent = calculate_time_spent
     self.save
  end

   def to_json(options = {}, deep=true)
    if deep
      self[:ticket_id] = self.ticket.display_id
      self[:agent_name] = self.agent_name
      self[:time_spent] = sprintf( "%0.02f", self.time_spent/3600) # converting to hours as in UI
      self[:agent_email] = user.email
      self[:customer_name] = self.customer_name
      self[:contact_email] = ticket.requester.email
      options[:except] = [:account_id,:ticket_id,:time_spent]
      options[:root] =:time_entry
    end
    json_str = super options
    json_str
  end

  def to_xml(options = {})
    options[:indent] ||= 2
    xml = options[:builder] ||= Builder::XmlMarkup.new(:indent => options[:indent])
    xml.instruct! unless options[:skip_instruct]
    super(:builder => xml, :skip_instruct => true,:dasherize=>false,:except => [:account_id,:ticket_id,:time_spent],:root=>:time_entry) do |xml|
      xml.tag!(:ticket_id,ticket.display_id)
      xml.tag!(:agent_name,agent_name)
      xml.tag!(:time_spent,sprintf( "%0.02f", self.time_spent/3600)) # converting to hours as in UI
      xml.tag!(:agent_email,user.email) 
      xml.tag!(:customer_name,self.customer_name)
      xml.tag!(:contact_email,ticket.requester.email)
    end
  end
  
  private
  
   def calculate_time_spent
    p "calculate time spent"
    to_time = Time.zone.now.to_time
    from_time = start_time.to_time 
    running_time =  ((to_time - from_time).abs).round 
    return (time_spent + running_time)
   end

  def update_timer_activity
     p "update_activity"
      if timer_running
         ticket.create_activity(User.current, 'activities.tickets.timesheet.timer_started.long', 
          {'eval_args' => {'timesheet_path' => ['timesheet_path', 
                                {'ticket_id' => ticket.display_id, 'timesheet_id' => id}]}},
                                'activities.tickets.timesheet.timer_started.short')
        
      else
        ticket.create_activity(User.current, 'activities.tickets.timesheet.timer_stopped.long', 
          {'eval_args' => {'timesheet_path' => ['timesheet_path', 
                                {'ticket_id' => ticket.display_id, 'timesheet_id' => id}]}},
                                'activities.tickets.timesheet.timer_stopped.short')
      end
  end
  
  def create_new_activity
    p "create_activity"
      ticket.create_activity(User.current, 'activities.tickets.timesheet.new.long', 
          {'eval_args' => {'timesheet_path' => ['timesheet_path', 
                                {'ticket_id' => ticket.display_id, 'timesheet_id' => id}]}},
                                'activities.tickets.timesheet.new.short')
 end

  def set_default_values
    self.executed_at ||= self.created_at
  end

  # VA - Observer Rule 

  def update_observer_events
    from, to = time_spent_change    # Should find another way - Hari
    if from == nil
      unless to == 0
        @observer_changes = {:time_sheet => :added} 
      end
    elsif from == 0
      @observer_changes = {:time_sheet => :added}
    else
      @observer_changes = {:time_sheet => :updated}
    end unless time_spent_change.nil?
  end
  
end
