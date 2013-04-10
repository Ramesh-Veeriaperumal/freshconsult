class Helpdesk::TimeSheet < ActiveRecord::Base
  set_table_name "helpdesk_time_sheets"
  
  belongs_to :workable, :polymorphic => true
  delegate :product_name, :group_name, :to => :workable

  belongs_to :user
  belongs_to_account
  
  before_validation :set_default_values 

  after_create :create_new_activity
  after_update :update_timer_activity , :if  => :timer_running_changed?
  
  has_many :integrated_resources, 
    :class_name => 'Integrations::IntegratedResource',
    :as => 'local_integratable',
    :dependent => :destroy
    
  named_scope :timer_active , :conditions =>["timer_running=?" , true]

  named_scope :created_at_inside, lambda { |start, stop|
    { :conditions => 
      [" helpdesk_time_sheets.executed_at >= ? and helpdesk_time_sheets.executed_at <= ?", 
        start, stop] 
    }
  }
  named_scope :hour_billable , lambda {|hr_billable| {:conditions =>{:billable => hr_billable} } }
        
  named_scope :by_agent , lambda { |created_by|
    { :conditions => {:user_id => created_by } } unless created_by.blank?
  }
  
  named_scope :by_group , lambda  { |group|
      { :conditions => { :helpdesk_tickets => { :group_id => group } } } unless group.blank?
  }

  named_scope :for_customers, lambda{ |customers|
    {
      :select     => "DISTINCT `helpdesk_time_sheets`.*" ,
      :joins => ["INNER JOIN `helpdesk_tickets` ON `helpdesk_time_sheets`.workable_id = `helpdesk_tickets`.id AND `helpdesk_time_sheets`.workable_type = 'Helpdesk::Ticket'" , 
                "INNER JOIN `users` ON `helpdesk_tickets`.requester_id = `users`.id"],
      :conditions => {:users => {:customer_id => customers}}
    } unless customers.blank?
  }
      
  named_scope :for_contacts, lambda{|contact_email|
      {
        :include =>{:workable =>:requester},
        :conditions =>{:users => {:email => contact_email}},
      } unless contact_email.blank?
  }

  def self.billable_options
    { I18n.t('helpdesk.time_sheets.billable') => true, 
      I18n.t('helpdesk.time_sheets.non_billable') => false}
  end

  def self.group_by_options
    [ [I18n.t('helpdesk.time_sheets.customer') , :customer_name], 
      [I18n.t('helpdesk.time_sheets.ticket') , :workable], 
      [I18n.t('helpdesk.time_sheets.agent') , :agent_name], 
      [I18n.t('helpdesk.time_sheets.executed_at') , :group_by_day_criteria],
      [I18n.t('helpdesk.time_sheets.product') , :product_name], 
      [I18n.t('helpdesk.time_sheets.group') , :group_name] ]
  end                                                                                                                                               

  def self.report_list
    { :ticket => I18n.t('helpdesk.time_sheets.ticket'),
      :customer_name => I18n.t('helpdesk.time_sheets.customer'), 
      :agent_name =>  I18n.t('helpdesk.time_sheets.agent'), 
      :note =>  I18n.t('helpdesk.time_sheets.note'),
      :group_by_day_criteria =>I18n.t('helpdesk.time_sheets.executed_at'), 
      :hours => I18n.t('helpdesk.time_sheets.hours') ,
      :product_name => I18n.t('helpdesk.time_sheets.product'), 
      :group_name => I18n.t('helpdesk.time_sheets.group') }    
  end                    

  def hours 
    seconds = time_spent.to_f
    sprintf( "%0.02f", seconds/3600)
  end


  def hhmm 
    seconds = time_spent
    hh = (seconds/3600).to_i
    mm = ((seconds % 3600) / 60).to_i

    hh.to_s.rjust(2,'0') + ":" + mm.to_s.rjust(2,'0')
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
    "#{workable.display_id} - #{workable.subject}"
  end
  
  def customer_name
    workable.requester.customer ? workable.requester.customer.name : workable.requester.name
  end
  
  def group_by_day_criteria
    executed_at.to_date.to_s(:db)
  end
  
  def stop_timer
     self.timer_running=false
     self.time_spent = calculate_time_spent
     self.save
  end

   def to_json(options = {}, deep=true)
    if deep
      self[:ticket_id] = self.workable.display_id
      self[:agent_name] = self.agent_name
      self[:timespent] = sprintf( "%0.02f", self.time_spent/3600) # converting to hours as in UI
      self[:agent_email] = user.email
      self[:customer_name] = self.customer_name
      self[:contact_email] = workable.requester.email
      options[:except] = [:account_id,:workable_id,:time_spent]
      options[:root] =:time_entry
    end
    json_str = super options
    json_str
  end

  def to_xml(options = {})
    options[:indent] ||= 2
    xml = options[:builder] ||= Builder::XmlMarkup.new(:indent => options[:indent])
    xml.instruct! unless options[:skip_instruct]
    super(:builder => xml, :skip_instruct => true, :dasherize=>false, :except => 
      [:account_id,:workable_id,:time_spent],:root=>:time_entry) do |xml|
      xml.tag!(:ticket_id,workable.display_id)
      xml.tag!(:agent_name,agent_name)
      xml.tag!(:time_spent,sprintf( "%0.02f", self.time_spent/3600)) # converting to hours as in UI
      xml.tag!(:agent_email,user.email) 
      xml.tag!(:customer_name,self.customer_name)
      xml.tag!(:contact_email,workable.requester.email)
    end
  end
  
  private
  
   def calculate_time_spent
    to_time = Time.zone.now.to_time
    from_time = start_time.to_time 
    running_time =  ((to_time - from_time).abs).round 
    return (time_spent + running_time)
   end

  def update_timer_activity
     
      if timer_running
         workable.create_activity(User.current, 
          "activities.#{workable_name}.timesheet.timer_started.long", 
          { 'eval_args' => { 'timesheet_path' => [ 
                                'timesheet_path', 
                                { 'ticket_id' => workable.display_id, 'timesheet_id' => id }
                              ]
                          }
          },
          "activities.#{workable_name}.timesheet.timer_started.short")
        
      else
        workable.create_activity(User.current, 
          "activities.#{workable_name}.timesheet.timer_stopped.long", 
          {'eval_args' => {'timesheet_path' => [
                                'timesheet_path', 
                                {'ticket_id' => workable.display_id, 'timesheet_id' => id }
                              ]
                          }
          },
          "activities.#{workable_name}.timesheet.timer_stopped.short")
      end 
  end
  
  def create_new_activity
      workable.create_activity(User.current, "activities.#{workable_name}.timesheet.new.long", 
          {'eval_args' => {'timesheet_path' => ['timesheet_path', 
                                {'ticket_id' => workable.display_id, 'timesheet_id' => id}]}},
                                "activities.#{workable_name}.timesheet.new.short")
  end

  def set_default_values
    self.executed_at ||= self.created_at
  end
 
  def workable_name
    workable_type.split("::").second.downcase.pluralize
  end
  
end
