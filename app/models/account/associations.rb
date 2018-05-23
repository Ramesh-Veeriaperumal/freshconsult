class Account < ActiveRecord::Base

  has_many :tickets, :class_name => 'Helpdesk::Ticket'
  has_many :ticket_bodies, :class_name => 'Helpdesk::TicketBody'
  has_many :notes, :class_name => 'Helpdesk::Note'
  has_many :note_bodies, :class_name => 'Helpdesk::NoteBody'
  has_many :external_notes, :class_name => 'Helpdesk::ExternalNote'
  has_many :broadcast_messages, :class_name => 'Helpdesk::BroadcastMessage'
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
  delegate :supported_languages, :to => :account_additional_settings
  delegate :secret_keys, to: :account_additional_settings
  delegate :max_template_limit, to: :account_additional_settings
  has_one  :whitelisted_ip
  has_one :contact_password_policy, :class_name => 'PasswordPolicy',
    :conditions => {:user_type => PasswordPolicy::USER_TYPE[:contact]}, :dependent => :destroy
  has_one :agent_password_policy, :class_name => 'PasswordPolicy',
    :conditions => {:user_type => PasswordPolicy::USER_TYPE[:agent]}, :dependent => :destroy
  has_many :dynamic_notification_templates
  has_many :google_accounts, :class_name => 'Integrations::GoogleAccount'


  accepts_nested_attributes_for :primary_email_config
  accepts_nested_attributes_for :main_portal
  accepts_nested_attributes_for :account_additional_settings
  accepts_nested_attributes_for :whitelisted_ip
  accepts_nested_attributes_for :contact_password_policy
  accepts_nested_attributes_for :agent_password_policy

  has_one  :subscription_plan, :through => :subscription

  has_one :conversion_metric

  accepts_nested_attributes_for :conversion_metric

  has_many :features
  has_many :flexi_field_defs, :class_name => 'FlexifieldDef'
  has_one  :ticket_field_def,  :class_name => 'FlexifieldDef',
      :conditions => {:module => "Ticket"}

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
  has_many :all_technicians, :class_name => "User", :conditions => { :helpdesk_agent => true }

  has_one :subscription
  has_many :subscription_payments


  has_many :solution_drafts, :class_name =>'Solution::Draft'
  has_many :solution_draft_bodies, :class_name =>'Solution::DraftBody'
  has_many :article_tickets, :class_name => 'ArticleTicket'

  has_many :installed_applications, :class_name => 'Integrations::InstalledApplication'
  has_many :user_credentials, :class_name => 'Integrations::UserCredential'
  has_many :companies
  has_many :company_domains
  has_many :contacts, :class_name => 'User' , :conditions => { :helpdesk_agent => false , :deleted =>false }
  has_many :agents, :through =>:users , :conditions =>{:users=>{:deleted => false}}, :order => "users.name"
  has_many :available_agents, :class_name => 'Agent', :through => :users, :source =>:agent, :conditions =>{:available => true}, :order => "users.name"
  has_many :full_time_agents, :through =>:users, :conditions => { :occasional => false,
                                                                  :users=> { :deleted => false } }
  has_many :all_contacts , :class_name => 'User', :conditions => { :helpdesk_agent => false }
  has_many :all_agents, :class_name => 'Agent', :through =>:all_users  , :source =>:agent
  has_many :sla_policies , :class_name => 'Helpdesk::SlaPolicy'
  has_one  :default_sla ,  :class_name => 'Helpdesk::SlaPolicy' , :conditions => { :is_default => true }
  has_many :google_contacts, :class_name => 'GoogleContact'
  has_many :mobihelp_devices, :class_name => 'Mobihelp::Device'

  has_many :skills, :order => "position", :class_name => 'Admin::Skill'
  has_many :sorted_skills, :order => "name", :class_name => 'Admin::Skill'

  has_many :user_skills

  has_one :activity_export, :class_name => 'ScheduledExport::Activity', dependent: :destroy

  has_many :scheduled_ticket_exports

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
  :rule_type => VAConfig::SCENARIO_AUTOMATION }

  has_many :all_scn_automations, :class_name => 'VaRule',:conditions => {
  :rule_type => VAConfig::SCENARIO_AUTOMATION }, :order=> "position"

  has_many :installed_app_business_rules, :class_name => 'VaRule', :conditions => {
  :rule_type => VAConfig::INSTALLED_APP_BUSINESS_RULE, :active => true }, :order => "position"

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

  has_many :ticket_fields, :class_name => 'Helpdesk::TicketField', :conditions => {:parent_id => nil},
    :include => [:picklist_values, :flexifield_def_entry], :order => "helpdesk_ticket_fields.position"

  has_many :ticket_fields_without_choices, :class_name => 'Helpdesk::TicketField', :conditions => {:parent_id => nil},
    :include => [:flexifield_def_entry], :order => "helpdesk_ticket_fields.position"

  has_many :ticket_fields_including_nested_fields, :class_name => 'Helpdesk::TicketField', :conditions => {:parent_id => nil},
    :include => [:picklist_values, :flexifield_def_entry, :nested_ticket_fields], :order => "helpdesk_ticket_fields.position"

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
  has_many :facebook_streams, :class_name => 'Social::FacebookStream'

  has_many :surveys
  has_many :survey_handles, :through => :surveys
  has_many :survey_results
  has_many :survey_remarks

  has_many :custom_surveys, :class_name => 'CustomSurvey::Survey'
  has_many :custom_survey_questions, :class_name => 'CustomSurvey::SurveyQuestion'
  has_many :custom_survey_handles, :class_name => 'CustomSurvey::SurveyHandle'
  has_many :custom_survey_results, :class_name => 'CustomSurvey::SurveyResult'
  has_many :custom_survey_remarks, :class_name => 'CustomSurvey::SurveyRemark'

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

  has_one :agent_skill_import, :class_name => 'Admin::DataImport' , :conditions => {:source => Admin::DataImport::IMPORT_TYPE[:agent_skill]}


  has_many :tags, :class_name =>'Helpdesk::Tag'
  has_many :tag_uses, :class_name =>'Helpdesk::TagUse'

  # Archive Association Starts Here
  has_many :archive_tickets, :class_name => "Helpdesk::ArchiveTicket"
  has_many :archive_notes, :class_name => "Helpdesk::ArchiveNote"
  has_many :archive_time_sheets , :class_name =>'Helpdesk::TimeSheet' , :through =>:archive_tickets , :conditions =>['archive_tickets.deleted =?', false]
  # Archive Association Ends Here

  has_many :time_sheets , :class_name =>'Helpdesk::TimeSheet' , :through =>:tickets , :conditions =>['helpdesk_tickets.deleted =?', false]

  has_many :support_scores, :class_name => 'SupportScore'

  has_one  :es_enabled_account, :class_name => 'EsEnabledAccount', :dependent => :destroy

  delegate :bcc_email, :ticket_id_delimiter, :email_cmds_delimeter,
    :pass_through_enabled, :api_limit, :webhook_limit, :to => :account_additional_settings

  has_many :subscription_events

  has_many :portal_templates,  :class_name=> 'Portal::Template'
  has_many :portal_pages,  :class_name=> 'Portal::Page'

  delegate :active_groups_in_account, :to => :groups, :allow_nil => true
  #Freshfone
  has_one  :freshfone_account, :class_name => 'Freshfone::Account', :dependent => :destroy
  has_one  :freshcaller_account, :class_name => 'Freshcaller::Account', :dependent => :destroy
  has_many :freshfone_numbers, :conditions =>{:deleted => false}, :class_name => "Freshfone::Number"
  has_many :all_freshfone_numbers, :class_name => 'Freshfone::Number', :dependent => :delete_all
  has_many :ivrs, :class_name => 'Freshfone::Ivr'
  has_many :freshfone_calls, :class_name => 'Freshfone::Call'
  has_many :freshcaller_calls, :class_name => 'Freshcaller::Call'
  has_many :supervisor_controls, :class_name => 'Freshfone::SupervisorControl'
  delegate :find_by_call_sid, :to => :freshfone_calls
  has_one  :freshfone_credit, :class_name => 'Freshfone::Credit'
  has_many :freshfone_payments, :class_name => 'Freshfone::Payment'
  delegate :freshfone_subaccount, :allow_nil => true, :to => :freshfone_account
  has_many :freshfone_users, :class_name => "Freshfone::User"
  has_many :freshfone_other_charges, :class_name => "Freshfone::OtherCharge"
  has_many :freshfone_blacklist_numbers, :class_name => "Freshfone::BlacklistNumber"
  has_one  :freshfone_subscription, :class_name => "Freshfone::Subscription"
  has_many :freshfone_caller_id, :class_name => "Freshfone::CallerId"

  has_many :freshfone_callers, :class_name => "Freshfone::Caller"

  has_many :freshfone_whitelist_country, :class_name => "Freshfone::WhitelistCountry"

  has_one :chat
  has_one  :freshchat_account, :class_name => 'Freshchat::Account', :dependent => :destroy
  has_many :report_filters, :class_name => 'Helpdesk::ReportFilter'

  has_one :chat_setting
  has_many :chat_widgets
  has_one  :main_chat_widget, :class_name => 'ChatWidget', :conditions => {:main_widget => true}
  has_many :mobihelp_apps, :class_name => 'Mobihelp::App'
  has_many :mobihelp_app_solutions, :class_name => 'Mobihelp::AppSolution'
  has_many :ecommerce_accounts, :class_name => 'Ecommerce::Account', :dependent => :destroy
  has_many :ebay_accounts, :class_name => 'Ecommerce::EbayAccount'
  has_many :ebay_questions, :class_name => "Ecommerce::EbayQuestion", :through => :ebay_accounts

  has_many :forum_moderators

  has_many :solution_customer_folders, :class_name => "Solution::CustomerFolder"

  has_many :sections, :class_name => 'Helpdesk::Section', :dependent => :destroy
  has_many :section_fields_with_field_values_mapping, :class_name => 'Helpdesk::SectionField',
            :include => [:parent_ticket_field, :section => {:section_picklist_mappings => :picklist_value}]
  has_many :section_fields, :class_name => 'Helpdesk::SectionField', :dependent => :destroy

  has_many :subscription_invoices
  has_many :dkim_category_change_activities

  has_many :user_companies
  has_many :cti_calls, :class_name => 'Integrations::CtiCall'
  has_many :cti_phones, :class_name => 'Integrations::CtiPhone'

  has_many :helpdesk_permissible_domains, :dependent => :destroy
  accepts_nested_attributes_for :helpdesk_permissible_domains, allow_destroy: true

  has_many :scheduled_tasks, :class_name => 'Helpdesk::ScheduledTask'
  has_many :outgoing_email_domain_categories, :dependent => :destroy
  has_many :authorizations, :class_name => '::Authorization'

  has_many :ticket_templates, :class_name => "Helpdesk::TicketTemplate"
  has_many :prime_templates,
            :class_name => "Helpdesk::TicketTemplate",
            :conditions =>['association_type != ?', Helpdesk::TicketTemplate::ASSOCIATION_TYPES_KEYS_BY_TOKEN[:child]]
  has_many :parent_templates,
            :class_name => "Helpdesk::TicketTemplate",
            :conditions => {:association_type => Helpdesk::TicketTemplate::ASSOCIATION_TYPES_KEYS_BY_TOKEN[:parent]}
  has_many :child_templates,
            :class_name => "Helpdesk::TicketTemplate",
            :conditions => {:association_type => Helpdesk::TicketTemplate::ASSOCIATION_TYPES_KEYS_BY_TOKEN[:child]}

  has_many :status_groups

  has_many :account_webhook_key, dependent: :destroy
  
  has_one :sandbox_job, :class_name => 'Admin::Sandbox::Job'
  
  has_many :ticket_subscriptions, :class_name => 'Helpdesk::Subscription'

  has_many :required_ticket_fields, :class_name => 'Helpdesk::TicketField', :conditions => "parent_id IS null AND required_for_closure IS true AND field_options NOT LIKE '%section: true%' AND field_type NOT IN ('default_subject','default_description','default_company')",
    :include => [:nested_ticket_fields, :picklist_values], :order => "helpdesk_ticket_fields.position"

  has_many :section_parent_fields, :class_name => 'Helpdesk::TicketField', :conditions => "parent_id is NULL AND field_type IN ('default_ticket_type' , 'custom_dropdown') AND field_options LIKE '%section_present: true%'", :include => [:nested_ticket_fields, {:picklist_values => :section}], :limit => Helpdesk::TicketField::SECTION_LIMIT

  has_one :collab_settings, :class_name => 'Collab::Setting'
  has_many :contact_notes
  has_many :company_notes

  has_many :reminders,
    :class_name => 'Helpdesk::Reminder',:dependent => :destroy
    
  has_many :bot_feedbacks, class_name: 'Bot::Feedback'
  has_many :bot_tickets, class_name: 'Bot::Ticket'
  has_many :bots, class_name: 'Bot', dependent: :destroy
  has_many :bot_feedback_mappings, class_name: 'Bot::FeedbackMapping'

  has_many :contact_notes
  has_many :company_notes
end
