# encoding: utf-8
require 'digest/md5'

class Helpdesk::ArchiveNote < ActiveRecord::Base
  include ParserUtil
  include Search::V2::EsCallbacks

  self.primary_key = :id
  belongs_to_account
  belongs_to :user, :class_name => 'User'
  belongs_to :archive_ticket, :class_name => 'Helpdesk::ArchiveTicket'

  has_one :archive_note_association, 
  		    :class_name => 'Helpdesk::ArchiveNoteAssociation',
  		    :dependent => :destroy

  has_one :tweet, :as => :tweetable, :class_name => 'Social::Tweet', :dependent => :destroy
  has_one :fb_post, :as => :postable, :class_name => 'Social::FbPost',  :dependent => :destroy
  has_one :freshfone_call, :class_name => 'Freshfone::Call', :as => 'notable'

  has_many :shared_attachments,
           :as => :shared_attachable,
           :class_name => 'Helpdesk::SharedAttachment',
           :dependent => :destroy

  has_many :attachments_sharable, :through => :shared_attachments, :source => :attachment, 
           :conditions => ["helpdesk_attachments.account_id=helpdesk_shared_attachments.account_id"]
  has_many_attachments
  has_many_cloud_files

  has_many :inline_attachments, :class_name => "Helpdesk::Attachment", 
                                :conditions => { :attachable_type => "ArchiveNote::Inline" },
                                :foreign_key => "attachable_id",
                                :dependent => :destroy
  
 
  attr_protected :account_id
  accepts_nested_attributes_for :archive_note_association, :allow_destroy => true
  
  concerned_with :esv2_methods

  SOURCES = %w{email form note status meta twitter feedback facebook forward_email phone mobihelp mobihelp_app_review}

  NOTE_TYPE = { true => :private, false => :public }
  
  SOURCE_KEYS_BY_TOKEN = Hash[*SOURCES.zip((0..SOURCES.size-1).to_a).flatten]
  
  ACTIVITIES_HASH = { Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN[:twitter] => "twitter" }

  TICKET_NOTE_SOURCE_MAPPING = { 
    Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN[:email] => SOURCE_KEYS_BY_TOKEN["email"] , 
    Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN[:portal] => SOURCE_KEYS_BY_TOKEN["email"] ,
    Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN[:phone] => SOURCE_KEYS_BY_TOKEN["email"] , 
    Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN[:forum] => SOURCE_KEYS_BY_TOKEN["email"] , 
    Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN[:twitter] => SOURCE_KEYS_BY_TOKEN["twitter"] , 
    Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN[:facebook] => SOURCE_KEYS_BY_TOKEN["facebook"] , 
    Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN[:chat] => SOURCE_KEYS_BY_TOKEN["email"],
    Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN[:mobihelp] => SOURCE_KEYS_BY_TOKEN["mobihelp"],
    Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN[:feedback_widget] => SOURCE_KEYS_BY_TOKEN["email"]
  }

  CATEGORIES = {
    :customer_response => 1,
    :agent_private_response => 2,
    :agent_public_response => 3,
    :third_party_response => 4,
    :meta_response => 5
  }
  
  scope :newest_first, :order => "id DESC"
  scope :public, :conditions => { :private => false } 
  scope :private, :conditions => { :private => true } 
   
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
    { :conditions => ["source != ? AND archive_notes.id < ? ",SOURCE_KEYS_BY_TOKEN["forward_email"], first_note_id], 
      :order => "archive_notes.id DESC",
      :limit => 4
    }
  }
  
  scope :latest_facebook_message,
              :conditions => [" incoming = 1 and social_fb_posts.postable_type = 'Helpdesk::Note'"], 
              :joins => "INNER join social_fb_posts on archive_notes.id = social_fb_posts.postable_id and archive_notes.account_id = social_fb_posts.account_id", 
              :order => "id desc"

  scope :exclude_source, lambda { |s| { :conditions => ['source <> ?', SOURCE_KEYS_BY_TOKEN[s]] } }

  def status?
    source == SOURCE_KEYS_BY_TOKEN["status"]
  end
  
  def email?
    source == SOURCE_KEYS_BY_TOKEN["email"]
  end

  def note?
    source == SOURCE_KEYS_BY_TOKEN["note"]
  end
  
  def tweet?
    source == SOURCE_KEYS_BY_TOKEN["twitter"]    
  end
  
  def feedback?
    source == SOURCE_KEYS_BY_TOKEN["feedback"]    
  end

  def meta?
    source == SOURCE_KEYS_BY_TOKEN["meta"]
  end

  def private_note?
    source == SOURCE_KEYS_BY_TOKEN["note"] && private
  end
  
  def public_note?
    source == SOURCE_KEYS_BY_TOKEN["note"] && !private
  end

  def phone_note?
    source == SOURCE_KEYS_BY_TOKEN["phone"]
  end
  
  def inbound_email?
    email? && incoming
  end
  
  def outbound_email?
    email_conversation? && !incoming
  end 
  
  def fwd_email?
    source == SOURCE_KEYS_BY_TOKEN["forward_email"]
  end

  def email_conversation?
    email? or fwd_email?
  end

  def kind
    return "private_note" if private_note?
    return "public_note" if public_note?
    return "forward" if fwd_email?
    return "phone_note" if phone_note?
    "reply"
  end

  def from_email
    association = archive_note_association.associations_data["helpdesk_notes_association"]
    association["schema_less_note"]["from_email"]
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

end