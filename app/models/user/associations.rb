class User < ActiveRecord::Base

  belongs_to :company, :foreign_key => 'customer_id'
  has_many :user_companies, :class_name => 'UserCompany', 
                            :before_remove => :update_user_companies,
                            :before_add => :update_user_companies,
                            :dependent => :destroy
  accepts_nested_attributes_for :user_companies, :allow_destroy => true
  has_one :default_user_company, :class_name => 'UserCompany', :conditions => { :default => true }, :autosave => true
  accepts_nested_attributes_for :default_user_company, :allow_destroy => true
  
  has_many :companies, :class_name => 'Company', 
                       :through => :user_companies, 
                       :foreign_key => 'user_id' do 
    def sorted
      to_ret = self.to_a
      user = proxy_association.owner
      return [] if to_ret.empty? || !user.default_user_company.present?
      to_ret.sort_by! { |c| [c.name] }
      default_company_pos = to_ret.find_index { |c| c.id == user.default_user_company.company_id }
      to_ret.insert(0, to_ret.delete_at(default_company_pos))
      to_ret
    end
  end

  belongs_to :parent, :class_name =>'User', :foreign_key => :string_uc04

  has_many :authorizations, :dependent => :destroy

  has_many :votes, :dependent => :destroy
  has_many :day_pass_usages, :dependent => :destroy
  has_custom_fields :class_name => 'ContactFieldData', :discard_blank => false # coz of schema_less_user_columns

  has_many :user_emails, class_name: 'UserEmail', validate: true, dependent: :destroy, order: 'primary_role desc', before_remove: :update_user_emails, before_add: :update_user_emails
  has_many :verified_emails, :class_name =>'UserEmail', :dependent => :destroy, :conditions => { :verified => true }
  has_one :primary_email, :class_name => 'UserEmail', :conditions => { :primary_role => true }, :autosave => true

  accepts_nested_attributes_for :user_emails, :reject_if => proc {|att| att['email'].blank? }, :allow_destroy => true

  delegate :email, :to => :primary_email, :allow_nil => true, :prefix => :actual
  
  has_many :time_sheets , :class_name =>'Helpdesk::TimeSheet' , :dependent => :destroy
   
  has_many :email_notification_agents,  :dependent => :destroy
  
  has_many :user_roles, :class_name => 'UserRole'
  has_many :user_roles, class_name: 'UserRole'
  has_many :roles,
          through: :user_roles,
          class_name: 'Role',
          after_add: :touch_add_role_change,
          after_remove: :touch_remove_role_change,
          autosave: true

  has_many :tag_uses,
    :as => :taggable,
    :class_name => 'Helpdesk::TagUse',
    :dependent => :destroy

  has_many :tags, 
    :class_name => 'Helpdesk::Tag',
    :through => :tag_uses,
    :after_remove => :update_user_tags,
    :after_add => :update_user_tags

  has_many :google_contacts, :dependent => :destroy

  has_one :avatar,
    :as => :attachable,
    :class_name => 'Helpdesk::Attachment',
    :dependent => :destroy

  accepts_nested_attributes_for :avatar, :allow_destroy => true

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

  has_many :contact_reminders, class_name: 'Helpdesk::Reminder',
    dependent: :destroy, foreign_key: 'contact_id', inverse_of: :contact
    
  has_many :tickets , :class_name => 'Helpdesk::Ticket' ,:foreign_key => "requester_id" 
  has_many :archive_tickets , :class_name => 'Helpdesk::ArchiveTicket' ,:foreign_key => "requester_id" 
  has_many :notes, :class_name => 'Helpdesk::Note'
  has_many :activities, :class_name => 'Helpdesk::Activity'
  
  has_many :open_tickets, :class_name => 'Helpdesk::Ticket' ,:foreign_key => "requester_id",
  :conditions => {:status => [OPEN,PENDING]},
  :order => "created_at desc"
  
  has_one :agent , :class_name => 'Agent' , :foreign_key => "user_id", :dependent => :destroy
  has_one :full_time_support_agent, :class_name => 'Agent', :foreign_key => "user_id", :conditions => { 
      :occasional => false, :agent_type => 1  } #no direct use, need this in account model for pass through.
  
  has_many :agent_groups, class_name: 'AgentGroup', foreign_key: 'user_id', conditions: { write_access: true }
  has_many :all_agent_groups, class_name: 'AgentGroup', foreign_key: 'user_id'
  has_many :groups, :through => :agent_groups, :dependent => :destroy #https://github.com/rails/rails/issues/7618#issuecomment-11682784

  has_many :user_skills, :order => :rank, :class_name => 'UserSkill' , :foreign_key => "user_id"
  has_many :skills, :through => :user_skills, :source => :skill, :order => :'user_skills.rank', :dependent => :destroy
  accepts_nested_attributes_for :user_skills, :allow_destroy => true

  has_many :achieved_quests, :dependent => :delete_all

  has_many :quests, :through => :achieved_quests
  
  has_many :canned_responses , :class_name =>'Admin::CannedResponse' 
  
  #accepts_nested_attributes_for :agent
  accepts_nested_attributes_for :google_contacts  # Added to save the company while importing user from google contacts.

  delegate :available?, :toggle_availability?, :agent_availability, :out_of_office_days, to: :agent, allow_nil: true

  # SavageBeast associations moved here
  has_many :moderatorships, :dependent => :destroy
  has_many :forums, :through => :moderatorships, :order => "#{Forum.table_name}.name"
  has_many :posts

  has_many :recent_posts, :class_name => 'Post', :conditions => ["#{Post.table_name}.published = ?", true], :order => "created_at desc", :limit => 10
  has_many :topics
  has_many :monitorships
  has_many :monitored_topics, :through => :monitorships, :conditions => ["#{Monitorship.table_name}.active = ?", true], :order => "#{Topic.table_name}.replied_at desc", :source => :monitorable, :source_type => "Topic"

  has_many :report_filters, :class_name => 'Helpdesk::ReportFilter'
  has_many :data_exports
  has_many :scheduled_exports
  has_many :scheduled_ticket_exports, :dependent => :destroy

  has_many :custom_survey_results, class_name: 'CustomSurvey::SurveyResult', foreign_key: 'customer_id'

  has_many :survey_results, class_name: 'SurveyResult', foreign_key: 'customer_id'

  has_many :user_accesses, class_name: 'Helpdesk::UserAccess'
  has_many :accesses,
           through: :user_accesses,
           source: :helpdesk_access,
           class_name: 'Helpdesk::Access'


  has_one :forum_moderator , :class_name => 'ForumModerator' , :foreign_key => "moderator_id", :dependent => :destroy

  has_many :ebay_questions, :class_name => 'Ecommerce::EbayQuestion'

  has_one :cti_phone, :class_name =>'Integrations::CtiPhone', :foreign_key => 'agent_id', :dependent => :nullify

  has_many :scheduled_tasks, :class_name => 'Helpdesk::ScheduledTask'

  has_one :qna_insight, :class_name => 'Helpdesk::QnaInsight'

  has_many :contact_notes, :dependent => :destroy

  has_many :announcements, class_name: 'DashboardAnnouncement', dependent: :destroy

  delegate :long_uc01, :boolean_uc01, :string_uc07, to: :contact_field_data
end
