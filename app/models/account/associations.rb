class Account < ActiveRecord::Base

  has_many :tickets, :class_name => 'Helpdesk::Ticket'
  has_many :ticket_bodies, :class_name => 'Helpdesk::TicketBody'
  has_many :notes, :class_name => 'Helpdesk::Note'
  has_many :note_bodies, :class_name => 'Helpdesk::NoteBody'
  has_many :external_notes, :class_name => 'Helpdesk::ExternalNote'
  has_many :activities, :class_name => 'Helpdesk::Activity'
  has_many :flexifields
  has_many :ticket_states, :class_name =>'Helpdesk::TicketState'
  has_many :schema_less_tickets, :class_name => 'Helpdesk::SchemaLessTicket'
  has_many :schema_less_notes, :class_name => 'Helpdesk::SchemaLessNote'

  has_many :all_email_configs, :class_name => 'EmailConfig', :order => "name"
  has_many :email_configs, :conditions => { :active => true }
  has_many :global_email_configs, :class_name => 'EmailConfig', :conditions => {:product_id => nil}, :order => "primary_role desc"
  has_one  :primary_email_config, :class_name => 'EmailConfig', :conditions => { :primary_role => true, :product_id => nil }
  has_many :imap_mailboxes
  has_many :smtp_mailboxes
  has_many :products, :order => "name"
  has_many :roles, :order => "default_role desc"
  has_many :portals, :dependent => :destroy
  has_one  :main_portal, :class_name => 'Portal', :conditions => { :main_portal => true}
  has_one :account_additional_settings, :class_name => 'AccountAdditionalSettings'
  has_one  :whitelisted_ip
  has_many :dynamic_notification_templates
  has_many :google_accounts, :class_name => 'Integrations::GoogleAccount'

  accepts_nested_attributes_for :primary_email_config
  accepts_nested_attributes_for :main_portal
  accepts_nested_attributes_for :account_additional_settings
  accepts_nested_attributes_for :whitelisted_ip

  has_many :survey_results
  has_many :survey_remarks

  has_one  :subscription_plan, :through => :subscription

  has_one :conversion_metric

  accepts_nested_attributes_for :conversion_metric

  has_many :features
  has_many :flexi_field_defs, :class_name => 'FlexifieldDef'
  has_one  :ticket_field_def,  :class_name => 'FlexifieldDef', 
    :conditions => Proc.new { 
      "name = 'Ticket_#{self.id}'"
    }
  has_one  :contact_form
  has_one  :company_form
  has_many :flexifield_def_entries

  has_many :data_exports

  has_one :account_additional_settings

  has_one :account_configuration

  delegate :contact_info, :admin_first_name, :admin_last_name, :admin_email, :admin_phone,
    :notification_emails, :invoice_emails, :to => "account_configuration"
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

  has_many :cloud_files,  :class_name=> 'Helpdesk::CloudFile'

  has_many :users, :conditions =>{:deleted =>false}, :order => :name
  has_many :all_users , :class_name => 'User'
  has_many :user_emails, :class_name => 'UserEmail'

  has_many :technicians, :class_name => "User", :conditions => { :helpdesk_agent => true, :deleted => false }, :order => "name desc"

  has_one :subscription
  has_many :subscription_payments
  has_many :portal_solution_categories, :class_name => "PortalSolutionCategory"
  has_many :solution_categories, :class_name =>'Solution::Category', :include =>:folders, :order => "solution_categories.position"
  has_many :solution_category_meta, :class_name =>'Solution::CategoryMeta', :include =>:solution_folder_meta, :order => "solution_category_meta.position"
  has_many :solution_articles, :class_name =>'Solution::Article'

  has_many :solution_drafts, :class_name =>'Solution::Draft'
  has_many :solution_draft_bodies, :class_name =>'Solution::DraftBody'
  has_many :article_tickets, :class_name => 'ArticleTicket'

  has_many :solution_article_meta, :class_name =>'Solution::ArticleMeta'
  has_many :solution_article_bodies, :class_name =>'Solution::ArticleBody'

  has_many :installed_applications, :class_name => 'Integrations::InstalledApplication'
  has_many :user_credentials, :class_name => 'Integrations::UserCredential'
  has_many :companies
  has_many :contacts, :class_name => 'User' , :conditions => { :helpdesk_agent => false , :deleted =>false }
  has_many :agents, :through =>:users , :conditions =>{:users=>{:deleted => false}}, :order => "users.name"
  has_many :full_time_agents, :through =>:users, :conditions => { :occasional => false,
                                                                  :users=> { :deleted => false } }
  has_many :all_contacts , :class_name => 'User', :conditions => { :helpdesk_agent => false }
  has_many :all_agents, :class_name => 'Agent', :through =>:all_users  , :source =>:agent
  has_many :sla_policies , :class_name => 'Helpdesk::SlaPolicy'
  has_one  :default_sla ,  :class_name => 'Helpdesk::SlaPolicy' , :conditions => { :is_default => true }
  has_many :google_contacts, :class_name => 'GoogleContact'
  has_many :mobihelp_devices, :class_name => 'Mobihelp::Device'

  #Scoping restriction for other models starts here
  has_many :account_va_rules, :class_name => 'VaRule'

  has_many :va_rules, :class_name => 'VaRule', :conditions => {
  :rule_type => VAConfig::BUSINESS_RULE, :active => true }, :order => "position"
  has_many :all_va_rules, :class_name => 'VaRule', :conditions => {
  :rule_type => VAConfig::BUSINESS_RULE }, :order => "position"

  has_many :supervisor_rules, :class_name => 'VaRule', :conditions => {
  :rule_type => VAConfig::SUPERVISOR_RULE, :active => true }, :order => "position"
  has_many :all_supervisor_rules, :class_name => 'VaRule', :conditions => {
  :rule_type => VAConfig::SUPERVISOR_RULE }, :order => "position"

  has_many :observer_rules, :class_name => 'VaRule', :conditions => {
  :rule_type => VAConfig::OBSERVER_RULE, :active => true }, :order => "position"
  has_many :all_observer_rules, :class_name => 'VaRule', :conditions => {
  :rule_type => VAConfig::OBSERVER_RULE }, :order => "position"

  has_many :api_webhook_rules, :class_name => 'VaRule', :conditions => {
  :rule_type => VAConfig::API_WEBHOOK_RULE, :active => true }, :order => "position"

  has_many :scn_automations, :class_name => 'ScenarioAutomation', :conditions =>{
  :rule_type => VAConfig::SCENARIO_AUTOMATION }, :order => "name"

  has_many :all_scn_automations, :class_name => 'VaRule',:conditions => {
  :rule_type => VAConfig::SCENARIO_AUTOMATION }, :order=> "position"
   
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
  has_many :monitorships
  has_many :votes

  has_many :folders, :class_name =>'Solution::Folder', :through => :solution_categories
  #The following is a duplicate association. Added this for metaprogramming
  has_many :solution_folders, :class_name =>'Solution::Folder', :through => :solution_categories
  has_many :solution_folder_meta, :class_name =>'Solution::FolderMeta', :through => :solution_category_meta
  has_many :public_folders, :through => :solution_categories
  has_many :published_articles, :through => :public_folders,
    :conditions => [" solution_folders.visibility = ? ", Solution::Folder::VISIBILITY_KEYS_BY_TOKEN[:anyone]]

  has_many :ticket_fields, :class_name => 'Helpdesk::TicketField', :conditions => {:parent_id => nil},
    :include => [:picklist_values, :flexifield_def_entry], :order => "helpdesk_ticket_fields.position"

  # added below mapping for multiform phase1 only
  has_many :ticket_fields_with_nested_fields, :class_name => 'Helpdesk::TicketField'

  has_many :ticket_statuses, :class_name => 'Helpdesk::TicketStatus', :order => "position"


  has_many :canned_response_folders, :class_name =>'Admin::CannedResponses::Folder', :order => 'folder_type , name'

  has_many :canned_responses , :class_name =>'Admin::CannedResponses::Response' , :order => 'title'

  has_many :accesses, :class_name => 'Helpdesk::Access'

  has_many :user_accesses , :class_name =>'Admin::UserAccess'

  has_many :facebook_pages, :class_name =>'Social::FacebookPage'

  has_many :facebook_posts, :class_name =>'Social::FbPost'

  has_many :ticket_filters , :class_name =>'Helpdesk::Filters::CustomTicketFilter'

  has_many :twitter_handles, :class_name =>'Social::TwitterHandle'
  has_many :tweets, :class_name =>'Social::Tweet'
  has_many :social_streams, :class_name => 'Social::Stream'
  has_many :twitter_streams, :class_name => 'Social::TwitterStream'

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

  delegate :addons, :currency_name, :billing, :to => :subscription

  has_one :zendesk_import, :class_name => 'Admin::DataImport' , :conditions => {:source => Admin::DataImport::IMPORT_TYPE[:zendesk]}

  has_one :contact_import, :class_name => 'Admin::DataImport' , :conditions => {:source => Admin::DataImport::IMPORT_TYPE[:contact]}

  has_one :company_import, :class_name => 'Admin::DataImport' , :conditions => {:source => Admin::DataImport::IMPORT_TYPE[:company]}


  has_many :tags, :class_name =>'Helpdesk::Tag'
  has_many :tag_uses, :class_name =>'Helpdesk::TagUse'

  has_many :time_sheets , :class_name =>'Helpdesk::TimeSheet' , :through =>:tickets , :conditions =>['helpdesk_tickets.deleted =?', false]

  has_many :support_scores, :class_name => 'SupportScore'

  has_one  :es_enabled_account, :class_name => 'EsEnabledAccount', :dependent => :destroy

  delegate :bcc_email, :ticket_id_delimiter, :email_cmds_delimeter,
    :pass_through_enabled, :api_limit, :to => :account_additional_settings

  has_many :subscription_events

  has_many :portal_templates,  :class_name=> 'Portal::Template'
  has_many :portal_pages,  :class_name=> 'Portal::Page'

  delegate :active_groups_in_account, :to => :groups, :allow_nil => true
  #Freshfone
  has_one  :freshfone_account, :class_name => 'Freshfone::Account', :dependent => :destroy
  has_many :freshfone_numbers, :conditions =>{:deleted => false}, :class_name => "Freshfone::Number"
  has_many :all_freshfone_numbers, :class_name => 'Freshfone::Number', :dependent => :delete_all
  has_many :ivrs, :class_name => 'Freshfone::Ivr'
  has_many :freshfone_calls, :class_name => 'Freshfone::Call'
  delegate :find_by_call_sid, :to => :freshfone_calls
  has_one  :freshfone_credit, :class_name => 'Freshfone::Credit'
  has_many :freshfone_payments, :class_name => 'Freshfone::Payment'
  delegate :freshfone_subaccount, :allow_nil => true, :to => :freshfone_account
  has_many :freshfone_users, :class_name => "Freshfone::User"
  has_many :freshfone_other_charges, :class_name => "Freshfone::OtherCharge"
  has_many :freshfone_blacklist_numbers, :class_name => "Freshfone::BlacklistNumber"

  has_many :freshfone_callers, :class_name => "Freshfone::Caller"

  has_many :freshfone_whitelist_country, :class_name => "Freshfone::WhitelistCountry"
  
  has_one :chat
  has_many :report_filters, :class_name => 'Helpdesk::ReportFilter'

  has_one :chat_setting
  has_many :chat_widgets
  has_one  :main_chat_widget, :class_name => 'ChatWidget', :conditions => {:main_widget => true}
  has_many :mobihelp_apps, :class_name => 'Mobihelp::App'
  has_many :mobihelp_app_solutions, :class_name => 'Mobihelp::AppSolution'

  has_many :forum_moderators

  has_many :solution_customer_folders, :class_name => "Solution::CustomerFolder"
end
