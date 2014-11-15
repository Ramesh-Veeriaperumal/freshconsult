class User < ActiveRecord::Base

  belongs_to :company, :foreign_key => 'customer_id'
  belongs_to :parent, :class_name =>'User', :foreign_key => :string_uc04

  has_many :authorizations, :dependent => :destroy
  has_many :votes, :dependent => :destroy
  has_many :day_pass_usages, :dependent => :destroy

  # has_many :user_emails , :class_name =>'UserEmail', :validate => true, :dependent => :destroy, :order => "primary_role desc"
  # has_many :verified_emails, :class_name =>'UserEmail', :dependent => :destroy, :conditions => { :verified => true }
  # has_one :primary_email, :class_name => 'UserEmail', :conditions => { :primary_role => true }

  # accepts_nested_attributes_for :user_emails, :reject_if => proc {|att| att['email'].blank? }, :allow_destroy => true

  # delegate :email, :to => :primary_email, :allow_nil => true, :prefix => :actual
  
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
  has_many :notes, :class_name => 'Helpdesk::Note'
  has_many :activities, :class_name => 'Helpdesk::Activity'
  
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
  accepts_nested_attributes_for :google_contacts  # Added to save the company while importing user from google contacts.

  delegate :available?, :in_round_robin?, :to => :agent, :allow_nil => true

  # SavageBeast associations moved here
  has_many :moderatorships, :dependent => :destroy
  has_many :forums, :through => :moderatorships, :order => "#{Forum.table_name}.name"
  has_many :posts

  has_many :recent_posts, :class_name => 'Post', :order => "created_at desc", :limit => 5
  has_many :topics
  has_many :monitorships
  has_many :monitored_topics, :through => :monitorships, :conditions => ["#{Monitorship.table_name}.active = ?", true], :order => "#{Topic.table_name}.replied_at desc", :source => :monitorable, :source_type => "Topic"
  has_many :freshfone_calls, :class_name => 'Freshfone::Call'
  has_one  :freshfone_user, :class_name => "Freshfone::User", :inverse_of => :user, :dependent => :destroy
  delegate :online?, :offline?, :presence, :incoming_preference, :number,
           :to => :freshfone_user, :prefix => true, :allow_nil => true
  delegate :available_on_phone?, :to => :freshfone_user, :allow_nil => true

  has_many :report_filters, :class_name => 'Helpdesk::ReportFilter'
  has_many :data_exports

  has_and_belongs_to_many :accesses,  
    :class_name => 'Helpdesk::Access',
    :join_table => 'user_accesses'

  has_many :mobihelp_devices, :class_name => 'Mobihelp::Device', :dependent => :destroy
end
