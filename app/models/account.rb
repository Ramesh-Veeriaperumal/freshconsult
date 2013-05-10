class Account < ActiveRecord::Base
  require 'net/dns/resolver'
  require 'net/http' 
  require 'uri' 

  include Mobile::Actions::Account
  include Tire::Model::Search
  include Cache::Memcache::Account
  include ErrorHandle

  #rebranding starts
  serialize :preferences, Hash
  serialize :sso_options, Hash
  
  
  has_many :tickets, :class_name => 'Helpdesk::Ticket', :dependent => :delete_all
  has_many :notes, :class_name => 'Helpdesk::Note', :dependent => :delete_all
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
  
  has_one :data_export
  
  has_one :account_additional_settings

  has_one :account_configuration
  validates_associated :account_configuration, :on => :create
  
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
    
  #rebranding ends 

  RESERVED_DOMAINS = %W(  blog help chat smtp mail www ftp imap pop faq docs doc wiki team people india us talk 
                          upload download info lounge community forums ticket tickets tour about pricing bugs in out 
                          logs projects itil marketing partner store channel reseller resellers online 
                          contact admin #{AppConfig['admin_subdomain']} girish shan vijay parsu kiran shihab 
                          productdemo resources static static0 static1 static2 static3 static4 static5 
                          static6 static7 static8 static9 static10 )

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
  
  has_many :scn_automations, :class_name => 'VARule', :conditions => {:rule_type => VAConfig::SCENARIO_AUTOMATION, :active => true}, :order => "position"
  
  
  
  has_many :email_notifications
  has_many :groups
  has_many :agent_groups
  has_many :forum_categories, :order => "position"
  
  has_one :business_calendar

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

  #has_many :report_filters, :class_name=>'Reports::Filters::ReportsFilter'
  
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

  has_one  :es_enabled_account, :class_name => 'EsEnabledAccount'

  delegate :bcc_email, :ticket_id_delimiter, :email_cmds_delimeter, :pass_through_enabled, :to => :account_additional_settings

  has_many :subscription_events 
  
  #Scope restriction ends
  
  validates_format_of :domain, :with => /(?=.*?[A-Za-z])[a-zA-Z0-9]*\Z/
  validates_exclusion_of :domain, :in => RESERVED_DOMAINS, :message => "The domain <strong>{{value}}</strong> is not available."
  validates_length_of :helpdesk_url, :maximum=>255, :allow_blank => true
  validate :valid_domain?
  validate :valid_helpdesk_url? 
  validate :valid_sso_options?
  validate_on_create :valid_plan?
  validate_on_create :valid_payment_info?
  validate_on_create :valid_subscription?
  validates_uniqueness_of :google_domain ,:allow_blank => true, :allow_nil => true
  
  attr_accessible :name, :domain, :user, :plan, :plan_start, :creditcard, :address,:preferences,:logo_attributes,:fav_icon_attributes,:ticket_display_id,:google_domain ,:language
  attr_accessor :user, :plan, :plan_start, :creditcard, :address, :affiliate
  
  validates_numericality_of :ticket_display_id,
                            :less_than => 1000000,
                            :message => "Value must be less than six digits"
                            


  before_create :set_default_values
  before_update :check_default_values, :update_users_time_zone
    
  after_create :populate_features
  
  after_update :update_users_language
  #after_create :enable_elastic_search

  before_destroy :update_crm, :notify_totango

  after_commit_on_create :add_to_billing, :add_to_totango #, :create_search_index

  after_commit_on_update :clear_cache
  after_commit_on_destroy :clear_cache, :delete_search_index, :delete_reports_archived_data
  before_update :backup_changes
  before_destroy :backup_changes
  
  named_scope :active_accounts,
              :conditions => [" subscriptions.next_renewal_at > now() "], 
              :joins => [:subscription]

  named_scope :premium_accounts, {:conditions => {:premium => true}}
              
  named_scope :non_premium_accounts, {:conditions => {:premium => false}}
             

  
  Limits = {
    'agent_limit' => Proc.new {|a| a.full_time_agents.count }
  }
  
  Limits.each do |name, meth|
    define_method("reached_#{name}?") do
      return false unless self.subscription
      self.subscription.send(name) && self.subscription.send(name) <= meth.call(self)
    end
  end
  
  PLANS_AND_FEATURES = {
    :basic => { :features => [ :twitter, :custom_domain, :multiple_emails ] },
    
    :pro => {
      :features => [ :scenario_automations, :customer_slas, :business_hours, :forums, 
        :surveys, :scoreboard, :facebook, :timesheets, :css_customization ],
      :inherits => [ :basic ]
    },
    
    :premium => {
      :features => [ :multi_product, :multi_timezone , :multi_language, :advanced_reporting],
      :inherits => [ :pro ] #To make the hierarchy easier
    },
    
    :sprout => {
      :features => [ :scenario_automations, :business_hours ]
    },
    
    :blossom => {
      :features => [ :twitter, :facebook, :forums, :surveys , :scoreboard, :timesheets, 
        :custom_domain, :multiple_emails],
      :inherits => [ :sprout ]
    },
    
    :garden => {
      :features => [ :multi_product, :customer_slas, :multi_timezone , :multi_language, 
        :css_customization, :advanced_reporting ],
      :inherits => [ :blossom ]
    },

    :estate => {
      :features => [ :gamification, :agent_collision, :layout_customization, :round_robin ],
      :inherits => [ :garden ]
    },

    :sprout_classic => {
      :features => [ :scenario_automations, :business_hours, :custom_domain, :multiple_emails ]
    },
    
    :blossom_classic => {
      :features => [ :twitter, :facebook, :forums, :surveys , :scoreboard, :timesheets],
      :inherits => [ :sprout_classic ]
    },
    
    :garden_classic => {
      :features => [ :multi_product, :customer_slas, :multi_timezone , :multi_language, 
        :css_customization, :advanced_reporting ],
      :inherits => [ :blossom_classic ]
    },

    :estate_classic => {
      :features => [ :gamification, :agent_collision, :layout_customization, :round_robin ],
      :inherits => [ :garden_classic ]
    }

  }
  

  has_many :portal_templates,  :class_name=> 'Portal::Template'
  has_many :portal_pages,  :class_name=> 'Portal::Page'

