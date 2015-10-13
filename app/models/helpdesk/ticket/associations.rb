class Helpdesk::Ticket < ActiveRecord::Base

  belongs_to_account

  has_flexiblefields :class_name => 'Flexifield', :as => :flexifield_set

  has_many_attachments

  has_many :inline_attachments, :class_name => "Helpdesk::Attachment", 
                                :conditions => { :attachable_type => "Ticket::Inline" },
                                :foreign_key => "attachable_id",
                                :dependent => :destroy

  has_many_cloud_files

  has_one :ticket_old_body, :class_name => 'Helpdesk::TicketOldBody', 
                            :dependent => :destroy, :autosave => false
                            
	has_one :schema_less_ticket, :class_name => 'Helpdesk::SchemaLessTicket', :dependent => :destroy

  belongs_to :email_config
  belongs_to :group
  belongs_to :responder, :class_name => 'User', :conditions => 'users.helpdesk_agent = true'

  belongs_to :requester, :class_name => 'User'

  has_many :notes, :inverse_of => :notable, :class_name => 'Helpdesk::Note', :as => 'notable', :dependent => :destroy # TODO-RAILS3 Need to cross check, :foreign_key => :id

  has_many :mobihelp_notes,  :class_name => 'Helpdesk::Note',
    :as => 'notable', :conditions => {:private =>  false, :deleted => false},
    :order => "CREATED_AT DESC LIMIT 10"

  has_many :public_notes,
    :class_name => 'Helpdesk::Note',
    :as => 'notable', :conditions => {:private =>  false, :deleted => false}
    
  has_many :activities, :class_name => 'Helpdesk::Activity', :as => 'notable', :dependent => :destroy

  has_many :reminders, :class_name => 'Helpdesk::Reminder', :dependent => :destroy

  has_many :subscriptions,  :class_name => 'Helpdesk::Subscription', :dependent => :destroy

  has_many :tag_uses, :as => :taggable, :class_name => 'Helpdesk::TagUse', :dependent => :destroy

  has_many :tags, :class_name => 'Helpdesk::Tag', :through => :tag_uses

  has_many :ticket_issues, :class_name => 'Helpdesk::TicketIssue', :dependent => :destroy

  has_many :issues, :class_name => 'Helpdesk::Issue', :through => :ticket_issues
    
  has_one :tweet, :as => :tweetable, :class_name => 'Social::Tweet', :dependent => :destroy
  
  has_one :fb_post, :as => :postable, :class_name => 'Social::FbPost',  :dependent => :destroy

  has_one :parent, :through => :schema_less_ticket

  has_one :archive_child, :class_name => 'Helpdesk::ArchiveChild', :dependent => :destroy

  has_one :archive_ticket, :through => :archive_child

  has_one :ticket_states, :class_name =>'Helpdesk::TicketState',:dependent => :destroy
  belongs_to :ticket_status, :class_name =>'Helpdesk::TicketStatus', :foreign_key => "status", :primary_key => "status_id"

  delegate :closed_at, :resolved_at, :first_response_time, :to => :ticket_states, :allow_nil => true
  delegate :active?, :open?, :is_closed, :closed?, :resolved?, :pending?, :onhold?, 
    :onhold_and_closed?, :to => :ticket_status, :allow_nil => true

  delegate :trashed, :to_emails, :product, :to => :schema_less_ticket, :allow_nil => true

  has_one :ticket_topic, :as => :ticketable, :dependent => :destroy
  has_one :topic, :through => :ticket_topic

  has_many :survey_handles, :as => :surveyable, :dependent => :destroy
  has_many :survey_results, :as => :surveyable, :dependent => :destroy
  has_many :custom_survey_handles, :class_name => 'CustomSurvey::SurveyHandle', :as => :surveyable, :dependent => :destroy
  has_many :custom_survey_results, :class_name => 'CustomSurvey::SurveyResult', :as => :surveyable, :dependent => :destroy
  has_many :support_scores, :as => :scorable, :dependent => :destroy
  has_many :integrated_resources, :as => :local_integratable, :class_name => 'Integrations::IntegratedResource', :dependent => :destroy
  
  has_many :time_sheets, 
    :class_name => 'Helpdesk::TimeSheet',
    :as => 'workable',
    :dependent => :destroy,
    :order => "executed_at"

  has_one :freshfone_call, :class_name => 'Freshfone::Call', :as => 'notable'

  has_one :mobihelp_ticket_info, :class_name => 'Mobihelp::TicketInfo' , :dependent => :destroy
  
  accepts_nested_attributes_for :tweet, :fb_post , :mobihelp_ticket_info

  has_one :article_ticket, :as => :ticketable, :dependent => :destroy
  has_one :article, :through => :article_ticket
  has_one :ebay_question, :as => :questionable, :class_name => 'Ecommerce::EbayQuestion', :dependent => :destroy
  has_one :ebay_account, :class_name => 'Ecommerce::EbayAccount', :through => :ebay_question
  
end
