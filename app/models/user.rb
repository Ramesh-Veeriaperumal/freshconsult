# encoding: utf-8
class User < ActiveRecord::Base
  
  belongs_to_account
  include ActionController::UrlWriter
  include SentientUser
  include Helpdesk::Ticketfields::TicketStatus
  include Mobile::Actions::User
  include Users::Activator
  include Users::Preferences
  include Authority::Rails::ModelHelpers
  include Search::ElasticSearchIndex
  include Cache::Memcache::User
  include Redis::RedisKeys
  include Redis::OthersRedis
  include Authority::Rails::ModelHelpers
  include ApiWebhooks::Methods

  USER_ROLES = [
     [ :admin,       "Admin",            1 ],
     [ :poweruser,   "Power User",       2 ],
     [ :customer,    "Customer",         3 ],
     [ :account_admin,"Account admin",   4 ],
     [ :client_manager,"Client Manager", 5 ],
     [ :supervisor,    "Supervisor"    , 6 ]
    ]

  EMAIL_REGEX = /(\A[-A-Z0-9.'’_&%=+]+@(?:[A-Z0-9\-]+\.)+(?:[A-Z]{2,10})\z)/i

  concerned_with :associations, :callbacks

  validates_uniqueness_of :twitter_id, :scope => :account_id, :allow_nil => true, :allow_blank => true
  validates_uniqueness_of :external_id, :scope => :account_id, :allow_nil => true, :allow_blank => true

  xss_sanitize  :only => [:name,:email]
  named_scope :contacts, :conditions => { :helpdesk_agent => false }
  named_scope :technicians, :conditions => { :helpdesk_agent => true }
  named_scope :visible, :conditions => { :deleted => false }
  named_scope :active, lambda { |condition| { :conditions => { :active => condition }} }
  named_scope :with_conditions, lambda { |conditions| { :conditions => conditions} }

  # Using text_uc01 column as the preferences hash for storing user based settings
  serialize :text_uc01, Hash
  alias_attribute :preferences, :text_uc01  
  alias_method_chain :preferences, :defaults

  # Attributes used in Freshservice
  # alias_attribute :last_name, :string_uc02 # string_uc02 is used in Freshservice to store last name
  alias_attribute :user_type, :user_role # Used for "System User"
  alias_attribute :extn, :string_uc03 # Active Directory User - Phone Extension
    
  acts_as_authentic do |c|    
    c.login_field(:email)
    c.validate_login_field(false)
    c.validate_email_field(false)
    c.validations_scope = :account_id
    c.validates_length_of_password_field_options = {:on => :update, :minimum => 4, :if => :has_no_credentials? }
    c.validates_length_of_password_confirmation_field_options = {:on => :update, :minimum => 4, :if => :has_no_credentials?}    
    #The following is a part to validate email only if its not deleted
    c.merge_validates_format_of_email_field_options  :if =>:chk_email_validation?, :with => EMAIL_REGEX
    c.merge_validates_length_of_email_field_options :if =>:chk_email_validation? 
    c.merge_validates_uniqueness_of_email_field_options :if =>:chk_email_validation?, :case_sensitive => true
  end
  
  validate :has_role?, :unless => :customer?
  validate :user_email_count, :if => :email_required?, :on => :update

  attr_accessor :import, :highlight_name, :highlight_job_title, :created_from_email, :primary_email_attributes
  
  attr_accessible :name, :email, :password, :password_confirmation, :primary_email_attributes, :user_emails_attributes, :second_email, :job_title, :phone, :mobile, 
                  :twitter_id, :description, :time_zone, :avatar_attributes, :customer_id, :import_id,
                  :deleted, :fb_profile_id, :language, :address, :client_manager, :helpdesk_agent, :role_ids, :parent_id

  class << self # Class Methods
    #Search display
    def search_display(user)
      "#{user.excerpts.name} - #{user.excerpts.email}"
    end
    #Search display ends here

    def filter(letter, page, state = "verified", per_page = 50,order_by = 'name')
      begin
        paginate :per_page => per_page, :page => page,
             :conditions => filter_condition(state, letter) ,
             :order => order_by, :include => :primary_email
      rescue Exception =>exp
        raise "Invalid fetch request for contacts"
      end
    end

    def filter_condition(state, letter)
      case state
        when "verified", "unverified"
          [ ' name like ? and deleted = ? and active = ? and deleted_at IS NULL and blocked = false ', 
            "#{letter}%", false , state.eql?("verified") ]
        when "deleted", "all"
          [ ' name like ? and deleted = ? and deleted_at IS NULL and blocked = false', 
            "#{letter}%", state.eql?("deleted")]
        when "blocked"
          [ ' name like ? and ((blocked = ? and blocked_at <= ?) or (deleted = ? and  deleted_at <= ?)) and whitelisted = false ', 
            "#{letter}%", true, (Time.now+5.days).to_s(:db), true, (Time.now+5.days).to_s(:db)  ]
      end                                      
    end

    def find_by_email_or_name(value)
      conditions = {}
      if value =~ /(\b[-a-zA-Z0-9.'’_%+]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}\b)/
        conditions[:email] = value
      else
        conditions[:name] = value
      end
      user = self.find(:first, :conditions => conditions)
      user
    end

    def find_by_an_unique_id(options = {})
      options.delete_if { |key, value| value.blank? }
      
      #return self.find(options[:id]) if options.key?(:id)
      return UserEmail.user_for_email(options[:email]) if options.key?(:email)
      return self.find_by_twitter_id(options[:twitter_id]) if options.key?(:twitter_id)
      return self.find_by_external_id(options[:external_id]) if options.key?(:external_id)
      return self.find_by_phone(options[:phone]) if options.key?(:phone)
    end 

    def update_posts_count
      self.class.update_posts_count id
    end
    
    def update_posts_count(id)
      User.update_all ['posts_count = ?', Post.count(:id, :conditions => {:user_id => id, :published => true})],   ['id = ?', id]
    end

    def reset_current_user
      User.current = nil
    end

    protected :find_by_email_or_name, :find_by_an_unique_id
  end
  
  def client_manager=(checked)
    if customer?
      self.privileges = (checked == "true") ? Role.privileges_mask([:client_manager]) : "0"
    end
  end

  def chk_email_validation?
    (is_not_deleted?) and (no_multiple_user_emails) and (twitter_id.blank? || !email.blank?) and (fb_profile_id.blank? || !email.blank?) and
                          (external_id.blank? || !email.blank?) and (phone.blank? || !email.blank?) and
                          (mobile.blank? || !email.blank?)
  end

  def email_required?
    is_not_deleted? and twitter_id.blank? and fb_profile_id.blank? and external_id.blank? and phone.blank? and mobile.blank?
  end

  def add_tag(tag)
    # Tag the users if he is not already tagged
    self.tags.push tag unless tag.blank? or self.tagged?(tag.id)
  end

  def parent_id
    string_uc04.to_i
  end

  def parent_id=(p_id)
    self.string_uc04 = p_id.to_s
  end

  def update_tag_names(csv_tag_names)
    unless csv_tag_names.nil? # Check only nil so that empty string will remove all the tags.
      updated_tag_names = csv_tag_names.split(",")
      new_tags = []
      updated_tag_names.each { |updated_tag_name|
        updated_tag_name = updated_tag_name.strip
        m=false
        new_tags.each { |fetched_tag|
          m=true if fetched_tag.name == updated_tag_name
        }
        next if m
        # TODO Below line executes query for every iteration.  Better to use some cached objects.
        new_tags.push self.account.tags.find_by_name(updated_tag_name) || Helpdesk::Tag.new(:name => updated_tag_name ,:account_id => self.account.id)
      }
      self.tags = new_tags
    end
  end

  def tagged?(tag_id)
    unless tag_id.blank?
      # To avoid DB query.
      self.tags.each {|tag|
        return true if tag.id == tag_id
      }
      # Check the tag_uses that are not yet committed in the DB, if any
      self.tag_uses.each {|tag_use|
        return true if tag_use.tag_id == tag_id
      }
    end
    return false
  end
	
	def available_number
		phone.blank? ? mobile : phone
	end


  def signup!(params , portal=nil)
    check_feature_and_modify(params) 
    self.name = params[:user][:name]
    self.phone = params[:user][:phone]
    self.mobile = params[:user][:mobile]
    self.twitter_id = params[:user][:twitter_id]
    self.external_id = params[:user][:external_id]
    self.description = params[:user][:description]
    self.customer_id = params[:user][:customer_id]
    self.job_title = params[:user][:job_title]
    self.helpdesk_agent = params[:user][:helpdesk_agent] || false
    self.client_manager = params[:user][:client_manager]
    self.role_ids = params[:user][:role_ids] || []
    self.time_zone = params[:user][:time_zone]
    self.import_id = params[:user][:import_id]
    self.fb_profile_id = params[:user][:fb_profile_id]
    self.email = params[:user][:email] if no_multiple_user_emails
    self.language = params[:user][:language]
    self.address = params[:user][:address]
    self.update_tag_names(params[:user][:tags]) # update tags in the user object
    self.avatar_attributes=params[:user][:avatar_attributes] unless params[:user][:avatar_attributes].nil?
    self.user_emails_attributes = params[:user][:user_emails_attributes] if params[:user][:user_emails_attributes].present?
    self.deleted = true if (user_emails.present? && user_emails.first.email =~ /MAILER-DAEMON@(.+)/i)
    self.created_from_email = params[:user][:created_from_email] 
    return false unless save_without_session_maintenance
    if (!deleted and !email.blank?)
      if self.language.nil?
        args = [ portal,false, params[:email_config]]
        Delayed::Job.enqueue(Delayed::PerformableMethod.new(self, :deliver_activation_instructions!, args), 
          nil, 5.minutes.from_now) 
      else
        deliver_activation_instructions!(portal,false, params[:email_config])
      end
    end
    true
  end

  named_scope :matching_users_from, lambda { |search|
    {
      :select => %(users.id, name, GROUP_CONCAT(user_emails.email) as `additional_email`, 
        twitter_id, fb_profile_id, phone, mobile, job_title, customer_id),
      :joins => %(left join user_emails on user_emails.user_id=users.id and 
        user_emails.account_id = users.account_id and user_emails.email like '%<str>s') % { :str => "%#{search}%" },
      :conditions => %((name like '%<str>s' or user_emails.email 
        like '%<str>s' and deleted = 0)) % {
        :str => "%#{search}%"      
      },
      
      :group => "users.id",
    }
  }

  named_scope :without, lambda { |source|
    {
      :conditions => "users.id <> %<us_id>i" % {
        :us_id => source.id
      }
    }
  }

  def signup(portal=nil)
    return false unless save_without_session_maintenance
    deliver_activation_instructions!(portal,false) if (!deleted and self.user_emails.present?)
    true
  end

  def check_feature_and_modify(params)
    if no_multiple_user_emails and params[:user][:user_emails_attributes]
      params[:user][:email] = params[:user][:user_emails_attributes]["0"][:email]
      params[:user].delete(:user_emails_attributes)
    elsif !no_multiple_user_emails and params[:user][:email]
      params[:user][:user_emails_attributes] = {"0" => {:email => params[:user][:email], :primary_role => true}}
      params[:user].delete(:email)
    end
  end

  def avatar_attributes=(av_attributes)
    return build_avatar(av_attributes) if avatar.nil?
    avatar.update_attributes(av_attributes)
  end
 
  def active?
    active
  end
  
  def has_email?
    !self.email.blank?
  end

  
  def activate!(params)
    self.active = true
    self.name = params[:user][:name]
    self.password = params[:user][:password]
    self.password_confirmation = params[:user][:password_confirmation]
    self.user_emails.first.update_attributes({:verified => true});
    #self.openid_identifier = params[:user][:openid_identifier]
    save
  end

  def exist_in_db?
    !(id.blank?)
  end

  def has_no_credentials?
    self.crypted_password.blank? && active? && !account.sso_enabled? && !deleted && self.authorizations.empty? && self.twitter_id.blank? && self.fb_profile_id.blank? && self.external_id.blank?
  end

  def first_name
    name_part("given")
  end

  def last_name
    name_part("family")
  end

  #Savage_beast changes start here
  #implement in your user model 
  def display_name
    to_s
  end

  #implement in your user model 

  def agent?
    helpdesk_agent
  end
  alias :is_agent :agent?

  def customer?
    !agent?
  end
  alias :is_customer :customer?
  
  # Used in mobile
  def is_client_manager?
    self.privilege?(:client_manager)
  end

  def can_assume?(user)
    # => Not himself
    # => User is not deleted
    # => And the user does not have any admin privileges (He is an agent)
    !((user == self) or user.deleted? or user.privilege?(:view_admin))
  end

  def api_assumable?
    !deleted? && privilege?(:manage_tickets)
  end
  
  def first_login?
    login_count <= 2
  end
  
  #Savage_beast changes end here

  ##Authorization copy starts here
  def name_details #changed name_email to name_details
    return "#{name} <#{email}>" unless email.blank?
    return "#{name} (#{phone})" unless phone.blank?
    return "#{name} (#{mobile})" unless mobile.blank?
    return "@#{twitter_id}" unless twitter_id.blank?
    name
  end

  def search_data
    if !no_multiple_user_emails and defined?(additional_email)
      [additional_email.split(",").map{|x| {:id => id, :details => "#{name} <#{x}>", :value => name}}]
    else
      [{:id => id, :details => self.name_details, :value => name}]
    end
  end
  ##Authorization copy ends here
  
  def url_protocol
    if account.main_portal.portal_url.blank? 
      return account.ssl_enabled? ? 'https' : 'http'
    else 
      return account.main_portal.ssl_enabled? ? 'https' : 'http'
    end
  end
  
  def to_s
    name.blank? ? email : name
  end
  
  def to_liquid
    @user_drop ||= UserDrop.new self
  end
    
  def has_company?
    customer? && customer
  end

  def emails
    user_emails.map(&:email)
  end

  def is_not_deleted?
    Rails.logger.debug "not ::deleted ?:: #{!self.deleted}"
    !self.deleted
  end
  
  def occasional_agent?
    agent && agent.occasional
  end

  def day_pass_granted_on(start_time = DayPassUsage.start_time) #Revisit..
    day_pass_usages.on_the_day(start_time).first
  end
  
  def spam?
    deleted && !deleted_at.nil?
  end

  def get_info
    (email) || (twitter_id) || (external_id) || (name)
  end
  
  def twitter_style_id
    "@#{twitter_id}"
  end
  
  def can_view_all_tickets?
    self.privilege?(:manage_tickets) && agent.all_ticket_permission
  end
  
  def group_ticket_permission
    self.privilege?(:manage_tickets) && agent.group_ticket_permission
  end

  def assigned_ticket_permission
    self.privilege?(:manage_tickets) && agent.assigned_ticket_permission
  end
  
  def has_ticket_permission? ticket
    (can_view_all_tickets?) or (ticket.responder_id == self.id ) or (ticket.requester_id == self.id) or (group_ticket_permission && (ticket.group_id && (agent_groups.collect{|ag| ag.group_id}.insert(0,0)).include?( ticket.group_id))) 
  end

  # For a customer we need to check if he is the requester of the ticket
  # Or if he is allowed to view tickets from his company
  def has_customer_ticket_permission?(ticket)
    (self.id == ticket.requester_id) or 
    (is_client_manager? && self.customer_id && ticket.requester.customer_id && (ticket.requester.customer_id == self.customer_id) )
  end
  
  def restricted?
    !can_view_all_tickets?
  end

  def to_xml(options = {})
     options[:indent] ||= 2
      xml = options[:builder] ||= Builder::XmlMarkup.new(:indent => options[:indent])
      xml.instruct! unless options[:skip_instruct]
      super(:builder => xml,:root=>options[:root], :skip_instruct => true, :include => :user_emails, :only => [:id,:name,:email,:created_at,:updated_at,:active,:customer_id,:job_title,
                                                              :phone,:mobile,:twitter_id,:description,:time_zone,:deleted,
                                                              :helpdesk_agent,:fb_profile_id,:external_id,:language,:address]) 
  end
  
  def company_name
    customer.name unless customer.nil?
  end

  def has_company?
    customer? && customer
  end

  def recent_tickets(limit = 5)
    tickets.newest(limit)
  end

  def available_quests
    account.quests.available(self)
  end

  def achieved_quest(quest)
    achieved_quests.find_by_quest_id(quest.id)
  end

  def badge_awarded_at(quest)
    achieved_quest(quest).updated_at
  end

  def change_primary_email primary
    self.user_emails.update_all(:primary_role => false)
    self.user_emails.find(primary.to_i).toggle!(:primary_role) #toggle
    return true
  end
  
  def make_customer
    return true if customer?
    if update_attributes({:helpdesk_agent => false, :deleted => false})
      subscriptions.destroy_all
      agent.destroy
      freshfone_user.destroy if freshfone_user
      email_notification_agents.destroy_all
      return true
    end 
    return false
  end
  
  def make_agent(args = {})
    ActiveRecord::Base.transaction do
      self.deleted = false
      self.helpdesk_agent = true
      self.role_ids = [account.roles.find_by_name("Agent").id] 
      UserEmail.destroy self.user_emails.reject(&:primary_role?)
      agent = build_agent()
      agent.occasional = !!args[:occasional]
      save
    end
  end

  def to_indexed_json
    to_json( 
              :root => "user",
              :tailored_json => true,
              :only => [ :name, :email, :description, :job_title, :phone, :mobile,
                         :twitter_id, :fb_profile_id, :account_id, :deleted,
                         :helpdesk_agent, :created_at, :updated_at ], 
              :include => { :customer => { :only => [:name] } } 
           )
  end

  def update_search_index
    Resque.enqueue(Search::IndexUpdate::UserTickets, { :current_account_id => account_id, :user_id => id })
  end

  def moderator_of?(forum)
    moderatorships.count(:all, :conditions => ['forum_id = ?', (forum.is_a?(Forum) ? forum.id : forum)]) == 1
  end

  def make_current
    User.current = self
  end

  def self.reset_current_user
    User.current = nil
  end
  
  def user_time_zone
    self.time_zone
  end
  
  def user_tag
    self.tags
  end

  def self.search_by_name search_by, account_id, options = { :load => true, :page => 1, :size => 10, :preference => :_primary_first }
    return [] if search_by.blank? || (search_by = search_by.gsub(/[\^\$]/, '')).blank?
    begin
      Search::EsIndexDefinition.es_cluster(account_id)
      item = Tire.search Search::EsIndexDefinition.searchable_aliases([User], account_id), options do |search|
        search.query do |query|
          query.filtered do |f|
            if SearchUtil.es_exact_match?(search_by)
              f.query { |q| q.text :name, SearchUtil.es_filter_exact(search_by), :type => :phrase }        
            else
              f.query { |q| q.string SearchUtil.es_filter_key(search_by), :fields => ['name'], :analyzer => "include_stop" }
            end
            f.filter :term, { :account_id => account_id }
            f.filter :term, { :deleted => false }
          end
        end
        search.from options[:size].to_i * (options[:page].to_i-1)
        search.highlight :description, :name, :job_title, :options => { :tag => '<strong>', :fragment_size => 50, :number_of_fragments => 4, :encoder => 'html' }
      end
      item.results
    rescue Exception => e
      NewRelic::Agent.notice_error(e)
      []
    end 
  end

  protected
  
    def search_fields_updated?
      all_fields = [:name, :email, :description, :job_title, :phone, :mobile,
                    :twitter_id, :fb_profile_id, :customer_id, :deleted, :helpdesk_agent]
      (@all_changes.keys & all_fields).any?
    end

  private
    def name_part(part)
      part = parsed_name[part].blank? ? "particle" : part unless parsed_name.blank? and part == "family"
      parsed_name[part].blank? ? name : parsed_name[part]
    end

    def parsed_name
      @parsed_name ||= Namae::Name.parse(self.name)
    end

    def bakcup_user_changes
      @all_changes = self.changes.clone
      @all_changes.symbolize_keys!
    end

    def helpdesk_agent_updated?
      @all_changes.has_key?(:helpdesk_agent)
    end

    def email_updated?
       @all_changes.has_key?(:email)
    end
    
    def customer_id_updated?
      @all_changes.has_key?(:customer_id)
    end

    def privileges_updated?
      @all_changes.has_key?(:privileges)
    end

    def company_info_updated?
      customer_id_updated? or privileges_updated?
    end

    def clear_redis_for_agent
      return unless deleted_changed? || agent?
      self.agent_groups.each do |ag|
        next unless ag.group.round_robin_eligible?
        remove_others_redis_key(GROUP_AGENT_TICKET_ASSIGNMENT % 
               {:account_id => account_id, :group_id => ag.group_id})
      end
    end

    def touch_role_change(role)
      @role_change_flag = true
    end

    def roles_changed?
      !!@role_change_flag
    end

    def has_role?
      self.errors.add(:base, I18n.t("activerecord.errors.messages.user_role")) if
        ((@role_change_flag or new_record?) && self.roles.blank?)
    end

    def user_email_count
      self.errors.add(:base, I18n.t("activerecord.errors.messages.user_emails")) unless
        (user_emails.reject(&:marked_for_destruction?).count)
    end

    def user_emails_migrated?
      # for user email delta
      self.account.user_emails_migrated?
    end

    def no_multiple_user_emails
      !self.account.features?(:multiple_user_emails) 
    end

    def self.find_by_user_emails(login)
      if !Account.current.features?(:multiple_user_emails)
        user = User.find_by_email(login)
        user if user.present? and user.active? and !user.blocked?
      else
        user_email = UserEmail.find_by_email(login)
        user_email.user if !user_email.nil? and user_email.verified? and !user_email.user.blocked?
      end
    end

end
