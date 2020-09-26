class Helpdesk::Ticket < ActiveRecord::Base

  belongs_to_account

  has_flexiblefields class_name: 'Flexifield', as: :flexifield_set, inverse_of: :flexifield_set

  has_one :ticket_field_data, inverse_of: :flexifield_set, dependent: :destroy, as: :flexifield_set
  accepts_nested_attributes_for :ticket_field_data

  has_many_attachments

  has_many :inline_attachments, :class_name => "Helpdesk::Attachment", 
                                :conditions => { :attachable_type => "Ticket::Inline" },
                                :foreign_key => "attachable_id",
                                :dependent => :destroy,
                                :before_add => :set_inline_attachable_type

  has_many :file_field_attachments, class_name: 'Helpdesk::Attachment', inverse_of: :attachable,
                                    conditions: { attachable_type: AttachmentConstants::FILE_TICKET_FIELD },
                                    foreign_key: 'attachable_id',
                                    dependent: :destroy,
                                    before_add: [proc { |ticket, attachment| self.set_file_field_attachments(ticket, attachment) }]

  has_many_cloud_files

  has_many :shared_attachments,
    :as => :shared_attachable,
    :class_name => 'Helpdesk::SharedAttachment',
    :dependent => :destroy

  has_many :attachments_sharable, :through => :shared_attachments, :source => :attachment

  has_one :ticket_body, class_name: 'Helpdesk::TicketBody', dependent: :destroy
  accepts_nested_attributes_for :ticket_body, update_only: true

  has_one :schema_less_ticket, class_name: 'Helpdesk::SchemaLessTicket', dependent: :destroy
  delegate :scheduler_trace_id, :update_scheduler_trace_id, :reset_scheduler_trace_id, to: :schema_less_ticket

  belongs_to :email_config

  belongs_to :group
  belongs_to :internal_group, :class_name => "Group"
  belongs_to :responder, :class_name => 'User', :conditions => 'users.helpdesk_agent = true'
  belongs_to :internal_agent, :class_name => "User", :conditions => {:helpdesk_agent => true}

  belongs_to :requester, :class_name => 'User'

  belongs_to :company, :foreign_key => :owner_id

  has_many :notes, :inverse_of => :notable, :class_name => 'Helpdesk::Note', :as => 'notable', :dependent => :destroy # TODO-RAILS3 Need to cross check, :foreign_key => :id

  has_many :mobihelp_notes,  :class_name => 'Helpdesk::Note',
    :as => 'notable', :conditions => {:private =>  false, :deleted => false},
    :order => "CREATED_AT DESC LIMIT 10"

  has_many :public_notes,
    :class_name => 'Helpdesk::Note',
    :as => 'notable', :conditions => {:private =>  false, :deleted => false}

  has_one :summary, 
    :class_name => 'Helpdesk::Note',
    :as => 'notable', :conditions => {:source => Helpdesk::Source.note_source_keys_by_token['summary']}

  has_many :activities, :class_name => 'Helpdesk::Activity', :as => 'notable', :dependent => :destroy

  has_many :reminders, :class_name => 'Helpdesk::Reminder', :dependent => :destroy

  has_many :subscriptions,  :class_name => 'Helpdesk::Subscription', :dependent => :destroy

  has_many :tag_uses, :as => :taggable, :class_name => 'Helpdesk::TagUse', :dependent => :destroy

  # Added after_add, after_remove for activities
  # Issue reported for after_remove callback in rails 4
  # Tested similar association in 4.2.6 and working fine
  # https://github.com/rails/rails/issues/14365 
  has_many :tags, :class_name => 'Helpdesk::Tag', :through => :tag_uses, 
    :after_remove => :remove_tag_activity , :after_add => :add_tag_activity, :dependent => :destroy

  has_one :tweet, :as => :tweetable, :class_name => 'Social::Tweet', :dependent => :destroy
  
  has_one :fb_post, :as => :postable, :class_name => 'Social::FbPost',  :dependent => :destroy

  has_one :parent, :through => :schema_less_ticket

  has_one :archive_child, :class_name => 'Helpdesk::ArchiveChild', :dependent => :destroy

  has_one :archive_ticket, :through => :archive_child

  has_one :ticket_states, :class_name =>'Helpdesk::TicketState',:dependent => :destroy
  belongs_to :ticket_status, :class_name =>'Helpdesk::TicketStatus', :foreign_key => "status", :primary_key => "status_id"

  belongs_to :skill, :class_name => 'Admin::Skill', :foreign_key => 'sl_skill_id'
  delegate :active?, :open?, :is_closed, :closed?, :resolved?, :pending?, :onhold?, 
    :onhold_and_closed?, :to => :ticket_status, :allow_nil => true

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

  has_many :time_sheets_with_users, :class_name => 'Helpdesk::TimeSheet', :as => 'workable',
    :order => "executed_at", :include => {:user => :avatar}

  has_one :freshfone_call, :class_name => 'Freshfone::Call', :as => 'notable'
  has_one :freshcaller_call, :class_name => 'Freshcaller::Call', :as => 'notable'
  
  accepts_nested_attributes_for :tweet, :fb_post

  has_one :article_ticket, :as => :ticketable, :dependent => :destroy
  has_one :article, :through => :article_ticket
  has_one :ebay_question, :as => :questionable, :class_name => 'Ecommerce::EbayQuestion', :dependent => :destroy
  has_one :ebay_account, :class_name => 'Ecommerce::EbayAccount', :through => :ebay_question
  has_one :cti_call, :class_name => 'Integrations::CtiCall', :as => 'recordable', :dependent => :destroy
  
  has_many :linked_applications, :through => :integrated_resources,
           :source => :installed_application

  has_one :bot_ticket, class_name: 'Bot::Ticket', dependent: :destroy
  has_one :bot_response, class_name: 'Bot::Response', dependent: :destroy

  has_many :canned_form_handles, :class_name => 'Admin::CannedFormHandle', :dependent => :destroy
  delegate :agent_availability, :out_of_office_days, to: :responder, allow_nil: true

  belongs_to :ticket_source, class_name: 'Helpdesk::Source', foreign_key: 'source', primary_key: 'account_choice_id', inverse_of: :tickets

  private

  def set_inline_attachable_type(inline_attachment)
    inline_attachment.attachable_type = "Ticket::Inline"
  end

  def ticket_field_data_with_safe_access
    if ticket_field_data_without_safe_access.blank?
      build_ticket_field_data
      ticket_field_data.flexifield_def = account.ticket_field_def
    end
    ticket_field_data_without_safe_access
  end

    def self.set_file_field_attachments(ticket, attachment)
      return if attachment.attachable_type == AttachmentConstants::FILE_TICKET_FIELD

      attachment.attachable_type = AttachmentConstants::FILE_TICKET_FIELD
      file_fields = Account.current.ticket_fields_from_cache.select { |field| field.field_type == Helpdesk::TicketField::CUSTOM_FILE }
      custom_fields_hash = ticket.custom_fields_hash
      field = file_fields.find { |x| custom_fields_hash.key?(x.name) && custom_fields_hash[x.name] == attachment.id }
      attachment.description = field.column_name
    end
    alias_method_chain :ticket_field_data, :safe_access
end
