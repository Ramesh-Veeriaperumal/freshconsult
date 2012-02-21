class Helpdesk::Note < ActiveRecord::Base
  set_table_name "helpdesk_notes"

  belongs_to :notable, :polymorphic => true  
  belongs_to :account
  belongs_to :user
  
  Max_Attachment_Size = 15.megabyte

  has_many :attachments,
    :as => :attachable,
    :class_name => 'Helpdesk::Attachment',
    :dependent => :destroy
    
  has_one :tweet,
    :as => :tweetable,
    :class_name => 'Social::Tweet',
    :dependent => :destroy
    
  has_one :fb_post,
    :as => :postable,
    :class_name => 'Social::FbPost',
    :dependent => :destroy
    
  has_one :survey_remark, :foreign_key => 'note_id', :dependent => :destroy

  attr_accessor :nscname
  attr_protected :attachments, :notable_id
  
  after_create :save_response_time, :update_parent, :add_activity, :update_in_bound_count
  accepts_nested_attributes_for :tweet , :fb_post
  
  unhtml_it :body
  
  named_scope :newest_first, :order => "created_at DESC"
  named_scope :visible, :conditions => { :deleted => false } 
  named_scope :public, :conditions => { :private => false } 
  
  named_scope :latest_twitter_comment,
              :conditions => [" incoming = 1 and social_tweets.tweetable_type = 'Helpdesk::Note'"], 
              :joins => "INNER join social_tweets on helpdesk_notes.id = social_tweets.tweetable_id", 
              :order => "created_at desc"
  
  
  named_scope :freshest, lambda { |account|
    { :conditions => ["deleted = ? and account_id = ? ", false, account], 
      :order => "helpdesk_notes.created_at DESC"
    }
  }

  SOURCES = %w{email form note status meta twitter feedback facebook}
  
  SOURCE_KEYS_BY_TOKEN = Hash[*SOURCES.zip((0..SOURCES.size-1).to_a).flatten]
  
  ACTIVITIES_HASH = { Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN[:twitter] => "twitter" }

  named_scope :exclude_source, lambda { |s| { :conditions => ['source <> ?', SOURCE_KEYS_BY_TOKEN[s]] } }

  validates_presence_of  :source, :notable_id
  validates_numericality_of :source
  validates_inclusion_of :source, :in => 0..SOURCES.size-1

  def status?
    source == SOURCE_KEYS_BY_TOKEN["status"]
  end
  
  def email?
    source == SOURCE_KEYS_BY_TOKEN["email"]
  end

  def note?
  	source == SOURCE_KEYS_BY_TOKEN["note"]
  end
  
  def note?
    source == SOURCE_KEYS_BY_TOKEN["note"]
  end
  
  def tweet?
    source == SOURCE_KEYS_BY_TOKEN["twitter"]    
  end

  def private_note?
    source == SOURCE_KEYS_BY_TOKEN["note"] && private
  end
  
  def public_note?
    source == SOURCE_KEYS_BY_TOKEN["note"] && !private
  end
  
  def inbound_email?
    source == SOURCE_KEYS_BY_TOKEN["email"] && incoming
  end
  
  def outbound_email?
    source == SOURCE_KEYS_BY_TOKEN["email"] && !incoming
  end 
  
  def to_liquid
    { 
      "commenter" => user,
      "body"      => liquidize_body
    }
  end
  
  def to_xml(options = {})
     options[:indent] ||= 2
      xml = options[:builder] ||= Builder::XmlMarkup.new(:indent => options[:indent])
      xml.instruct! unless options[:skip_instruct]
      super(:builder => xml, :skip_instruct => true,:include => :attachments,:except => [:account_id,:notable_id,:notable_type]) 
   end
    

  protected
    def save_response_time
      if human_note_for_ticket?
        ticket_state = notable.ticket_states     
        if "Customer".eql?(User::USER_ROLES_NAMES_BY_KEY[user.user_role])      
          ticket_state.requester_responded_at=Time.zone.now          
        else
          ticket_state.agent_responded_at=Time.zone.now unless private
          ticket_state.first_response_time=Time.zone.now if ticket_state.first_response_time.nil? && !private
        end  
        ticket_state.save
      end
    end
    
    def update_parent #Maybe after_save?!
      return unless human_note_for_ticket?
      
      if user.customer? 
        unless notable.open?
          notable.status = Helpdesk::Ticket::STATUS_KEYS_BY_TOKEN[:open]
          notification_type = EmailNotification::TICKET_REOPENED
        end 
        e_notification = account.email_notifications.find_by_notification_type(notification_type ||= EmailNotification::REPLIED_BY_REQUESTER)
        Helpdesk::TicketNotifier.send_later(:notify_by_email, (notification_type ||= 
              EmailNotification::REPLIED_BY_REQUESTER), notable, self) if notable.responder && e_notification.agent_notification?
      else
        e_notification = account.email_notifications.find_by_notification_type(EmailNotification::COMMENTED_BY_AGENT)
        Helpdesk::TicketNotifier.send_later(:notify_by_email, EmailNotification::COMMENTED_BY_AGENT, 
            notable, self) if source.eql?(SOURCE_KEYS_BY_TOKEN["note"]) && !private && e_notification.requester_notification?
      end
      
      notable.updated_at = created_at
      notable.save
    end
    
    def update_in_bound_count
     if incoming?
      inbound_count = notable.notes.find(:all,:conditions => {:incoming => true}).count
      notable.ticket_states.update_attribute(:inbound_count,inbound_count+=1)
     end
    end
      
    
    def add_activity
      return unless human_note_for_ticket?
      
      if outbound_email?
        notable.create_activity(user, 'activities.tickets.conversation.out_email.long',
            {'eval_args' => {'reply_path' => ['reply_path', 
                                {'ticket_id' => notable.display_id, 'comment_id' => id}]}},
            'activities.tickets.conversation.out_email.short')
      elsif inbound_email?
        notable.create_activity(user, 'activities.tickets.conversation.in_email.long', 
          {'eval_args' => {'email_response_path' => ['email_response_path', 
                                {'ticket_id' => notable.display_id, 'comment_id' => id}]}},
          'activities.tickets.conversation.in_email.short')
      else
        notable.create_activity(user, "activities.tickets.conversation.#{ACTIVITIES_HASH.fetch(source, "note")}.long", 
          {'eval_args' => {"#{ACTIVITIES_HASH.fetch(source, "comment")}_path" => ["#{ACTIVITIES_HASH.fetch(source, "comment")}_path", 
                                {'ticket_id' => notable.display_id, 'comment_id' => id}]}},
          "activities.tickets.conversation.#{ACTIVITIES_HASH.fetch(source, "note")}.short")
      end
    end
    
  private
    def human_note_for_ticket?
      (self.notable.is_a? Helpdesk::Ticket) && user && (source != SOURCE_KEYS_BY_TOKEN['meta'])
    end
    
    def liquidize_body
      attachments.empty? ? body_html : 
        "#{body_html}\n\nAttachments :\n#{notable.liquidize_attachments(attachments)}\n"
    end
end
