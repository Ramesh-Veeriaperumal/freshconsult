class Helpdesk::Ticket < ActiveRecord::Base

  belongs_to_account

  has_flexiblefields

  has_many_attachments

  has_many_dropboxes

  has_one :ticket_body, :class_name => 'Helpdesk::TicketBody', :dependent => :destroy

	has_one :schema_less_ticket, :class_name => 'Helpdesk::SchemaLessTicket', :dependent => :destroy

  belongs_to :email_config
  belongs_to :group
  belongs_to :responder, :class_name => 'User', :conditions => 'users.helpdesk_agent = true'

  belongs_to :requester, :class_name => 'User'
  
  belongs_to :sphinx_requester,
    :class_name => 'User',
    :foreign_key => 'requester_id',
    :conditions => 'helpdesk_tickets.account_id = users.account_id'

  has_many :notes,  :class_name => 'Helpdesk::Note', :as => 'notable', :dependent => :destroy

  has_many :public_notes,
    :class_name => 'Helpdesk::Note',
    :as => 'notable', :conditions => {:private =>  false, :deleted => false}
    
  has_many :sphinx_notes, 
    :class_name => 'Helpdesk::Note',
    :conditions => 'helpdesk_tickets.account_id = helpdesk_notes.account_id',
    :as => 'notable'
    
  has_many :activities, :class_name => 'Helpdesk::Activity', :as => 'notable', :dependent => :destroy

  has_many :reminders, :class_name => 'Helpdesk::Reminder', :dependent => :destroy

  has_many :subscriptions,  :class_name => 'Helpdesk::Subscription', :dependent => :destroy

  has_many :tag_uses, :as => :taggable, :class_name => 'Helpdesk::TagUse', :dependent => :destroy

  has_many :tags, :class_name => 'Helpdesk::Tag', :through => :tag_uses

  has_many :ticket_issues, :class_name => 'Helpdesk::TicketIssue', :dependent => :destroy

  has_many :issues, :class_name => 'Helpdesk::Issue', :through => :ticket_issues
    
  has_one :tweet, :as => :tweetable, :class_name => 'Social::Tweet', :dependent => :destroy
  
  has_one :fb_post, :as => :postable, :class_name => 'Social::FbPost',  :dependent => :destroy
    
  has_one :ticket_states, :class_name =>'Helpdesk::TicketState',:dependent => :destroy
  belongs_to :ticket_status, :class_name =>'Helpdesk::TicketStatus', :foreign_key => "status", :primary_key => "status_id"

  delegate :closed_at, :resolved_at, :first_response_time, :to => :ticket_states, :allow_nil => true
  delegate :active?, :open?, :is_closed, :closed?, :resolved?, :pending?, :onhold?, 
    :onhold_and_closed?, :to => :ticket_status, :allow_nil => true

  has_one :ticket_topic,:dependent => :destroy
  has_one :topic, :through => :ticket_topic
  
  has_many :survey_handles, :as => :surveyable, :dependent => :destroy
  has_many :survey_results, :as => :surveyable, :dependent => :destroy
  has_many :support_scores, :as => :scorable, :dependent => :destroy
  
  has_many :time_sheets, 
    :class_name => 'Helpdesk::TimeSheet',
    :as => 'workable',
    :dependent => :destroy,
    :order => "executed_at"

  accepts_nested_attributes_for :tweet, :fb_post, :ticket_body

end