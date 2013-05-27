# encoding: utf-8
class Helpdesk::Activity < ActiveRecord::Base
  set_table_name "helpdesk_activities"
  
  belongs_to_account
  
  serialize :activity_data

  #belongs_to :account
  belongs_to :user
  belongs_to :notable, :polymorphic => true
  
  attr_protected :notable_id
  
  validates_presence_of :description, :notable_id, :user_id
  
  before_create :set_short_descr
  
  
  
  named_scope :freshest, lambda { |account|
    { :conditions => ["helpdesk_activities.account_id = ? ", account], 
      :order => "helpdesk_activities.id DESC"
    }
  }

  named_scope :activity_since, lambda { |id|
    { :conditions => ["helpdesk_activities.id > ? ", id],
      :order => "helpdesk_activities.id DESC",
      :limit => 20
    }
  }

  named_scope :activity_before, lambda { | activity_id|
    { :conditions => ["helpdesk_activities.id < ?", activity_id], 
      :order => "helpdesk_activities.id DESC"
    }
  }

  named_scope :newest_first, :order => "helpdesk_activities.id DESC"

  
 named_scope :permissible , lambda {|user| { 
 :joins => "LEFT JOIN `helpdesk_tickets` ON helpdesk_activities.notable_id = helpdesk_tickets.id AND helpdesk_activities.account_id = helpdesk_tickets.account_id AND notable_type = 'Helpdesk::Ticket'"  ,
 :conditions => send(:agent_permission ,user) } if user.agent? && !user.agent.all_ticket_permission  }
  
  def self.agent_permission user
    
    permissions = { :all_tickets => [] , 
                    :group_tickets => ["(helpdesk_activities.notable_type !=?)   OR (helpdesk_tickets.group_id in (?) OR helpdesk_tickets.responder_id=?)",
                                       'Helpdesk::Ticket' , user.agent_groups.collect{|ag| ag.group_id}.insert(0,0), user.id] , 
                    :assigned_tickets =>["(helpdesk_activities.notable_type !=?)   OR (helpdesk_tickets.responder_id=?)" ,'Helpdesk::Ticket', user.id] 
                  }
                  
     return permissions[Agent::PERMISSION_TOKENS_BY_KEY[user.agent.ticket_permission]]
  end

  def ticket_activity_type
    #Getting the Activity type ( Eg: activities.tickets.status_change.long ) to just "status_change"
    description.chomp('.long').gsub('activities.tickets.','')
  end

  def activity_type
    description.split('.')[1]
  end

  def ticket?
    activity_type == 'tickets'
  end

  def note?
    ticket_activity_type.start_with?('conversation.')
  end

  def note
    return Helpdesk::Note.find(note_id) if note?
  end

  def note_id
    key = activity_data["eval_args"].keys.first
    return activity_data['eval_args'][key][1]['comment_id']
  end

  private
    def set_short_descr
      self.short_descr ||= description
    end

end
