class Helpdesk::TimeSheet < ActiveRecord::Base
  self.primary_key = :id
  include Va::Observer::Util
  include ApplicationHelper
  include Mobile::Actions::TimeSheet

  self.table_name =  "helpdesk_time_sheets"

  default_scope :order => "executed_at DESC"
  
  belongs_to :workable, :polymorphic => true
  delegate :product_name, :group_name, :to => :workable

  belongs_to :user
  belongs_to_account
  
  before_validation :set_default_values 

  after_create :create_new_activity
  after_update :update_timer_activity , :if => :timer_running_changed?
  before_save :update_observer_events
  after_commit :filter_observer_events, :if => :user_present?

  has_many :integrated_resources, 
    :class_name => 'Integrations::IntegratedResource',
    :as => 'local_integratable'
    
  scope :timer_active , :conditions =>["timer_running=?" , true]

  scope :created_at_inside, lambda { |start, stop|
    { :conditions => 
      [" helpdesk_time_sheets.executed_at >= ? and helpdesk_time_sheets.executed_at <= ?", 
        start, stop] 
    }
  }
  scope :hour_billable , lambda {|hr_billable| {:conditions =>{:billable => hr_billable} } }
        
  scope :by_agent , lambda { |created_by|
    { :conditions => {:user_id => created_by } } unless created_by.blank?
  }
  
  scope :by_group , lambda  { |group|
      { :conditions => { :helpdesk_tickets => { :group_id => group } } } unless group.blank?
  }

  scope :for_companies, lambda{ |company_ids|
    {
      :joins => [ "INNER JOIN `users` ON `helpdesk_tickets`.requester_id = `users`.id"],
      :conditions => {:users => {:customer_id => company_ids}}
    } unless company_ids.blank?
  }
      
  scope :for_contacts, lambda{|contact_email|
      {
        :joins => [ "INNER JOIN `users` ON `helpdesk_tickets`.requester_id = `users`.id"],
        :conditions =>{:users => {:email => contact_email}},
      } unless contact_email.blank?
  }

  scope :for_contacts_with_id, lambda{|id|
      {
        :joins => [ "INNER JOIN `users` ON `helpdesk_tickets`.requester_id = `users`.id"],
        :conditions =>{:users => {:id => id}},
      } unless id.blank?
  }

  scope :for_products, lambda { |products|
    { 
      :joins => [ "INNER JOIN helpdesk_schema_less_tickets on helpdesk_schema_less_tickets.ticket_id = helpdesk_tickets.id"],
      :conditions => {:helpdesk_schema_less_tickets=>{:product_id=>products}}
     } unless products.blank?
  }

  FILTER_OPTIONS = { :group_id => [], :company_id => [], :user_id => [], :billable => true, :executed_after => 0 }

  def self.billable_options
    { I18n.t('helpdesk.time_sheets.billable') => true, 
      I18n.t('helpdesk.time_sheets.non_billable') => false}
  end

  def self.group_by_options
    [ [I18n.t('helpdesk.time_sheets.customer') , :customer_name], 
      [I18n.t('helpdesk.time_sheets.agent') , :agent_name], 
      [I18n.t('helpdesk.time_sheets.group') , :group_name],
      [I18n.t('helpdesk.time_sheets.product') , :product_name], 
      [I18n.t('helpdesk.time_sheets.ticket') , :workable], 
      [I18n.t('helpdesk.time_sheets.executed_at') , :group_by_day_criteria] ]
  end                                                                                                                                               

  def self.report_list
    { :ticket => I18n.t('helpdesk.time_sheets.ticket'),
      :customer_name => I18n.t('helpdesk.time_sheets.customer'), 
      :agent_name =>  I18n.t('helpdesk.time_sheets.agent'), 
      :priority_name => I18n.t('helpdesk.time_sheets.priority'),
      :status_name => I18n.t('helpdesk.time_sheets.status'),
      :note =>  I18n.t('helpdesk.time_sheets.note'),
      :group_by_day_criteria =>I18n.t('helpdesk.time_sheets.executed_at'), 
      :hours => I18n.t('helpdesk.time_sheets.hours') ,
      :product_name => I18n.t('helpdesk.time_sheets.product'), 
      :group_name => I18n.t('helpdesk.time_sheets.group') }    
  end                    

  def self.filter(filter_options=FILTER_OPTIONS)
    relation = scoped
    filter_options.each_pair do |key, value|
      clause = filter_conditions(filter_options)[key.to_sym] || {}
      relation = relation.where(clause[:conditions]).joins(clause[:joins]) # where & join chaining
    end
    relation
  end

  def self.filter_conditions(filter_options=FILTER_OPTIONS)
    {
      billable: {
        conditions: { billable: filter_options[:billable].to_s.to_bool }
      },

      executed_after: {
        conditions: ['`helpdesk_time_sheets`.`executed_at` >= ?', Time.zone.parse(filter_options[:executed_after].to_s) ]
      },

      executed_before: {
        conditions: ['`helpdesk_time_sheets`.`executed_at` <= ?', Time.zone.parse(filter_options[:executed_before].to_s) ]
      },

      user_id: {
        conditions: {user_id: filter_options[:user_id]}
      },
      
      company_id: {
        joins: ["INNER JOIN `users` ON `helpdesk_tickets`.requester_id = `users`.id AND `helpdesk_tickets`.account_id = `users`.account_id"],
        conditions: {:users => {:customer_id => filter_options[:company_id]}}
      }
    }
  end

  def hours 
    seconds = time_spent.to_f
    sprintf( "%0.02f", seconds/3600)
  end

  def billable_type
    billable ? I18n.t('helpdesk.time_sheets.billable') : I18n.t('helpdesk.time_sheets.non_billable')
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
    workable.requester.company ? workable.requester.company.name : workable.requester.name
  end

  def priority_name
    workable.priority_name
  end

  def status_name
    workable.status_name
  end
  
  def group_by_day_criteria
    executed_at.to_date.to_s(:db)
  end
  
  def stop_timer
     self.timer_running=false
     self.time_spent = calculate_time_spent
     self.save
  end

   def as_json(options = {}, deep=true)
    if deep
      hash = {}
      hash['ticket_id'] = self.workable.display_id
      hash['agent_name'] = self.agent_name
      hash['timespent'] = sprintf( "%0.02f", self.time_spent.to_f/3600) # converting to hours as in UI
      hash['agent_email'] = user.email
      hash['customer_name'] = self.customer_name
      hash['contact_email'] = workable.requester.email
      options[:except] = [:account_id,:workable_id,:time_spent]
      options[:root] =:time_entry
    end
    json_hash = super(options)
    json_hash[:time_entry] = json_hash[:time_entry].merge(hash) if deep
    json_hash
  end

  def to_xml(options = {})
    options[:indent] ||= 2
    xml = options[:builder] ||= ::Builder::XmlMarkup.new(:indent => options[:indent])
    xml.instruct! unless options[:skip_instruct]
    super(:builder => xml, :skip_instruct => true, :dasherize=>false, :except => 
      [:account_id,:workable_id,:time_spent],:root=>:time_entry) do |xml|
      xml.tag!(:ticket_id,workable.display_id)
      xml.tag!(:agent_name,agent_name)
      xml.tag!(:time_spent,sprintf( "%0.02f", self.time_spent.to_f/3600)) # converting to hours as in UI
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

  # VA - Observer Rule 

  def update_observer_events
    return unless workable.instance_of? Helpdesk::Ticket
    unless time_spent_change.nil?      
      from, to = time_spent_change
      if from == nil
        unless to == 0
          @model_changes = {:time_sheet_action => :added} 
        end
      elsif from == 0
        @model_changes = {:time_sheet_action => :added}
      else
        @model_changes = {:time_sheet_action => :updated}
      end 
    end
  end

  def workable_name
   workable_type.split("::").second.downcase.pluralize
  end
  
end
