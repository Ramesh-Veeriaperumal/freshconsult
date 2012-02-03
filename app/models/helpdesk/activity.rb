class Helpdesk::Activity < ActiveRecord::Base
  set_table_name "helpdesk_activities"
  
  serialize :activity_data

  belongs_to :account
  belongs_to :user
  belongs_to :notable, :polymorphic => true
  
  attr_protected :notable_id
  
  validates_presence_of :description, :notable_id, :user_id
  
  before_create :set_short_descr
  
  named_scope :freshest, lambda { |account|
    { :conditions => ["helpdesk_activities.account_id = ? ", account], 
      :order => "helpdesk_activities.created_at DESC"
    }
  }

  named_scope :activity_since, lambda { |id|
    { :conditions => ["helpdesk_activities.id > ? ", id],
      :order => "helpdesk_activities.id DESC"
    }
  }

  named_scope :activty_before, lambda { |account, activity_id|
    { :conditions => ["helpdesk_activities.account_id = ? and helpdesk_activities.id <= ?", account, activity_id], 
      :order => "helpdesk_activities.created_at DESC"
    }
  }

  
 named_scope :permissible , lambda {|user| { 
 :joins => "LEFT JOIN `helpdesk_tickets` ON helpdesk_activities.notable_id = helpdesk_tickets.id AND notable_type = 'Helpdesk::Ticket' "  ,
 :conditions => send(:agent_permission ,user) } unless user.customer?  }
  
  def self.agent_permission user
    
    permissions = { :all_tickets => [] , 
                    :group_tickets => ["(helpdesk_activities.notable_type !=?)   OR (helpdesk_tickets.group_id in (?) OR helpdesk_tickets.responder_id=?)",
                                       'Helpdesk::Ticket' , user.agent_groups.collect{|ag| ag.group_id}.insert(0,0), user.id] , 
                    :assigned_tickets =>["(helpdesk_activities.notable_type !=?)   OR (helpdesk_tickets.responder_id=?)" ,'Helpdesk::Ticket', user.id] 
                  }
                  
     return permissions[Agent::PERMISSION_TOKENS_BY_KEY[user.agent.ticket_permission]]
  end

  private
    def set_short_descr
      self.short_descr ||= description
    end

end
