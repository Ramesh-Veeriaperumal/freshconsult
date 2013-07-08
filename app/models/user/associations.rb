class User < ActiveRecord::Base

  belongs_to :customer
  has_many :authorizations, :dependent => :destroy
  has_many :votes, :dependent => :destroy
  has_many :day_pass_usages, :dependent => :destroy
  
  has_many :time_sheets , :class_name =>'Helpdesk::TimeSheet' , :dependent => :destroy
   
  has_many :email_notification_agents,  :dependent => :destroy
  
  has_and_belongs_to_many :roles,
    :join_table => "user_roles",
    :insert_sql => 
      'INSERT INTO user_roles (account_id, user_id, role_id) VALUES
       (#{account_id}, #{id}, #{ActiveRecord::Base.sanitize(record.id)})',
    :after_add => :touch_role_change,
    :after_remove => :touch_role_change,
    :autosave => true

  has_many :tag_uses,
    :as => :taggable,
    :class_name => 'Helpdesk::TagUse',
    :dependent => :destroy

  has_many :tags, 
    :class_name => 'Helpdesk::Tag',
    :through => :tag_uses

  has_many :google_contacts, :dependent => :destroy

  has_one :avatar,
    :as => :attachable,
    :class_name => 'Helpdesk::Attachment',
    :dependent => :destroy

  has_many :support_scores, :dependent => :delete_all

  has_many :user_credentials, :class_name => 'Integrations::UserCredential', :dependent => :destroy

  # TODO move this to the "HelpdeskUser" model
  # when it is available
  has_many :subscriptions, 
    :class_name => 'Helpdesk::Subscription'
  
  has_many :subscribed_tickets, 
    :class_name => 'Helpdesk::Ticket',
    :source => 'ticket',
    :through => :subscriptions

  has_many :reminders, 
    :class_name => 'Helpdesk::Reminder',:dependent => :destroy
    
  has_many :tickets , :class_name => 'Helpdesk::Ticket' ,:foreign_key => "requester_id" 
  
  has_many :open_tickets, :class_name => 'Helpdesk::Ticket' ,:foreign_key => "requester_id",
  :conditions => {:status => [OPEN,PENDING]},
  :order => "created_at desc"
  
  has_one :agent , :class_name => 'Agent' , :foreign_key => "user_id", :dependent => :destroy
  has_one :full_time_agent, :class_name => 'Agent', :foreign_key => "user_id", :conditions => { 
      :occasional => false  } #no direct use, need this in account model for pass through.
  
  has_many :agent_groups , :class_name =>'AgentGroup', :foreign_key => "user_id" , :dependent => :destroy

  has_many :achieved_quests, :dependent => :delete_all

  has_many :quests, :through => :achieved_quests
  
  has_many :canned_responses , :class_name =>'Admin::CannedResponse' 
  
  #accepts_nested_attributes_for :agent
  accepts_nested_attributes_for :customer, :google_contacts  # Added to save the customer while importing user from google contacts.

  delegate :available?, :in_round_robin?, :to => :agent, :allow_nil => true

  # SavageBeast associations moved here
  has_many :moderatorships, :dependent => :destroy
  has_many :forums, :through => :moderatorships, :order => "#{Forum.table_name}.name"
  has_many :posts
  has_many :topics
  has_many :monitorships
  has_many :monitored_topics, :through => :monitorships, :conditions => ["#{Monitorship.table_name}.active = ?", true], :order => "#{Topic.table_name}.replied_at desc", :source => :topic

end