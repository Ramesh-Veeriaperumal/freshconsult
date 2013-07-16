class Account < ActiveRecord::Base

  has_many :tickets, :class_name => 'Helpdesk::Ticket', :dependent => :delete_all
  has_many :ticket_bodies, :class_name => 'Helpdesk::TicketBody', :dependent => :delete_all
  has_many :notes, :class_name => 'Helpdesk::Note', :dependent => :delete_all
  has_many :note_bodies, :class_name => 'Helpdesk::NoteBody', :dependent => :delete_all
  has_many :external_notes, :class_name => 'Helpdesk::ExternalNote', :dependent => :delete_all
  has_many :activities, :class_name => 'Helpdesk::Activity', :dependent => :delete_all
  has_many :flexifields, :dependent => :delete_all
  has_many :ticket_states, :class_name =>'Helpdesk::TicketState', :dependent => :delete_all
  has_many :schema_less_tickets, :class_name => 'Helpdesk::SchemaLessTicket', :dependent => :delete_all
  has_many :schema_less_notes, :class_name => 'Helpdesk::SchemaLessNote', :dependent => :delete_all
  
  has_many :all_email_configs, :class_name => 'EmailConfig', :order => "name"
  has_many :email_configs, :conditions => { :active => true }
  has_many :global_email_configs, :class_name => 'EmailConfig', :conditions => {:product_id => nil}, :order => "primary_role desc"
  has_one  :primary_email_config, :class_name => 'EmailConfig', :conditions => { :primary_role => true, :product_id => nil }
  has_many :products, :order => "name"
  has_many :roles, :dependent => :delete_all, :order => "default_role desc"
  has_many :portals
  has_one  :main_portal, :class_name => 'Portal', :conditions => { :main_portal => true}

  accepts_nested_attributes_for :primary_email_config
  accepts_nested_attributes_for :main_portal


  has_many :survey_results
  has_many :survey_remarks

  has_one  :subscription_plan, :through => :subscription

  has_one :conversion_metric

  accepts_nested_attributes_for :conversion_metric
 
  has_many :features
  has_many :flexi_field_defs, :class_name => 'FlexifieldDef'
  has_many :flexifield_def_entries
  
  has_one :data_export
  
  has_one :account_additional_settings

  has_one :account_configuration

  delegate :contact_info, :admin_first_name, :admin_last_name, :admin_email, :admin_phone, 
            :invoice_emails, :to => "account_configuration"
  has_one :logo,
    :as => :attachable,
    :class_name => 'Helpdesk::Attachment',
    :conditions => ['description = ?', 'logo' ]
  
  has_one :fav_icon,
    :as => :attachable,
    :class_name => 'Helpdesk::Attachment',
    :conditions => ['description = ?', 'fav_icon' ]

    #
  # Tell authlogic that we'll be scoping users by account
  #
  authenticates_many :user_sessions
  
  has_many :attachments, :class_name => 'Helpdesk::Attachment'

  has_many :dropboxes,  :class_name=> 'Helpdesk::Dropbox'
  
  has_many :users, :conditions =>{:deleted =>false}, :order => :name
  has_many :all_users , :class_name => 'User'
  
  has_many :technicians, :class_name => "User", :conditions => { :helpdesk_agent => true, :deleted => false }, :order => "name desc"
  
  has_one :subscription
  has_many :subscription_payments
  has_many :solution_categories, :class_name =>'Solution::Category',:include =>:folders,:order => "position"
  has_many :portal_solution_categories, :class_name =>'Solution::Category', :order => "position"
  has_many :solution_articles, :class_name =>'Solution::Article'
  
  has_many :installed_applications, :class_name => 'Integrations::InstalledApplication'
  has_many :user_credentials, :class_name => 'Integrations::UserCredential', :dependent => :destroy
  has_many :customers
  has_many :contacts, :class_name => 'User' , :conditions => { :helpdesk_agent => false , :deleted =>false }
  has_many :agents, :through =>:users , :conditions =>{:users=>{:deleted => false}}, :order => "users.name"
  has_many :full_time_agents, :through =>:users, :conditions => { :occasional => false, 
      :users=> { :deleted => false } }
  has_many :all_contacts , :class_name => 'User', :conditions => { :helpdesk_agent => false }
  has_many :all_agents, :class_name => 'Agent', :through =>:all_users  , :source =>:agent
  has_many :sla_policies , :class_name => 'Helpdesk::SlaPolicy' 
  has_one  :default_sla ,  :class_name => 'Helpdesk::SlaPolicy' , :conditions => { :is_default => true }

  #Scoping restriction for other models starts here
  has_many :account_va_rules, :class_name => 'VARule'
  
  has_many :va_rules, :class_name => 'VARule', :conditions => { 
    :rule_type => VAConfig::BUSINESS_RULE, :active => true }, :order => "position"
  has_many :all_va_rules, :class_name => 'VARule', :conditions => {
    :rule_type => VAConfig::BUSINESS_RULE }, :order => "position"
    
  has_many :supervisor_rules, :class_name => 'VARule', :conditions => { 
    :rule_type => VAConfig::SUPERVISOR_RULE, :active => true }, :order => "position"
  has_many :all_supervisor_rules, :class_name => 'VARule', :conditions => {
    :rule_type => VAConfig::SUPERVISOR_RULE }, :order => "position"

  has_many :observer_rules, :class_name => 'VARule', :conditions => { 
    :rule_type => VAConfig::OBSERVER_RULE, :active => true }, :order => "position"
  has_many :all_observer_rules, :class_name => 'VARule', :conditions => {
    :rule_type => VAConfig::OBSERVER_RULE }, :order => "position"
  
  has_many :scn_automations, :class_name => 'VARule', :conditions => {:rule_type => VAConfig::SCENARIO_AUTOMATION, :active => true}, :order => "position"
  has_many :all_scn_automations, :class_name => 'VARule', :conditions => {:rule_type => VAConfig::SCENARIO_AUTOMATION, :active => true}, :order => "position"
  
  has_many :email_notifications
  has_many :groups
  has_many :agent_groups
  has_many :forum_categories, :order => "position"
  
  has_many :business_calendar 

  has_many :forums, :through => :forum_categories    
  has_many :portal_forums, :through => :forum_categories, 
    :conditions =>{:forum_visibility => Forum::VISIBILITY_KEYS_BY_TOKEN[:anyone]}, :order => "position"     
  has_many :portal_topics, :through => :forums# , :order => 'replied_at desc', :limit => 5
  
  has_many :user_forums, :through => :forum_categories, :conditions =>['forum_visibility != ?', Forum::VISIBILITY_KEYS_BY_TOKEN[:agents]] 
  has_many :user_topics, :through => :user_forums#, :order => 'replied_at desc', :limit => 5

  has_many :topics
  has_many :posts

  has_many :folders, :class_name =>'Solution::Folder', :through => :solution_categories  
  has_many :public_folders, :through => :solution_categories
  has_many :published_articles, :through => :public_folders
   
  has_many :ticket_fields, :class_name => 'Helpdesk::TicketField', 
    :include => [:picklist_values, :flexifield_def_entry], :order => "position"

  has_many :ticket_statuses, :class_name => 'Helpdesk::TicketStatus', :order => "position"
  
  has_many :canned_response_folders, :class_name =>'Admin::CannedResponses::Folder', :order => 'is_default desc'

  has_many :canned_responses , :class_name =>'Admin::CannedResponses::Response' , :order => 'title' 
  
  has_many :user_accesses , :class_name =>'Admin::UserAccess' 

  has_many :facebook_pages, :class_name =>'Social::FacebookPage' 
  
  has_many :facebook_posts, :class_name =>'Social::FbPost' 
  
  has_many :ticket_filters , :class_name =>'Helpdesk::Filters::CustomTicketFilter' 

  has_many :twitter_handles, :class_name =>'Social::TwitterHandle' 
  has_many :tweets, :class_name =>'Social::Tweet'  
  
  has_one :survey
  has_many :survey_handles, :through => :survey

  has_many :scoreboard_ratings
  has_many :scoreboard_levels

  has_many :quests, :class_name => 'Quest', :conditions => { :active => true }, 
    :order => "quests.created_at desc, quests.id desc"
  has_many :all_quests, :class_name => 'Quest', :order => "quests.created_at desc, quests.id desc"


  has_one :day_pass_config
  has_many :day_pass_usages
  has_many :day_pass_purchases, :order => "created_at desc"
  
  has_one :data_import,:class_name => 'Admin::DataImport' 

  
  has_many :tags, :class_name =>'Helpdesk::Tag'
  
  has_many :time_sheets , :class_name =>'Helpdesk::TimeSheet' , :through =>:tickets , :conditions =>['helpdesk_tickets.deleted =?', false]
  
  has_many :support_scores, :class_name => 'SupportScore', :dependent => :delete_all

  has_one  :es_enabled_account, :class_name => 'EsEnabledAccount', :dependent => :destroy

  delegate :bcc_email, :ticket_id_delimiter, :email_cmds_delimeter, :pass_through_enabled, :to => :account_additional_settings

  has_many :subscription_events 

  has_many :portal_templates,  :class_name=> 'Portal::Template'
  has_many :portal_pages,  :class_name=> 'Portal::Page'
  
end