# Default feature when creating account has been made true :surveys & ::survey_links $^&WE^%$E
    
  SELECTABLE_FEATURES = {:open_forums => true, :open_solutions => true, :auto_suggest_solutions => true,
    :anonymous_tickets =>true, :survey_links => true, :gamification_enable => true, :google_signin => true,
    :twitter_signin => true, :facebook_signin => true, :signup_link => true, :captcha => false , :portal_cc => false, 
    :personalized_email_replies => false, :enterprise_reporting => false}
    
  
  has_features do
    PLANS_AND_FEATURES.each_pair do |k, v|
      feature k, :requires => ( v[:inherits] || [] )
      v[:features].each { |f_n| feature f_n, :requires => [] } unless v[:features].nil?
      SELECTABLE_FEATURES.keys.each { |f_n| feature f_n }
    end
  end
  
  def installed_apps_hash
    installed_apps = installed_applications.all(:include => {:application => :widgets})
    installed_apps.inject({}) do |result,installed_app|
     result[installed_app.application.name.to_sym] = installed_app
     result
   end
  end

  def self.reset_current_account
    Thread.current[:account] = nil
  end
  
  def self.actual_customer_count
    Account.count('id',:distinct => true,:joins => :subscription_payments)
  end
  
  def can_add_agents?(agent_count)
    subscription.agent_limit.nil? or 
      (subscription.agent_limit >= (agent_count + full_time_agents.count))
  end
  
  def get_max_display_id
    ticket_dis_id = self.ticket_display_id
    max_dis_id = self.tickets.maximum('display_id')
    unless max_dis_id.nil?
      return  ticket_dis_id > max_dis_id ? ticket_dis_id : max_dis_id 
    end
    return 0
  end
  
  def check_default_values
    dis_max_id = get_max_display_id
    if self.ticket_display_id.blank? or (self.ticket_display_id < dis_max_id)
       self.ticket_display_id = dis_max_id
    end
  end
  
  def account_managers
    technicians.select do |user|
      user.privilege?(:manage_account)
    end
  end
  
  def update_users_time_zone #Ideally this should be called in after_update
    if time_zone_changed? && !features.multi_timezone?
      all_users.update_all(:time_zone => time_zone)
    end
  end
  
  def update_users_language
    all_users.update_all(:language => main_portal.language) if !features.multi_language? and main_portal
  end
  
  def needs_payment_info?
    if new_record?
      AppConfig['require_payment_info_for_trials'] && @plan && @plan.amount.to_f + @plan.setup_amount.to_f > 0
    else
      self.subscription.needs_payment_info?
    end
  end
  
  # Does the account qualify for a particular subscription plan
  # based on the plan's limits
  def qualifies_for?(plan)
    Subscription::Limits.keys.collect {|rule| rule.call(self, plan) }.all?
  end
  
  def active?
    !self.subscription.suspended?
  end
  
  def plan_name
    subscription.subscription_plan.canon_name
  end
  
  def domain
    @domain ||= self.full_domain.blank? ? '' : self.full_domain.split('.').first
  end
  
  def domain=(domain)
    @domain = domain
    self.full_domain = "#{domain}.#{AppConfig['base_domain'][RAILS_ENV]}"
  end
  
  def default_friendly_email
    primary_email_config.friendly_email
  end

  def default_friendly_email_personalize(user_name)
    primary_email_config.friendly_email_personalize(user_name)
  end
  
  def default_email
    primary_email_config.reply_email
  end
  
  def to_s
    name.blank? ? full_domain : "#{name} (#{full_domain})"
  end
  
  #Will be used as :host in emails
  def host
    main_portal.portal_url.blank? ? full_domain : main_portal.portal_url
  end
  
  def full_url
    "http://#{host}"
  end

  def url_protocol
    self.ssl_enabled? ? 'https' : 'http'
  end
  
  #Helpdesk hack starts here
  def reply_emails
    to_ret = (email_configs.collect { |ec| ec.friendly_email }).sort
    to_ret.empty? ? [ "support@#{full_domain}" ] : to_ret #to_email case will come, when none of the emails are active.. 
  end
  #HD hack ends..

  #Helpdesk hack starts here
  def reply_personalize_emails(user_name)
    to_ret = (email_configs.collect { |ec| ec.friendly_email_personalize(user_name) }).sort
    to_ret.empty? ? [ "support@#{full_domain}" ] : to_ret #to_email case will come, when none of the emails are active.. 
  end
  #HD hack ends..
  
  def support_emails
    to_ret = email_configs.collect { |ec| ec.reply_email }
    to_ret.empty? ? [ "support@#{full_domain}" ] : to_ret #to_email case will come, when none of the emails are active.. 
  end

  def portal_name #by Shan temp.
    main_portal.name
  end
  
   def language
      main_portal.language
   end
  
  #Sentient things start here, can move to lib some time later - Shan
  def self.current
    Thread.current[:account]
  end
  
  def make_current
    Thread.current[:account] = self
  end
  #Sentient ends here
  
  def populate_features
    add_features_of subscription.subscription_plan.name.downcase.to_sym
    SELECTABLE_FEATURES.each { |key,value| features.send(key).create  if value}
  end
  
  def add_features_of(s_plan)
    p_features = PLANS_AND_FEATURES[s_plan]
    unless p_features.nil?
      p_features[:inherits].each { |p_n| add_features_of(p_n) } unless p_features[:inherits].nil?

      features.send(s_plan).create
      p_features[:features].each { |f_n| features.send(f_n).create } unless p_features[:features].nil?
    end
  end
  
  def remove_features_of(s_plan)
    p_features = PLANS_AND_FEATURES[s_plan]
    unless p_features.nil?
      p_features[:inherits].each { |p_n| remove_features_of(p_n) } unless p_features[:inherits].nil?
      
      features.send(s_plan).destroy
      p_features[:features].each { |f_n| features.send(f_n).destroy } unless p_features[:features].nil?
    end
  end
  
  def ticket_type_values
    ticket_fields.type_field.first.picklist_values
  end
  
  def ticket_status_values
    ticket_statuses.visible
  end
  
  def has_multiple_products?
    !products.empty?
  end
  
  def kbase_email
    "kbase@#{full_domain}"
  end
  
  def has_credit_card?
    !subscription.card_number.nil?
  end

  def pass_through_enabled?
    pass_through_enabled
  end

  def create_search_index
    sandbox(0) {
      Tire.index(search_index_name) do
        create(
          :settings => {
            :analysis => {
              :filter => {
                :word_filter  => {
                       "type" => "word_delimiter",
                       "split_on_numerics" => false,
                       "generate_word_parts" => false,
                       "generate_number_parts" => false,
                       "split_on_case_change" => false,
                       "preserve_original" => true
                }
              },
              :analyzer => {
                :default => { :type => "custom", :tokenizer => "whitespace", :filter => [ "word_filter", "lowercase" ] },
                :include_stop => { :type => "custom", :tokenizer => "whitespace", :filter => [ "word_filter", "lowercase", "stop" ] }
              }
            }
          },
          :mappings => {
            :user => {
              :properties => {
                  :name => { :type => :string, :boost => 10, :store => 'yes' },
                  :email => { :type => :string, :boost => 50 },
                  :description => { :type => :string, :boost => 3 },
                  :job_title => { :type => :string, :boost => 4, :store => 'yes' },
                  :phone => { :type => :string },
                  :mobile => { :type => :string },
                  :customer => { :type => "object", 
                                 :properties => {
                                   :name => { :type => :string, :boost => 5, :store => 'yes' } 
                                 }
                               },
                  :twitter_id => { :type => :string },
                  :fb_profile_id => { :type => :string },
                  :account_id => { :type => :long, :include_in_all => false },
                  :deleted => { :type => :boolean, :include_in_all => false }
              }
            },
            :customer => {
              :properties => {
                  :name => { :type => :string, :boost => 10, :store => 'yes' },
                  :description => { :type => :string, :boost => 3 },
                  :note => { :type => :string, :boost => 4 },
                  :account_id => { :type => :long, :include_in_all => false }
              }
            },
            :"helpdesk/ticket" => {
              :properties => {
                :display_id => { :type => :long, :store => 'yes' },
                :subject => { :type => :string, :boost => 10, :store => 'yes' },
                :description => { :type => :string, :boost => 5, :store => 'yes' },
                :account_id => { :type => :long, :include_in_all => false },
                :responder_id => { :type => :long, :null_value => 0, :include_in_all => false },
                :group_id => { :type => :long, :null_value => 0, :include_in_all => false },
                :requester_id => { :type => :long, :include_in_all => false },
                :status => { :type => :long, :include_in_all => false },
                :spam => { :type => :boolean, :include_in_all => false },
                :deleted => { :type => :boolean, :include_in_all => false },
                :attachments => { :type => "object", 
                                  :properties => {
                                    :content_file_name => { :type => :string } 
                                  }
                                },
                :es_notes => { :type => "object", 
                               :properties => {
                                 :body => { :type => :string },
                                 :private => { :type => :boolean, :include_in_all => false },
                                 :attachments => { :type => :string }
                               }
                             },
                :es_from => { :type => :string },
                :to_emails => { :type => :string },
                :es_cc_emails => { :type => :string },
                :es_fwd_emails => { :type => :string },
                :company_id => { :type => :long, :null_value => 0, :include_in_all => false }
              }
            },
            :"solution/article" => {
              :properties => {
                :title => { :type => :string, :boost => 10, :store => 'yes' },
                :desc_un_html => { :type => :string, :boost => 6, :store => 'yes' },
                :tags => { :type => "object", 
                           :properties => {
                             :name => { :type => :string } 
                           }
                         },
                :user_id => { :type => :long, :include_in_all => false },
                :status => { :type => :integer, :include_in_all => false },
                :account_id => { :type => :long, :include_in_all => false },
                :folder => { :type => "object", 
                             :properties => { 
                               :category_id => { :type => :long, :include_in_all => false },
                               :visibility => { :type => :long, :include_in_all => false },
                               :customer_folders => { :type => "object",
                                                      :properties => {
                                                        :customer_id => { :type => :long, :include_in_all => false }  
                                                      }
                                                    }
                             }
                           },
                :attachments => { :type => "object", 
                                  :properties => {
                                    :content_file_name => { :type => :string } 
                                  }
                                }
              }
            },
            :topic => {
              :properties => {
                  :title => { :type => :string, :boost => 10, :store => 'yes' },
                  :user_id => { :type => :long, :include_in_all => false },
                  :posts => { :type => "object", 
                              :properties => {
                                :body => { :type => :string, :boost => 4, :store => 'yes' },
                                :attachments => { :type => "object", 
                                                  :properties => {
                                                    :content_file_name => { :type => :string } 
                                                  }
                                                }
                              }
                            },
                  :account_id => { :type => :long, :include_in_all => false },
                  :forum => { :type => "object", 
                              :properties => {
                                :forum_category_id => { :type => :long, :include_in_all => false },
                                :forum_visibility => { :type => :integer, :include_in_all => false },
                                :customer_forums => { :type => "object",
                                                       :properties => {
                                                         :customer_id => { :type => :long, :include_in_all => false }  
                                                       }
                                                     }
                              }
                            }
              }
            }
          }
        )
      end
    }
  end

  def enable_elastic_search
    EsEnabledAccount.create(:account_id => self.id, :index_name => self.search_index_name)
    MemcacheKeys.cache(ES_ENABLED_ACCOUNTS, EsEnabledAccount.all_es_indices)
  end

  def search_index_name
    "account-#{self.id}"
  end

  def delete_search_index
    es_enable_status = MemcacheKeys.fetch(MemcacheKeys::ES_ENABLED_ACCOUNTS) { EsEnabledAccount.all_es_indices }
    if es_enable_status.key?(self.id)
      Tire.index(search_index_name).delete
      es_enabled_account.disable_elastic_search
    end
  end

  def es_enabled?
    es_status = MemcacheKeys.fetch(ES_ENABLED_ACCOUNTS) { EsEnabledAccount.all_es_indices }
    es_status.key?(self.id) ? es_status[self.id] : false
  end
  
  protected
  
    def valid_domain?
      conditions = new_record? ? ['full_domain = ?', self.full_domain] : ['full_domain = ? and id <> ?', self.full_domain, self.id]
      self.errors.add(:domain, 'is not available') if self.full_domain.blank? || self.class.count(:conditions => conditions) > 0
    end
    
    def valid_sso_options?
      if self.sso_enabled?
        if self.sso_options[:login_url].blank?  
          self.errors.add(:sso_options, ', Please provide a valid login url') 
        #else
          #self.errors.add(:sso_options, ', Please provide a valid login url') if !external_url_is_valid?(self.sso_options[:login_url])
        end
      end
    end
    
    def external_url_is_valid?(url) 
      uri = URI.parse(url) 
      response = Net::HTTP.start(uri.host, uri.port) {|http| http.head(uri.path)} 
      response.is_a?(Net::HTTPSuccess) || response.is_a?(Net::HTTPRedirection) 
    rescue  ArgumentError
      false
    rescue Errno::ECONNREFUSED
      false
    rescue Errno::ETIMEDOUT
      false
    end 
    
    def valid_helpdesk_url?
      return true if (helpdesk_url.blank? || helpdesk_url == full_domain)

      errors.add_to_base(<<-eos
                          Host verification failed, please configure a CNAME record in your DNS server 
                          for '#{helpdesk_url}' and alias it to '#{full_domain}'
                        eos
                        ) unless (cname == full_domain)
    end
    
    def cname
      begin
        Net::DNS::Resolver.new.query(helpdesk_url).each_cname do |cn| 
          return cn.sub(/\.?$/, '') if cn.include?(full_domain)
        end
      rescue Exception => e
        Rails.logger.debug "Host name verification failed #{e.message}"
      end
    end
    
    def valid_payment_info?
      if needs_payment_info?
        unless @creditcard && @creditcard.valid?
          errors.add_to_base("Invalid payment information")
        end
        
        unless @address && @address.valid?
          errors.add_to_base("Invalid address")
        end
      end
    end
    
    def valid_plan?
      errors.add_to_base("Invalid plan selected.") unless @plan
    end
    
    def valid_subscription?
      return if errors.any? # Don't bother with a subscription if there are errors already
      self.build_subscription(:plan => @plan, :next_renewal_at => @plan_start, :creditcard => @creditcard, :address => @address, :affiliate => @affiliate)
      if !subscription.valid?
        errors.add_to_base("Error with payment: #{subscription.errors.full_messages.to_sentence}")
        return false
      end
    end
    
    def set_default_values
      self.time_zone = Time.zone.name if time_zone.nil? #by Shan temp.. to_s is kinda hack.
      self.helpdesk_name = name if helpdesk_name.nil?
      self.preferences = HashWithIndifferentAccess.new({:bg_color => "#efefef",:header_color => "#252525", :tab_color => "#006063"})
      self.shared_secret = generate_secret_token
      self.sso_options = set_sso_options_hash
    end
    
    def generate_secret_token
      Digest::MD5.hexdigest(Helpdesk::SHARED_SECRET + self.full_domain + Time.now.to_f.to_s).downcase
    end
    
    def set_sso_options_hash
      HashWithIndifferentAccess.new({:login_url => "",:logout_url => ""})
    end
        
    def subscription_next_renewal_at
      subscription.next_renewal_at
    end

    def backup_changes
      @old_object = self.clone
      @all_changes = self.changes.clone
      @all_changes.symbolize_keys!
    end


  private 

    def add_to_billing
      Resque.enqueue(Billing::AddToBilling, { :account_id => id })
    end

    def add_to_totango
      Resque.enqueue(CRM::Totango::TrialCustomer, {:account_id => id})
    end

    def update_crm
      Resque.enqueue(CRM::AddToCRM::DeletedCustomer, id)
    end

    def notify_totango
      Resque.enqueue(CRM::Totango::CanceledCustomer, id, full_domain)
    end

    def delete_reports_archived_data
      Resque.enqueue(Workers::DeleteArchivedData, {:account_id => id})
    end

end
