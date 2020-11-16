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
  include MemcacheKeys

  SCHEMA_LESS_ATTRIBUTES = ['from_email', 'to_emails', 'cc_emails', 'bcc_emails', 'header_info', 'category',
                            'response_time_in_seconds', 'response_time_by_bhrs', 'email_config_id', 'subject',
                            'last_modified_user_id', 'last_modified_timestamp', 'sentiment','dynamodb_range_key',
                            'failure_count', 'quoted_parsing_done', 'import_id', 'thank_you_note', 'on_state_time',
                            'response_violated'
                          ]

  self.table_name = 'helpdesk_notes'

  concerned_with :associations, :constants, :callbacks, :rabbitmq, :esv2_methods, :presenter

  #zero_downtime_migration_methods :methods => {:remove_columns => ["body", "body_html"] }

  attr_accessor :nscname, :disable_observer, :send_survey, :include_surveymonkey_link, :quoted_text,
                :skip_notification, :changes_for_observer, :disable_observer_rule, :last_note_id,
                :post_to_forum_topic, :import_note, :model_changes, :activity_type

  attr_protected :attachments, :notable_id

  has_many :shared_attachments,
           :as => :shared_attachable,
           :class_name => 'Helpdesk::SharedAttachment',
           :dependent => :destroy

  has_many :attachments_sharable, :through => :shared_attachments, :source => :attachment

  delegate :to_emails, :cc_emails, :bcc_emails, :subject, :cc_emails_hash, :to => :schema_less_note
  scope :newest_first, -> { order("created_at DESC,id DESC") }
  scope :oldest_first, -> { order('created_at ASC,id ASC') }
  scope :visible, -> { where(deleted: false) }
  scope :public_notes, -> { where(private: false) }
  scope :private_notes, -> { where(private: true) }

  scope :latest_twitter_comment, -> {
    where(" incoming = 1 AND social_tweets.tweetable_type = 'Helpdesk::Note'").
    joins("INNER join social_tweets on helpdesk_notes.id = social_tweets.tweetable_id and helpdesk_notes.account_id = social_tweets.account_id").
    order('created_at DESC')
  }

  scope :freshest, ->(account){
    where(deleted: false, account_id: account.id).
    order('helpdesk_notes.created_at DESC')
  }

  scope :since, ->(last_note_id){
    where(['helpdesk_notes.id > ? ', last_note_id]).
    order('helpdesk_notes.created_at DESC')
  }

  scope :created_since, -> (last_note_id, last_note_created_at) {
    where(["helpdesk_notes.id != ? AND helpdesk_notes.created_at >= ?", 
            last_note_id, last_note_created_at])
  }

  scope :updated_since, ->(last_note_id, last_note_updated_at) {
    where(['helpdesk_notes.id != ? AND helpdesk_notes.updated_at >= ?',
      last_note_id, last_note_updated_at])
  }

  scope :conversations, -> (preload_options = nil, order_conditions = nil, limit = nil) {
    where(['source NOT IN (?) and deleted = false', conversation_sources]).
    order(order_conditions).
    includes(preload_options).
    limit(limit)
  }

  scope :before, -> (first_note_id) {
    where(["helpdesk_notes.id < ? ", first_note_id]).
    order('helpdesk_notes.created_at DESC')
  }
  
  scope :for_quoted_text, -> (first_note_id) {
    where(["source != ? AND helpdesk_notes.id < ? ", Account.current.helpdesk_sources.note_source_keys_by_token["forward_email"], first_note_id]).
    order("helpdesk_notes.created_at DESC").
    limit(4)
  }
  
  scope :parent_facebook_comments, ->(ancestry = nil, preload_options = nil, order_conditions = nil, limit = nil) {
    where(['helpdesk_notes.source NOT IN (?) and helpdesk_notes.deleted = false', conversation_sources])
      .where(['(social_fb_posts.postable_type = "Helpdesk::Note" and social_fb_posts.ancestry = (?)) OR social_fb_posts.id is null', ancestry])
      .joins('LEFT JOIN social_fb_posts on helpdesk_notes.id = social_fb_posts.postable_id and helpdesk_notes.account_id = social_fb_posts.account_id')
      .order(order_conditions)
      .includes(preload_options)
      .limit(limit)
  }

  scope :child_facebook_comments, ->(ancestry = nil, preload_options = nil, order_conditions = nil, limit = nil) {
    where(['helpdesk_notes.source NOT IN (?) and helpdesk_notes.deleted = false', conversation_sources])
      .where(['social_fb_posts.postable_type = "Helpdesk::Note" and social_fb_posts.ancestry = (?)', ancestry])
      .joins('INNER JOIN social_fb_posts on helpdesk_notes.id = social_fb_posts.postable_id and helpdesk_notes.account_id = social_fb_posts.account_id')
      .order(order_conditions)
      .includes(preload_options)
      .limit(limit)
  }

  scope :latest_facebook_message, -> {
    where([" incoming = 1 and social_fb_posts.postable_type = 'Helpdesk::Note'"]).
    joins("INNER join social_fb_posts on helpdesk_notes.id = social_fb_posts.postable_id and helpdesk_notes.account_id = social_fb_posts.account_id").
    order("created_at desc")
  }

  CATEGORIES.keys.each do |c| 
    scope c.to_s.pluralize, -> {
      where(helpdesk_schema_less_notes: {
        int_nc01: CATEGORIES[c]
      }).
      joins('INNER JOIN helpdesk_schema_less_notes on helpdesk_schema_less_notes.note_id ='\
        ' helpdesk_notes.id and helpdesk_notes.account_id = helpdesk_schema_less_notes.account_id')
    }
  end

  scope :created_between, -> (start_time, end_time) {
    where(['helpdesk_notes.created_at >= ? and helpdesk_notes.created_at <= ?', 
              start_time, end_time])
  }
  
  scope :exclude_source, -> (s) { where(exclude_condition(s)[:conditions]) }
  
  scope :broadcast_notes, -> {
    where(["notable_type = ? and deleted = 0 and "\
              "helpdesk_schema_less_notes.#{Helpdesk::SchemaLessNote.category_column} = ?",
              "Helpdesk::Ticket", Helpdesk::Note::CATEGORIES[:broadcast]]).
    joins('INNER JOIN helpdesk_schema_less_notes on helpdesk_schema_less_notes.note_id ='\
      ' helpdesk_notes.id and helpdesk_notes.account_id = helpdesk_schema_less_notes.account_id')
  }



  validates_presence_of  :source, :notable_id
  validates_numericality_of :source
  validate :inclusion_of_note_source
  validates :user, presence: true, if: -> {user_id.present?}
  validate :edit_broadcast_note, on: :update, :if => :broadcast_note?

  def assign_values(notehash)
    notehash.each_key do |k|
      safe_send("#{k}=", notehash[k])
    end
  end

  def edit_broadcast_note
    self.errors.add(:base, I18n.t('activerecord.errors.messages.edit_broadcast_note'))
  end

  SCHEMA_LESS_ATTRIBUTES.each do |attribute|
    define_method("#{attribute}") do
      load_schema_less_note
      schema_less_note.safe_send(attribute)
    end

    define_method("#{attribute}?") do
      load_schema_less_note
      schema_less_note.safe_send(attribute)
    end

    define_method("#{attribute}=") do |value|
      load_schema_less_note
      schema_less_note.safe_send("#{attribute}=", value)
    end
  end

  def all_attachments
    shared_attachments=self.attachments_sharable
    individual_attachments = self.attachments
    shared_attachments+individual_attachments
  end

  def self.exclude_condition source
    if source.is_a?(Array)
      { :conditions => ['`helpdesk_notes`.source NOT IN (?)', source.map{|s| Account.current.helpdesk_sources.note_source_keys_by_token[s]} ] }
    else
      { :conditions => ['`helpdesk_notes`.source <> ?', Account.current.helpdesk_sources.note_source_keys_by_token[source]] }
    end
  end

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

  def fb_note?
    source == Account.current.helpdesk_sources.note_source_keys_by_token["facebook"]
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

  def ecommerce?
    source == Account.current.helpdesk_sources.note_source_keys_by_token["ecommerce"] && self.ebay_question.present?
  end

  def canned_form?
    source == Account.current.helpdesk_sources.note_source_keys_by_token['canned_form']
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

  def to_cc_emails
    [to_emails,cc_emails]
  end

  def can_split?
    return false unless Account.current.split_tickets_enabled?
     human_note_for_ticket? and (self.incoming and self.notable) and !user.blocked? and (self.private ? user.customer? : true) and
      ((self.notable.facebook? and self.fb_post) ? self.fb_post.can_comment? : true) and
        (!self.mobihelp?) and (!self.ecommerce?) and(!self.feedback?) and
        self.notable.customer_performed?(self.user) and (!self.broadcast_note?)
  end

  def broadcast_note?
    source == Account.current.helpdesk_sources.note_source_keys_by_token["note"] && schema_less_note.category == CATEGORIES[:broadcast]
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
    Account.current.helpdesk_sources.note_sources[source]
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

  def summary_note?
    source == Account.current.helpdesk_sources.note_source_keys_by_token["summary"]
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
      Account.current.response_time_null_fix_enabled? ? notable.save : ticket_state.save
    end
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
    return "private_note" if private_note? && !broadcast_note?
    return "public_note" if public_note?
    return "forward" if fwd_email?
    return "phone_note" if phone_note?
    return "broadcast_note" if broadcast_note?
    return 'canned_form' if canned_form?
    return "summary" if summary_note?
    "reply"
  end

  def liquidize_body
    all_attachments.empty? ? body_html :
      "#{body_html}\n\nAttachments :\n#{notable.liquidize_attachments(all_attachments)}\n"
  end

  def fb_reply_allowed?
    self.notable.facebook? and self.fb_post and self.incoming and self.fb_post.can_comment?
  end

  def load_note_reply_cc
    if self.third_party_response?
      [self.cc_emails, self.from_email.to_a + self.to_emails.to_a.reject { |e| exclude_emails_list.include?(parse_email_text(e)[:email]) }]
    elsif (self.reply_to_forward? || self.fwd_email?)
      [self.cc_emails, self.to_emails.to_a]
    else
      [[], []]
    end
  end

  def load_note_reply_from_email
    email_addrs = []
    if (self.fwd_email? || self.reply_to_forward?)
      parsed_email = parse_email_text(self.from_email)
      email_addrs = parsed_email[:email].downcase.to_a
    elsif self.third_party_response?
      to_emails = self.to_emails.map{ |email| parse_email_text(email)[:email].downcase }
      email_addrs = to_emails
      cc_emails = self.cc_emails.map{ |email| parse_email_text(email)[:email].downcase }
      email_addrs += cc_emails
    end
    email_addrs
  end

  # Store NER API response in memcache
  # Whenever the customer note is created with timedata information, memcache key needs to be updated.

  def store_ner_data(data)
    ner_data = data.merge({"note_id"=>self.id})
    key = NER_ENRICHED_NOTE % { :account_id => self.account_id , :ticket_id => self.notable_id }
    MemcacheKeys.cache(key, ner_data, NER_DATA_TIMEOUT)
  end

  def inline_attachment_ids=(attachment_ids)
    attachment_ids ||= []
    attachment_ids = attachment_ids.split(",") if attachment_ids.is_a? String
    attachment_ids = (inline_attachment_ids + attachment_ids).map(&:to_i).uniq
    super(attachment_ids)
  end

  def update_email_received_at(received_at)
    return if received_at.blank?

    schema_less_note.note_properties = {} if schema_less_note.note_properties.nil?
    schema_less_note.note_properties[:received_at] = received_at
  end

  def recently_created_note?
    Time.zone.now - created_at < 1.hour
  end

  def eligible_to_detect_thank_you?
    user.customer? && !import_note && body.present? && !Account.current.helpdesk_sources.note_blacklisted_thank_you_detector_note_sources.include?(source) &&
      recently_created_note?
  end

  def body
    note_body && note_body.body
  end

  def body_html
    note_body && note_body.body_html
  end

  def full_text
    note_body && note_body.full_text
  end

  def full_text_html
    note_body && note_body.full_text_html
  end

  def redactable?
    Account.current.redaction_enabled? && Account.current.active_redaction_configs.present? && user.customer?
  end

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
      return if third_party_response?

      cc_email_hash_value = notable.cc_email_hash.nil? ? Helpdesk::Ticket.default_cc_hash : notable.cc_email_hash
      if fwd_email? || reply_to_forward?
        fwd_emails = self.to_emails | self.cc_emails | self.bcc_emails | cc_email_hash_value[:fwd_emails]
        fwd_emails.delete_if {|email| (notable.requester.email.present? && parse_email(email)[:email].downcase == notable.requester.email.downcase)}
        cc_email_hash_value[:fwd_emails]  = fwd_emails
      else
        cc_email_hash_value[:reply_cc] = self.cc_emails.reject {|email| (parse_email(email)[:email].downcase == notable.requester.email.downcase)}
        tkt_cc_emails = self.cc_emails | cc_email_hash_value[:cc_emails]
        cc_emails = tkt_cc_emails.map { |email| parse_email(email)[:email].downcase }.compact.uniq
        cc_emails.delete_if {|email| (notable.requester.email.present? && email == notable.requester.email.downcase)}
        cc_email_hash_value[:bcc_emails] = cc_email_hash_value[:bcc_emails].present? ? self.bcc_emails | cc_email_hash_value[:bcc_emails] : self.bcc_emails
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
      self.source == Account.current.helpdesk_sources.note_source_keys_by_token['mobihelp'] || self.source == Account.current.helpdesk_sources.note_source_keys_by_token['mobihelp_app_review']
    end

    def inclusion_of_note_source
      Account.current.helpdesk_sources.note_source_keys_by_token.values.include?(source)
    end

  private

    def human_note_for_ticket?
      (self.notable.is_a? Helpdesk::Ticket) && user && (source != Account.current.helpdesk_sources.note_source_keys_by_token['meta'])
    end

    def automated_note_for_ticket?
      (source == Account.current.helpdesk_sources.note_source_keys_by_token["automation_rule"])
    end

    # Replied by third pary to the forwarded email
    # Use this method only after checking human_note_for_ticket? and user.customer?
    def replied_by_third_party?
      private_note? and incoming and notable.included_in_fwd_emails?(user.email)
    end

    def consecutive_customer_response?
      notable.ticket_states.consecutive_customer_response?
    end

    def method_missing(method, *args, &block)
      begin
        super
      rescue NoMethodError => e
        if(SCHEMA_LESS_ATTRIBUTES.include?(method.to_s.chomp("=").chomp("?")))
          load_schema_less_note
          args = args.first if args && args.is_a?(Array)
          (method.to_s.include? '=') ? schema_less_note.safe_send(method, args) : schema_less_note.safe_send(method)
        end
      end
    end

    def only_kbase?
      ((to_emails || []) | (cc_emails || []) | (bcc_emails || [])).compact == [account.kbase_email]
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

    def exclude_emails_list
      @exclude_emails_list ||= self.notable.to_email.to_a + self.account.email_configs.pluck(:reply_email)
    end

    def save_att_as_user_draft(att)
      att.attachable_id = User.current.id
      att.attachable_type = 'UserDraft'
      att.save
      att
    end

    def self.conversation_sources
      Account.current.helpdesk_sources.note_exclude_sources.map { |s| Account.current.helpdesk_sources.note_source_keys_by_token[s] }
    end
end
