class Helpdesk::Note < ActiveRecord::Base

  include ParserUtil
  include BusinessRulesObserver
  include Va::Observer::Util
  include Search::ElasticSearchIndex
  include Mobile::Actions::Note

  set_table_name "helpdesk_notes"

  concerned_with :associations, :constants, :callbacks

  attr_accessor :nscname, :disable_observer, :send_survey, :quoted_text
  attr_protected :attachments, :notable_id
  
  named_scope :newest_first, :order => "created_at DESC"
  named_scope :visible, :conditions => { :deleted => false } 
  named_scope :public, :conditions => { :private => false } 
  
  named_scope :latest_twitter_comment,
              :conditions => [" incoming = 1 and social_tweets.tweetable_type = 'Helpdesk::Note'"], 
              :joins => "INNER join social_tweets on helpdesk_notes.id = social_tweets.tweetable_id and helpdesk_notes.account_id = social_tweets.account_id", 
              :order => "created_at desc"
  
  named_scope :freshest, lambda { |account|
    { :conditions => ["deleted = ? and account_id = ? ", false, account], 
      :order => "helpdesk_notes.created_at DESC"
    }
  }
  named_scope :since, lambda { |last_note_id|
    { :conditions => ["helpdesk_notes.id > ? ", last_note_id], 
      :order => "helpdesk_notes.created_at DESC"
    }
  }
  
  named_scope :before, lambda { |first_note_id|
    { :conditions => ["helpdesk_notes.id < ? ", first_note_id], 
      :order => "helpdesk_notes.created_at DESC"
    }
  }
  
  named_scope :for_quoted_text, lambda { |first_note_id|
    { :conditions => ["source != ? AND helpdesk_notes.id < ? ",SOURCE_KEYS_BY_TOKEN["forward_email"], first_note_id], 
      :order => "helpdesk_notes.created_at DESC",
      :limit => 4
    }
  }
  
  named_scope :latest_facebook_message,
              :conditions => [" incoming = 1 and social_fb_posts.postable_type = 'Helpdesk::Note'"], 
              :joins => "INNER join social_fb_posts on helpdesk_notes.id = social_fb_posts.postable_id and helpdesk_notes.account_id = social_fb_posts.account_id", 
              :order => "created_at desc"

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
    options[:methods] = [:user_name,:source_name] unless options[:human].blank?
    options[:except] = [:account_id,:notable_id,:notable_type]
    super options
  end

  def source_name
    SOURCES[source]
  end
  
  def to_liquid
    # { 
    #   "commenter" => user,
    #   "body"      => liquidize_body,
    #   "body_text" => body
    # }
    Helpdesk::NoteDrop.new self
  end
  
  def body
    body
  end

  def body_html
    body_html
  end

  def full_text
    note_body ? note_body.full_text : read_attribute(:body)
  end

  def full_text_html
    note_body ? note_body.full_text_html : read_attribute(:body_html)
  end
 
  def body_with_note_body
    note_body ? note_body.body : read_attribute(:body)
  end
  alias_method_chain :body, :note_body

  def body_html_with_note_body
    note_body ? note_body.body_html : read_attribute(:body_html)
  end
  alias_method_chain :body_html, :note_body


  def to_xml(options = {})
     options[:indent] ||= 2
      xml = options[:builder] ||= Builder::XmlMarkup.new(:indent => options[:indent])
      xml.instruct! unless options[:skip_instruct]
      super(:builder => xml, :skip_instruct => true, :include=>:attachments, 
                          :except => [:account_id,:notable_id,:notable_type]) do |xml|
        unless options[:human].blank?
          xml.tag!(:source_name,self.source_name)
          xml.tag!(:user_name,user.name)
        end
      end
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
        update_note_level_resp_time(ticket_state)
        ticket_state.set_avg_response_time
        ticket_state.agent_responded_at = created_at
        ticket_state.set_first_response_time(created_at)
      end 
      ticket_state.save
    end
  end

  def trigger_observer model_changes
    @model_changes = model_changes.symbolize_keys unless model_changes.nil?
    filter_observer_events if user_present?
  end

  def update_note_level_resp_time(ticket_state)
    if ticket_state.first_response_time.nil?
      resp_time = created_at - notable.created_at
      resp_time_bhrs = Time.zone.parse(notable.created_at.to_s).
                          business_time_until(Time.zone.parse(created_at.to_s))
    else
      customer_resp = notable.notes.visible.customer_responses.
        created_between(ticket_state.agent_responded_at,created_at).first(
        :select => "helpdesk_notes.id,helpdesk_notes.created_at", 
        :order => "helpdesk_notes.created_at ASC")
      unless customer_resp.blank?
        resp_time = created_at - customer_resp.created_at
        resp_time_bhrs = Time.zone.parse(customer_resp.created_at.to_s).
                            business_time_until(Time.zone.parse(created_at.to_s))
      end
    end
    schema_less_note.update_attributes(:response_time_in_seconds => resp_time,
      :response_time_by_bhrs => resp_time_bhrs) unless resp_time.blank?
  end

  def kind
    return "private_note" if private_note?
    return "public_note" if public_note?
    return "forward" if fwd_email?
    "reply"
  end

  def liquidize_body
    attachments.empty? ? body_html : 
      "#{body_html}\n\nAttachments :\n#{notable.liquidize_attachments(attachments)}\n"
  end

  def to_indexed_json
    to_json({
            :root => "helpdesk/note",
            :methods => [ :notable_company_id, :notable_responder_id, :notable_group_id, :notable_deleted, :notable_spam, :notable_requester_id ],
            :only => [ :notable_id, :deleted, :private, :body, :account_id ], 
            :include => { 
                          :attachments => { :only => [:content_file_name] }
                        }
            })
  end

  protected

    def send_reply_email  
      add_cc_email     
      if fwd_email?
        Helpdesk::TicketNotifier.send_later(:deliver_forward, notable, self)
      elsif self.to_emails.present? or self.cc_emails.present? or self.bcc_emails.present? and !self.private
        Helpdesk::TicketNotifier.send_later(:deliver_reply, notable, self, {:include_cc => self.cc_emails.present? , 
                :send_survey => ((!self.send_survey.blank? && self.send_survey.to_i == 1) ? true : false),
                :quoted_text => self.quoted_text})
      end
    end

    def add_cc_email
      cc_email_hash_value = notable.cc_email_hash.nil? ? {:cc_emails => [], :fwd_emails => []} : notable.cc_email_hash
      if fwd_email?
        fwd_emails = self.to_emails | self.cc_emails | self.bcc_emails | cc_email_hash_value[:fwd_emails]
        fwd_emails.delete_if {|email| (email == notable.requester.email)}
        cc_email_hash_value[:fwd_emails]  = fwd_emails
      else
        cc_emails = self.cc_emails | cc_email_hash_value[:cc_emails]
        cc_emails.delete_if {|email| (email == notable.requester.email)}
        cc_email_hash_value[:cc_emails] = cc_emails
      end
      notable.cc_email = cc_email_hash_value    
    end
    
    # The below 2 methods are used only for to_json 
    def user_name
      human_note_for_ticket? ? (user.name || user_info) : "-"
    end
    
    def user_info
      user.get_info if user
    end

  private
    def human_note_for_ticket?
      (self.notable.is_a? Helpdesk::Ticket) && user && (source != SOURCE_KEYS_BY_TOKEN['meta'])
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
        Rails.logger.debug "method_missing :: args is #{args.inspect} and method:: #{method}"  
        if (load_schema_less_note && schema_less_note.respond_to?(method))
          args = args.first if args && args.is_a?(Array)
          (method.to_s.include? '=') ? schema_less_note.send(method, args) : schema_less_note.send(method)
        end
      end
    end
end
