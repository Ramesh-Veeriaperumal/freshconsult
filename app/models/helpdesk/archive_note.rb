# encoding: utf-8
require 'digest/md5'

class Helpdesk::ArchiveNote < ActiveRecord::Base
  include ParserUtil

  self.primary_key = :id
  belongs_to_account
  belongs_to :user, :class_name => 'User'
  belongs_to :archive_ticket, :class_name => 'Helpdesk::ArchiveTicket'

  has_one :tweet, :as => :tweetable, :class_name => 'Social::Tweet', :dependent => :destroy
  has_one :fb_post, :as => :postable, :class_name => 'Social::FbPost',  :dependent => :destroy
  has_one :freshfone_call, :class_name => 'Freshfone::Call', :as => 'notable'
  has_one :freshcaller_call, :class_name => 'Freshcaller::Call', :as => 'notable'

  has_many :shared_attachments,
           :as => :shared_attachable,
           :class_name => 'Helpdesk::SharedAttachment',
           :dependent => :destroy

  has_many :attachments_sharable, :through => :shared_attachments, :source => :attachment
  has_many_attachments
  has_many_cloud_files

  has_many :inline_attachments, :class_name => "Helpdesk::Attachment", 
                                :conditions => { :attachable_type => "ArchiveNote::Inline" },
                                :foreign_key => "attachable_id",
                                :dependent => :destroy

  belongs_to :note_source, class_name: 'Helpdesk::Source', foreign_key: 'source', primary_key: 'account_choice_id', inverse_of: :archive_notes
 
  attr_protected :account_id

  concerned_with :attributes, :s3, :esv2_methods
  
  scope :exclude_source, lambda { |s| { :conditions => ['source <> ?', Account.current.helpdesk_sources.note_source_keys_by_token[s]] } }
  scope :visible, :conditions => { :deleted => false }
  
  # Callbacks will be executed in the order in which they have been included. 
  # Included rabbitmq callbacks at the last
  include RabbitMq::Publisher

  def self.const_missing(constant_name, *args)  
    if [:SOURCES, :SOURCE_KEYS_BY_TOKEN, :ACTIVITIES_HASH, :TICKET_NOTE_SOURCE_MAPPING, :EXCLUDE_SOURCE].include?(constant_name)  
      new_constant_name = 'Helpdesk::ArchiveNote::'+ constant_name.to_s + '_1'  
      Rails.logger.debug("Warning accessing note constants :: #{new_constant_name}")  
      Rails.logger.debug(caller[0..10].join("\n"))  
      new_constant_name.constantize 
    else 
      Rails.logger.debug("Constant missing #{constant_name}") 
      Rails.logger.debug(caller[0..10].join("\n"))  
      super(constant_name, *args) 
    end 
  end 

  SOURCES_1 = %w{email form note status meta twitter feedback facebook    
               forward_email phone mobihelp mobihelp_app_review summary automation_rule_forward}  

  SOURCE_KEYS_BY_TOKEN_1 = Hash[*SOURCES_1.zip((0..SOURCES_1.size-1).to_a).flatten]   

  ACTIVITIES_HASH_1 = { Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN_1[:twitter] => "twitter" }   

  EXCLUDE_SOURCE_1 =  %w{meta summary}.freeze   

  TICKET_NOTE_SOURCE_MAPPING_1 = {    
    Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN_1[:email] => SOURCE_KEYS_BY_TOKEN_1["email"] ,     
    Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN_1[:portal] => SOURCE_KEYS_BY_TOKEN_1["email"] ,    
    Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN_1[:phone] => SOURCE_KEYS_BY_TOKEN_1["email"] ,     
    Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN_1[:forum] => SOURCE_KEYS_BY_TOKEN_1["email"] ,     
    Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN_1[:twitter] => SOURCE_KEYS_BY_TOKEN_1["twitter"] ,     
    Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN_1[:facebook] => SOURCE_KEYS_BY_TOKEN_1["facebook"] ,     
    Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN_1[:chat] => SOURCE_KEYS_BY_TOKEN_1["email"],   
    Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN_1[:mobihelp] => SOURCE_KEYS_BY_TOKEN_1["mobihelp"],    
    Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN_1[:feedback_widget] => SOURCE_KEYS_BY_TOKEN_1["email"]   
  }.freeze

  NOTE_TYPE = { true => :private, false => :public }

  CATEGORIES = {
    :customer_response => 1,
    :agent_private_response => 2,
    :agent_public_response => 3,
    :third_party_response => 4,
    :meta_response => 5
  }
  SCHEMA_LESS_FIELDS = {
    :note_properties => "text_nc02"
  }
  
  scope :newest_first, :order => "id DESC"
  scope :public, :conditions => { :private => false } 
  scope :private, :conditions => { :private => true } 

  scope :public_notes, -> { where(private: false) }
  scope :private_notes, -> { where(private: true) }

  scope :latest_twitter_comment,
              :conditions => [" incoming = 1 and social_tweets.tweetable_type =
 'Helpdesk::Note'"],
              :joins => "INNER join social_tweets on archive_notes.id = social_tweets.tweetable_id and archive_notes.account_id = social_tweets.account_id", 
              :order => "id desc"
  
  scope :freshest, lambda { |account|
    { :conditions => ["account_id = ? ", account], 
      :order => "archive_notes.id DESC"
    }
  }
  scope :since, lambda { |last_note_id|
    { :conditions => ["archive_notes.id > ? ", last_note_id], 
      :order => "archive_notes.id DESC"
    }
  }
  
  scope :before, lambda { |first_note_id|
    { :conditions => ["archive_notes.id < ? ", first_note_id], 
      :order => "archive_notes.id DESC"
    }
  }
  
  scope :for_quoted_text, lambda { |first_note_id|
    { :conditions => ["source != ? AND archive_notes.id < ? ", Account.current.helpdesk_sources.note_source_keys_by_token["forward_email"], first_note_id], 
      :order => "archive_notes.id DESC",
      :limit => 4
    }
  }
  
  scope :latest_facebook_message,
              :conditions => [" incoming = 1 and social_fb_posts.postable_type = 'Helpdesk::Note'"], 
              :joins => "INNER join social_fb_posts on archive_notes.id = social_fb_posts.postable_id and archive_notes.account_id = social_fb_posts.account_id", 
              :order => "id desc"

  scope :exclude_source, lambda { |s| { :conditions => ['source <> ?', Account.current.helpdesk_sources.note_source_keys_by_token[s]] } }

  scope :conversations, lambda { |preload_options = nil, order_conditions = nil, limit = nil|
    {
      :conditions => ["source NOT IN (?) and deleted = false", Account.current.helpdesk_sources.note_exclude_sources.map{|s| Account.current.helpdesk_sources.note_source_keys_by_token[s]}],
      :order => order_conditions,
      :include => preload_options,
      :limit => limit
    }
  }

  def status?
    source == Account.current.helpdesk_sources.note_source_keys_by_token["status"]
  end
  
  def email?
    source == Account.current.helpdesk_sources.note_source_keys_by_token["email"]
  end

  def note?
    source == Account.current.helpdesk_sources.note_source_keys_by_token["note"]
  end
  
  def tweet?
    source == Account.current.helpdesk_sources.note_source_keys_by_token["twitter"]    
  end
  
  def feedback?
    source == Account.current.helpdesk_sources.note_source_keys_by_token["feedback"]    
  end

  def meta?
    source == Account.current.helpdesk_sources.note_source_keys_by_token["meta"]
  end

  def private_note?
    source == Account.current.helpdesk_sources.note_source_keys_by_token["note"] && private
  end
  
  def public_note?
    source == Account.current.helpdesk_sources.note_source_keys_by_token["note"] && !private
  end

  def phone_note?
    source == Account.current.helpdesk_sources.note_source_keys_by_token["phone"]
  end

  def summary_note?
    source == Account.current.helpdesk_sources.note_source_keys_by_token["summary"]
  end
  
  def summary_note?
    source == Account.current.helpdesk_sources.note_source_keys_by_token["summary"]
  end

  def inbound_email?
    email? && incoming
  end
  
  def outbound_email?
    email_conversation? && !incoming
  end 
  
  def fwd_email?
    user_fwd_email? || automation_fwd_email?
  end

  def user_fwd_email?
    source == Account.current.helpdesk_sources.note_source_keys_by_token["forward_email"]
  end

  def automation_fwd_email?
    source == Account.current.helpdesk_sources.note_source_keys_by_token["automation_rule_forward"]
  end

  def email_conversation?
    email? or fwd_email?
  end

  def automated_note_for_ticket?
    (source == Account.current.helpdesk_sources.note_source_keys_by_token["automation_rule"])
  end

  def kind
    return "private_note" if private_note?
    return "public_note" if public_note?
    return "forward" if fwd_email?
    return "phone_note" if phone_note?
    return "summary" if summary_note?
    "reply"
  end

  def from_email
    association = archive_note_association.associations_data["helpdesk_notes_association"]
    association["schema_less_note"]["from_email"]
  end

  def cc_emails
    association = archive_note_association.associations_data["helpdesk_notes_association"]
    association["schema_less_note"]["cc_emails"]["cc_emails"]
  end

  def to_emails
    association = archive_note_association.associations_data["helpdesk_notes_association"]
    association["schema_less_note"]["to_emails"]
  end
  
  def bcc_emails 
    association = archive_note_association.associations_data["helpdesk_notes_association"]
    association["schema_less_note"]["bcc_emails"]
  end

  def body
    archive_note_association.body
  end

  def body_html
    archive_note_association.body_html
  end

  def all_attachments
    shared_attachments=self.attachments_sharable
    individual_attachments = self.attachments
    shared_attachments+individual_attachments
  end
  
  def to_liquid
    @archive_note_drop ||= Helpdesk::ArchiveNoteDrop.new self    
  end

  def support_email
    hash = parse_email_text(self.from_email)
    hash[:email]
  end

  def as_json(options = {})
    return super(options) unless options[:tailored_json].blank?
    options[:methods] = Array.new if options[:methods].nil?
    options[:methods].push(:attachments, :support_email)
    options[:methods].push(:user_name, :source_name) unless options[:human].blank?
    options[:except] = [:account_id]
    super options
  end

  def to_xml(options = {})
    options[:indent] ||= 2
    xml = options[:builder] ||= ::Builder::XmlMarkup.new(:indent => options[:indent])
    xml.instruct! unless options[:skip_instruct]
    super(:builder => xml, :root => "helpdesk-archived-note", :skip_instruct => true, :include =>:attachments, :methods => [:support_email, :body, :body_html],
                        :except => [:account_id, :archive_ticket_id]) do |xml|
      unless options[:human].blank?
        xml.tag!(:source_name, self.source_name)
        xml.tag!(:user_name, user.name)
      end
    end
  end

  # All helpdesk_note associations
  def helpdesk_notes_association
    archive_note_association.associations_data["helpdesk_notes_association"]
  end

  def survey_remark
    helpdesk_notes_association and helpdesk_notes_association["survey_remark"]
  end
  alias :custom_survey_remark :survey_remark

  def survey_result
    if helpdesk_notes_association and helpdesk_notes_association["survey_remark"]
      if Account.current.features?(:custom_survey)
        CustomSurvey::SurveyResult.find_by_id(helpdesk_notes_association["survey_remark"]["survey_result_id"])
      else
        SurveyResult.find_by_id(helpdesk_notes_association["survey_remark"]["survey_result_id"])
      end
    end
  end
  
  def full_text_html
    helpdesk_notes_association["note_old_body"]["full_text_html"]
  end

  def notable
    archive_ticket
  end

  def parent
    helpdesk_notes_association["schema_less_note"]
  end

  SCHEMA_LESS_FIELDS.each do |alias_attribute, field_name|
    define_method "#{alias_attribute}" do
      parent[field_name]
    end
  end

  def last_modified_user_id
    note_properties["last_modified_user_id"] unless note_properties.nil?
  end

  def last_modified_timestamp
    Time.zone.parse(note_properties["last_modified_timestamp"].to_s).to_datetime unless note_properties.nil?
  end

  def deleted?
    archive_note_association.associations_data["helpdesk_tickets"]["deleted"]
  end  


end
