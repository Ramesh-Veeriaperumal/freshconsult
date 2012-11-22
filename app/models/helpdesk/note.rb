class Helpdesk::Note < ActiveRecord::Base

  include ParserUtil
  include BusinessRulesObserver

  set_table_name "helpdesk_notes"

  belongs_to_account

  belongs_to :notable, :polymorphic => true

  belongs_to :user
  
  Max_Attachment_Size = 15.megabyte
  include Mobile::Actions::Note

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

  has_one :schema_less_note, :class_name => 'Helpdesk::SchemaLessNote',
          :foreign_key => 'note_id', :autosave => true, :dependent => :destroy

  attr_accessor :nscname, :disable_observer
  attr_protected :attachments, :notable_id
  
  before_create :validate_schema_less_note
  before_save :load_schema_less_note, :update_category
  after_create :update_content_ids, :update_parent, :add_activity, :fire_create_event               
  after_commit_on_create :update_ticket_states   

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
  
  named_scope :latest_facebook_message,
              :conditions => [" incoming = 1 and social_fb_posts.postable_type = 'Helpdesk::Note'"], 
              :joins => "INNER join social_fb_posts on helpdesk_notes.id = social_fb_posts.postable_id", 
              :order => "created_at desc"

  SOURCES = %w{email form note status meta twitter feedback facebook forward_email}
  
  SOURCE_KEYS_BY_TOKEN = Hash[*SOURCES.zip((0..SOURCES.size-1).to_a).flatten]
  
  ACTIVITIES_HASH = { Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN[:twitter] => "twitter" }

  TICKET_NOTE_SOURCE_MAPPING = { 
    Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN[:email] => SOURCE_KEYS_BY_TOKEN["email"] , 
    Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN[:portal] => SOURCE_KEYS_BY_TOKEN["email"] ,
    Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN[:phone] => SOURCE_KEYS_BY_TOKEN["email"] , 
    Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN[:forum] => SOURCE_KEYS_BY_TOKEN["email"] , 
    Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN[:twitter] => SOURCE_KEYS_BY_TOKEN["twitter"] , 
    Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN[:facebook] => SOURCE_KEYS_BY_TOKEN["facebook"] , 
    Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN[:chat] => SOURCE_KEYS_BY_TOKEN["email"]
  }

  CATEGORIES = {
    :customer_response => 1,
    :agent_private_response => 2,
    :agent_public_response => 3,
    :third_party_response => 4,
    :meta_response => 5
  }

  CATEGORIES.keys.each { |c| named_scope c.to_s.pluralize, 
    :joins => 'INNER JOIN helpdesk_schema_less_notes on helpdesk_schema_less_notes.note_id ='\
      ' helpdesk_notes.id and helpdesk_notes.account_id = helpdesk_schema_less_notes.account_id',
    :conditions => { 'helpdesk_schema_less_notes' => { :int_nc01 => CATEGORIES[c]}}
    }

  named_scope :created_between, lambda { |start_time, end_time| 
    {:conditions => ['helpdesk_notes.created_at >= ? and helpdesk_notes.created_at <= ?', 
      start_time, end_time]}
  }
  
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
  
  def feedback?
    source == SOURCE_KEYS_BY_TOKEN["feedback"]    
  end

  def private_note?
    source == SOURCE_KEYS_BY_TOKEN["note"] && private
  end
  
  def public_note?
    source == SOURCE_KEYS_BY_TOKEN["note"] && !private
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
  
  def to_json(options = {})
    options[:include] = [:attachments]
    options[:methods] = [:user_name]
    options[:except] = [:account_id,:notable_id,:notable_type]
    super options
  end

  def source_name
    SOURCES[source]
  end
  
  def to_liquid
    { 
      "commenter" => user,
      "body"      => liquidize_body,
      "body_text" => body
    }
  end
  
  def to_xml(options = {})
     options[:indent] ||= 2
      xml = options[:builder] ||= Builder::XmlMarkup.new(:indent => options[:indent])
      xml.instruct! unless options[:skip_instruct]
      super(:builder => xml, :skip_instruct => true,:include => :attachments,:except => [:account_id,:notable_id,:notable_type]) 
   end

  def create_fwd_note_activity(to_emails)
    notable.create_activity(user, 'activities.tickets.conversation.out_email.private.long',
            {'eval_args' => {'fwd_path' => ['fwd_path', 
                                {'ticket_id' => notable.display_id, 'comment_id' => id}]}, 'to_emails' => parse_to_comma_sep_emails(to_emails)},
            'activities.tickets.conversation.out_email.private.short')  
  end

  def respond_to?(attribute)
    return false if [:to_ary].include? attribute.to_sym
    super(attribute) || (load_schema_less_note && schema_less_note.respond_to?(attribute))
  end

  def save_response_time
    if human_note_for_ticket?
      ticket_state = notable.ticket_states   
      if user.customer?  
        ticket_state.requester_responded_at = created_at unless replied_by_third_party?
        ticket_state.inbound_count = notable.notes.visible.customer_responses.count+1
      elsif !private
        update_avg_response_time(ticket_state)
        ticket_state.agent_responded_at = created_at
        ticket_state.first_response_time ||= created_at
      end  
      ticket_state.save
    end
  end

  protected

    def update_content_ids
      header = self.header_info
      return if attachments.empty? or header.nil? or header[:content_ids].blank?
      
      attachments.each do |attach| 
        content_id = header[:content_ids][attach.content_file_name]
        self.body_html.sub!("cid:#{content_id}", attach.content.url) if content_id
      end
      
      # For rails 2.3.8 this was the only i found with which we can update an attribute without triggering any after or before callbacks
      Helpdesk::Note.update_all("body_html= #{ActiveRecord::Base.connection.quote(body_html)}", ["id=? and account_id=?", id, account_id]) if body_html_changed?
    end

    
    def update_parent #Maybe after_save?!
      return unless human_note_for_ticket?
      
      if user.customer?
        # Will re-open the ticket if it is not in open status and not feedback
        # Will re-open when the system gets a reply from third party and the ticket is not in resolved/closed statuses.
        unless notable.open? || feedback? || (replied_by_third_party? and !notable.active?)
          notable.status = Helpdesk::Ticketfields::TicketStatus::OPEN unless notable.import_id
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
      # syntax to move code from delayed jobs to resque.
      #Resque::MyNotifier.deliver_reply( notable.id, self.id , {:include_cc => true})
      notable.updated_at = created_at
      notable.save
    end
    
    def add_activity
      return if (!human_note_for_ticket? or zendesk_import?)
          
      if outbound_email?
        unless private?
          notable.create_activity(user, 'activities.tickets.conversation.out_email.long',
            {'eval_args' => {'reply_path' => ['reply_path', 
                                {'ticket_id' => notable.display_id, 'comment_id' => id}]}},
            'activities.tickets.conversation.out_email.short')
        end
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

    # The below 2 methods are used only for to_json 
    def user_name
      human_note_for_ticket? ? (user.name || user_info) : "-"
    end
    
    def user_info
      user.get_info if user
    end

    def validate_schema_less_note
      return unless human_note_for_ticket?
      
      if email_conversation?
        if schema_less_note.to_emails.blank?
          schema_less_note.to_emails = notable.requester.email 
          schema_less_note.from_email ||= account.primary_email_config.reply_email
        end
        schema_less_note.to_emails = fetch_valid_emails(schema_less_note.to_emails)
        schema_less_note.cc_emails = fetch_valid_emails(schema_less_note.cc_emails)
        schema_less_note.bcc_emails = fetch_valid_emails(schema_less_note.bcc_emails)
      elsif note?
        schema_less_note.to_emails = fetch_valid_emails(schema_less_note.to_emails)
      end
    end
    
  private
    def human_note_for_ticket?
      (self.notable.is_a? Helpdesk::Ticket) && user && (source != SOURCE_KEYS_BY_TOKEN['meta'])
    end

    def zendesk_import?
      Thread.current["zenimport_#{account_id}"]
    end
    
    def liquidize_body
      attachments.empty? ? body_html : 
        "#{body_html}\n\nAttachments :\n#{notable.liquidize_attachments(attachments)}\n"
    end

    # Replied by third pary to the forwarded email
    # Use this method only after checking human_note_for_ticket? and user.customer?
    def replied_by_third_party? 
      private_note? and incoming and notable.included_in_fwd_emails?(user.email)
    end

    def method_missing(method, *args, &block)
      begin
        super
      rescue NoMethodError => e
        logger.debug "method_missing :: args is #{args.inspect} and method:: #{method}"  
        if (load_schema_less_note && schema_less_note.respond_to?(method))
          args = args.first if args && args.is_a?(Array)
          (method.to_s.include? '=') ? schema_less_note.send(method, args) : schema_less_note.send(method)
        end
      end
    end

    def load_schema_less_note
      build_schema_less_note unless schema_less_note
      schema_less_note
    end

    def fire_create_event
      fire_event(:create) unless disable_observer
    end

    def update_category
      schema_less_note.category = CATEGORIES[:meta_response]
      return unless human_note_for_ticket?

      if user.customer?
        schema_less_note.category = replied_by_third_party? ? CATEGORIES[:third_party_response] : 
          CATEGORIES[:customer_response]
      else
        schema_less_note.category = private? ? CATEGORIES[:agent_private_response] : 
          CATEGORIES[:agent_public_response]
      end
    end 

    def update_ticket_states
      Resque.enqueue(Helpdesk::UpdateTicketStates, { :id => id }) unless private?
    end

    def update_avg_response_time(ticket_state)
      if ticket_state.first_response_time.nil?
        resp_time = created_at - notable.created_at
      else
        customer_resp = notable.notes.visible.customer_responses.
          created_between(ticket_state.agent_responded_at,created_at).first(
          :select => "helpdesk_notes.id,helpdesk_notes.created_at", 
          :order => "helpdesk_notes.created_at ASC")
        resp_time = created_at - customer_resp.created_at unless customer_resp.blank?
      end
      schema_less_note.update_attribute(:response_time_in_seconds, resp_time) unless resp_time.blank?

      notable_values = notable.notes.visible.agent_public_responses.first(
        :select => 'count(*) as outbounds, avg(helpdesk_schema_less_notes.int_nc02) as avg_resp_time')
      ticket_state.outbound_count = notable_values.outbounds
      ticket_state.avg_response_time = notable_values.avg_resp_time
    end

end
