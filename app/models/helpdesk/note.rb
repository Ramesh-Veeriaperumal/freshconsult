class Helpdesk::Note < ActiveRecord::Base
  self.primary_key= :id

  include ParserUtil
  include BusinessRulesObserver
  include Va::Observer::Util
  include Search::ElasticSearchIndex
  include Mobile::Actions::Note
  include Helpdesk::Services::Note
  include ApiWebhooks::Methods
  include BusinessHoursCalculation

  SCHEMA_LESS_ATTRIBUTES = ['from_email', 'to_emails', 'cc_emails', 'bcc_emails', 'header_info', 'category', 
                            'response_time_in_seconds', 'response_time_by_bhrs', 'email_config_id', 'subject']

  self.table_name =  "helpdesk_notes"

  concerned_with :associations, :constants, :callbacks, :riak, :s3, :mysql, :attributes, :rabbitmq, :esv2_methods
  text_datastore_callbacks :class => "note"
  spam_watcher_callbacks :user_column => "user_id"
  attr_accessor :nscname, :disable_observer, :send_survey, :include_surveymonkey_link, :quoted_text, 
                :skip_notification
  attr_protected :attachments, :notable_id

  has_many :shared_attachments,
           :as => :shared_attachable,
           :class_name => 'Helpdesk::SharedAttachment',
           :dependent => :destroy

  has_many :attachments_sharable, :through => :shared_attachments, :source => :attachment, :conditions => ["helpdesk_attachments.account_id=helpdesk_shared_attachments.account_id"]

  delegate :to_emails, :cc_emails, :bcc_emails, :subject, :to => :schema_less_note

  scope :newest_first, :order => "created_at DESC"
  scope :visible, :conditions => { :deleted => false } 
  scope :public, :conditions => { :private => false } 
  scope :private, :conditions => { :private => true } 
   
  scope :last_traffic_cop_note,
    :conditions => ["private = ? or incoming = ?",false,true],
    :order => "created_at DESC",
    :limit => 1

  scope :latest_twitter_comment,
              :conditions => [" incoming = 1 and social_tweets.tweetable_type =
 'Helpdesk::Note'"],
              :joins => "INNER join social_tweets on helpdesk_notes.id = social_tweets.tweetable_id and helpdesk_notes.account_id = social_tweets.account_id", 
              :order => "created_at desc"
  
  scope :freshest, lambda { |account|
    { :conditions => ["deleted = ? and account_id = ? ", false, account], 
      :order => "helpdesk_notes.created_at DESC"
    }
  }
  scope :since, lambda { |last_note_id|
    { :conditions => ["helpdesk_notes.id > ? ", last_note_id], 
      :order => "helpdesk_notes.created_at DESC"
    }
  }
  
  scope :before, lambda { |first_note_id|
    { :conditions => ["helpdesk_notes.id < ? ", first_note_id], 
      :order => "helpdesk_notes.created_at DESC"
    }
  }
  
  scope :for_quoted_text, lambda { |first_note_id|
    { :conditions => ["source != ? AND helpdesk_notes.id < ? ",SOURCE_KEYS_BY_TOKEN["forward_email"], first_note_id], 
      :order => "helpdesk_notes.created_at DESC",
      :limit => 4
    }
  }
  
  scope :latest_facebook_message,
              :conditions => [" incoming = 1 and social_fb_posts.postable_type = 'Helpdesk::Note'"], 
              :joins => "INNER join social_fb_posts on helpdesk_notes.id = social_fb_posts.postable_id and helpdesk_notes.account_id = social_fb_posts.account_id", 
              :order => "created_at desc"

  CATEGORIES.keys.each { |c| scope c.to_s.pluralize, 
    :joins => 'INNER JOIN helpdesk_schema_less_notes on helpdesk_schema_less_notes.note_id ='\
      ' helpdesk_notes.id and helpdesk_notes.account_id = helpdesk_schema_less_notes.account_id',
    :conditions => { 'helpdesk_schema_less_notes' => { :int_nc01 => CATEGORIES[c]}}
    }

  scope :created_between, lambda { |start_time, end_time| 
    {:conditions => ['helpdesk_notes.created_at >= ? and helpdesk_notes.created_at <= ?', 
      start_time, end_time]}
  }
  
  scope :exclude_source, lambda { |s| { :conditions => ['source <> ?', SOURCE_KEYS_BY_TOKEN[s]] } }

  validates_presence_of  :source, :notable_id
  validates_numericality_of :source
  validates_inclusion_of :source, :in => 0..SOURCES.size-1
  validates :user, presence: true, if: -> {user_id.present?}

  def all_attachments
    shared_attachments=self.attachments_sharable
    individual_attachments = self.attachments
    shared_attachments+individual_attachments
  end


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
  
  def fb_note?
    source == SOURCE_KEYS_BY_TOKEN["facebook"]
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

  def ecommerce?
    source == SOURCE_KEYS_BY_TOKEN["ecommerce"] && self.ebay_question.present?
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
  
  def can_split?
    (self.incoming and self.notable) and (self.fb_post ? self.fb_post.can_comment? : true) and (self.private ? user.customer? : true) and (!self.mobihelp?) and !user.blocked? and (!self.ecommerce?)
  end

  def as_json(options = {})
    return super(options) unless options[:tailored_json].blank?
    options[:methods] = Array.new if options[:methods].nil?
    options[:methods].push(:attachments, :support_email)
    options[:methods].push(:user_name, :source_name) unless options[:human].blank?
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

  def third_party_response?
    schema_less_note.category == CATEGORIES[:third_party_response]
  end

  def reply_to_forward?
    schema_less_note.category == CATEGORIES[:reply_to_forward]
  end

  def support_email
    hash = parse_email_text(self.schema_less_note.try(:from_email))
    hash[:email]
  end
  
  def to_xml(options = {})
     options[:indent] ||= 2
      xml = options[:builder] ||= ::Builder::XmlMarkup.new(:indent => options[:indent])
      xml.instruct! unless options[:skip_instruct]
      super(:builder => xml, :root => "helpdesk-note", :skip_instruct => true, :include =>:attachments, :methods => [:support_email],
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

  def respond_to?(attribute, include_private=false)
    return false if [:empty?, :to_ary].include? attribute.to_sym
    super(attribute, include_private) || SCHEMA_LESS_ATTRIBUTES.include?(attribute.to_s.chomp("=").chomp("?"))
  end

  def save_response_time
    if human_note_for_ticket?
      ticket_state = notable.ticket_states   
      if notable.customer_performed?(user)
        if notable.outbound_email?
          ticket_state.requester_responded_at = created_at  if can_set_requester_response?
        else
          ticket_state.requester_responded_at = created_at unless (replied_by_third_party? or consecutive_customer_response?)
        end
        #Hack - for outbound emails, the initial description is not considererd as inbound so not counting that for inbound_count column
        ticket_state.inbound_count = notable.outbound_email? ? notable.notes.visible.customer_responses.count : notable.notes.visible.customer_responses.count+1
      elsif !private
        update_note_level_resp_time(ticket_state)
        
        ticket_state.set_avg_response_time
        if notable.outbound_email?
          customer_resp = first_customer_note(notable,notable.created_at,created_at)
          ticket_state.agent_responded_at = created_at if ticket_state.requester_responded_at
          ticket_state.set_first_response_time(created_at, customer_resp.created_at) if customer_resp.present?
        else
          ticket_state.agent_responded_at = created_at
          ticket_state.set_first_response_time(created_at)
        end
      end 
      ticket_state.save
    end
  end

  def trigger_observer model_changes
    @model_changes = model_changes.symbolize_keys unless model_changes.nil?
    filter_observer_events if user_present?
  end

  def update_note_level_resp_time(ticket_state)
    resp_time_bhrs,resp_time = [nil,nil]

    if ticket_state.first_response_time.nil?
      if notable.outbound_email?
        resp_time,resp_time_bhrs = outbound_note_level_response
      else
        notable.schema_less_ticket.set_first_response_id(id)
        resp_time,resp_time_bhrs = calculate_response_time(notable)
      end
    else
      customer_resp = first_customer_note(notable,ticket_state.agent_responded_at, self.created_at)
      resp_time,resp_time_bhrs = calculate_response_time(customer_resp) unless customer_resp.blank?
    end
    
    schema_less_note.update_attributes(:response_time_in_seconds => resp_time,
      :response_time_by_bhrs => resp_time_bhrs) unless resp_time.blank?
  end

  def kind
    return "reply_to_forward" if reply_to_forward? 
    return "private_note" if private_note?
    return "public_note" if public_note?
    return "forward" if fwd_email?
    return "phone_note" if phone_note?
    "reply"
  end

  def liquidize_body
    all_attachments.empty? ? body_html : 
      "#{body_html}\n\nAttachments :\n#{notable.liquidize_attachments(all_attachments)}\n"
  end
  
  def fb_reply_allowed?
    self.fb_post and self.incoming and self.notable.is_facebook? and self.fb_post.can_comment? 
  end

  def load_note_reply_cc
    if self.third_party_response?
      [self.cc_emails, self.from_email.to_a]
    elsif (self.reply_to_forward? || self.fwd_email?)
      [self.cc_emails, self.to_emails.to_a]
    else
      [[], []]
    end
  end
  
  # Instance level spam watcher condition
  # def rl_enabled?
  #   self.account.features?(:resource_rate_limit) && !self.instance_variable_get(:@skip_resource_rate_limit)
  # end

  protected

    def send_reply_email  
      if fwd_email?
        Helpdesk::TicketNotifier.send_later(:deliver_forward, notable, self) unless only_kbase?
      elsif self.to_emails.present? or self.cc_emails.present? or self.bcc_emails.present? and !self.private
        Helpdesk::TicketNotifier.send_later(:deliver_reply, notable, self, {:include_cc => self.cc_emails.present? ,
                :send_survey => ((!self.send_survey.blank? && self.send_survey.to_i == 1) ? true : false),
                :quoted_text => self.quoted_text,
                :include_surveymonkey_link => (self.include_surveymonkey_link.present? && self.include_surveymonkey_link.to_i==1)})
      end
    end

    def add_cc_email
      cc_email_hash_value = notable.cc_email_hash.nil? ? Helpdesk::Ticket.default_cc_hash : notable.cc_email_hash
      if fwd_email? || reply_to_forward?
        fwd_emails = self.to_emails | self.cc_emails | self.bcc_emails | cc_email_hash_value[:fwd_emails]
        fwd_emails.delete_if {|email| (email == notable.requester.email)}
        cc_email_hash_value[:fwd_emails]  = fwd_emails
      else
        cc_email_hash_value[:reply_cc] = self.cc_emails.reject {|email| (email == notable.requester.email)}
        tkt_cc_emails = self.cc_emails | cc_email_hash_value[:cc_emails]
        cc_emails = tkt_cc_emails.map { |email| parse_email(email)[:email] }.compact.uniq
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

    def mobihelp?
      self.source == SOURCE_KEYS_BY_TOKEN['mobihelp'] || self.source == SOURCE_KEYS_BY_TOKEN['mobihelp_app_review']
    end

  private
  
    # def rl_exceeded_operation
    #   key = "RL_%{table_name}:%{account_id}:%{user_id}" % {:table_name => self.class.table_name, :account_id => self.account_id,
    #           :user_id => self.user_id }
    #   $spam_watcher.rpush(ResourceRateLimit::NOTIFY_KEYS, key)
    # end

    def human_note_for_ticket?
      (self.notable.is_a? Helpdesk::Ticket) && user && (source != SOURCE_KEYS_BY_TOKEN['meta'])
    end

    # Replied by third pary to the forwarded email
    # Use this method only after checking human_note_for_ticket? and user.customer?
    def replied_by_third_party? 
      private_note? and incoming and notable.included_in_fwd_emails?(user.email)
    end

    def consecutive_customer_response?
      notable.ticket_states.consecutive_customer_response?
    end

    def notable_cc_email_updated?(old_cc, new_cc)
      return !old_cc.eql?(new_cc) if old_cc.nil?
      [:cc_emails, :fwd_emails].any? { |f| 
                                       !(old_cc[f].uniq.sort.eql?(new_cc[f].uniq.sort))
                                     }
    end

    def method_missing(method, *args, &block)
      begin
        super
      rescue NoMethodError => e
        Rails.logger.debug "method_missing :: args is #{args.inspect} and method:: #{method}"  
        if(SCHEMA_LESS_ATTRIBUTES.include?(method.to_s.chomp("=").chomp("?")))
          load_schema_less_note
          args = args.first if args && args.is_a?(Array)
          (method.to_s.include? '=') ? schema_less_note.send(method, args) : schema_less_note.send(method)
        end
      end
    end

    def only_kbase?
      (self.to_emails | self.cc_emails | self.bcc_emails).compact == [self.account.kbase_email]
    end

    def first_customer_note(ticket, from_time, to_time)
      notable.notes.visible.customer_responses.
          created_between(from_time,to_time).first(
          :select => "helpdesk_notes.id,helpdesk_notes.created_at", 
          :order => "helpdesk_notes.created_at ASC")
    end

    def outbound_note_level_response
      customer_resp = first_customer_note(notable,notable.created_at, self.created_at)
      unless customer_resp.blank?
        resp_time,resp_time_bhrs = calculate_response_time(customer_resp)
        notable.schema_less_ticket.set_first_response_id(id)
      end
      [resp_time, resp_time_bhrs]
    end

    def calculate_response_time(object)
      resp_time = self.created_at - object.created_at
      resp_time_bhrs = BusinessCalendar.execute(self.notable) {
          calculate_time_in_bhrs(object.created_at, self.created_at, notable.group)
        }
      [resp_time, resp_time_bhrs]
    end

    def can_set_requester_response?
      ticket_state = notable.ticket_states
      if ticket_state.agent_responded_at.nil?
        ticket_state.requester_responded_at.nil?
      elsif !ticket_state.requester_responded_at.nil?
        ticket_state.agent_responded_at > ticket_state.requester_responded_at
      else
        false
      end
    end

end
