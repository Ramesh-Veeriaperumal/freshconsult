# encoding: utf-8

class User < ActiveRecord::Base
  self.primary_key= :id

  belongs_to_account
  has_many :access_tokens, :class_name => 'Doorkeeper::AccessToken', :foreign_key => :resource_owner_id, :dependent => :destroy

  include SentientUser
  include Helpdesk::Ticketfields::TicketStatus
  include Mobile::Actions::User
  include Users::Activator
  include Users::Preferences
  include Authority::FreshdeskRails::ModelHelpers
  include Search::ElasticSearchIndex
  include Cache::Memcache::User
  include Redis::RedisKeys
  include Redis::RoundRobinRedis
  include Redis::OthersRedis
  include Authority::FreshdeskRails::ModelHelpers
  include ApiWebhooks::Methods
  include InstalledAppBusinessRules::Methods
  include Social::Ext::UserMethods
  include AccountConstants
  include PasswordPolicies::UserHelpers
  include Redis::FreshidPasswordRedis
  include ContactsCompaniesHelper
  include Cache::Memcache::Admin::CustomData

  concerned_with :constants, :associations, :callbacks, :user_email_callbacks, :rabbitmq, :esv2_methods, :presenter, :freshid_methods, :presenter_helper

  include CustomerDeprecationMethods, CustomerDeprecationMethods::NormalizeParams # Placed here to handle deprecated Customer class. Has to be after associations

  validates_uniqueness_of :twitter_id, :scope => :account_id, :allow_nil => true, :allow_blank => true, unless: :uniqueness_validated
  validates_uniqueness_of :external_id, :scope => :account_id, :allow_nil => true, :allow_blank => true
  validates_uniqueness_of :unique_external_id, :scope => :account_id, :allow_nil => true, :case_sensitive => false, unless: :uniqueness_validated
  before_validation :trim_attributes

  xss_sanitize  :only => [:name,:email,:language, :job_title, :twitter_id, :address, :description, :fb_profile_id], :plain_sanitizer => [:name,:email,:language, :job_title, :twitter_id, :address, :description, :fb_profile_id]
  scope :trimmed, -> { select([:'users.id', :'users.name']) }
  scope :contacts, -> { where(helpdesk_agent: false) }
  scope :technicians, -> { where(helpdesk_agent: true) }
  scope :visible, -> { where(deleted: false) }
  scope :active, -> (condition) { where(active: condition) }
  scope :with_user_ids, -> (condition) { where(id: condition) }
  scope :with_conditions, -> (conditions) { where(conditions) }
  scope :with_contractors, -> (conditions) { 
            where(conditions).
            joins(%(INNER JOIN user_companies ON
              user_companies.account_id = users.account_id AND
              user_companies.user_id = users.id))
          }
  scope :company_users_via_customer_id, -> (cust_id) { where(customer_id: cust_id) }
  
  swindle :technicians_basics,
          scope: :technicians,
          attrs: %i[id name email]

  # Using text_uc01 column as the preferences hash for storing user based settings
  serialize :text_uc01, Hash
  alias_attribute :preferences, :text_uc01
  alias_method_chain :preferences, :defaults

  # Attributes used in Freshservice
  # alias_attribute :last_name, :string_uc02 # string_uc02 is used in Freshservice to store last name
  alias_attribute :user_type, :user_role # Used for "System User"
  alias_attribute :extn, :string_uc03 # Active Directory User - Phone Extension
  
  delegate :history_column=, :history_column, :to => :flexifield

  acts_as_authentic do |c|
    c.login_field(:email)
    c.validate_login_field(false)
    c.validate_email_field(false)
    c.validations_scope = :account_id
    c.validates_length_of_password_field_options = {:on => :update, :minimum => PASSWORD_LENGTH, :if => :has_no_credentials? }
    c.validates_length_of_password_confirmation_field_options = {:on => :update, :minimum => PASSWORD_LENGTH, :if => :has_no_credentials?}
    #The following is a part to validate email only if its not deleted
    c.merge_validates_format_of_email_field_options  :if =>:chk_email_validation?, :with => EMAIL_VALIDATOR
    c.merge_validates_length_of_email_field_options :if =>:chk_email_validation?
    c.merge_validates_uniqueness_of_email_field_options :if =>:chk_email_validation?, :case_sensitive => true
    c.crypto_provider = Authlogic::CryptoProviders::Sha512

    c.validate_password_length = {:if => :password_length_enabled?,
                                  :min_length => :minimum_password_length}

    c.password_history_field(:history_column)

    c.validate_password_history = {:if => :password_history_enabled?,
                                   :depth => :password_history_depth}
    c.password_format_options([{:if => :password_alphanumeric_enabled?, :regex => FDPasswordPolicy::Regex.alphanumeric, :error => "password_policy.alphanumeric"},
                               {:if => :password_special_character_enabled?, :regex => FDPasswordPolicy::Regex.special_characters, :error => "password_policy.special_characters"},
                               {:if => :password_mixed_case_enabled?, :regex => FDPasswordPolicy::Regex.mixed_case, :error => "password_policy.mixed_case"}])                                  
    
    c.validate_password_contains_login(:if => :password_contains_login_enabled?)

    c.password_expiry_field(:text_uc01)
    c.password_expiry_timeout = { :if => :password_expiry_enabled?,
                                  :duration => :password_expiry_duration}

    c.disable_perishable_token_maintenance(true)

    c.periodic_logged_in_timeout = { :if => :periodic_login_enabled?,
                                      :duration => :periodic_login_duration}
  end

  validates :user_skills, length: { :maximum => MAX_NO_OF_SKILLS_PER_USER } # to validate nested_attributes assignment, but this will not handle bulk array of skill ids assignment
  validate :has_role?, :unless => :customer?
  validate :email_validity, :if => :chk_email_presence?
  validate :user_email_presence, :if => :email_required?
  validate :only_primary_email, on: :update, :if => [:agent?]
  validate :max_user_emails
  validate :max_user_companies, :if => :has_multiple_companies_feature?
  validate :unique_external_id_feature, :if => :unique_external_id_changed?
  validate :check_roles_for_field_agents, if: -> { Account.current.field_service_management_enabled? && self.agent.try(:field_agent?) }, on: :update
  validate :validate_agent, on: :update, :if => :agent?

  def save_tags
    @prev_tags = self.tags.map(&:name)
  end

  def email_validity
    self.errors.add(:base, I18n.t("activerecord.errors.messages.email_invalid")) unless self[:account_id].blank? or self[:email] =~ EMAIL_VALIDATOR
    self.errors.add(:base, I18n.t("activerecord.errors.messages.email_not_unique")) if self[:email] and self[:account_id].present? and !uniqueness_validated and User.exists?(["email = ? and id != '#{self.id}'", self[:email]])
  end

  def unique_external_id_feature
    self.errors.add(:base, I18n.t('activerecord.errors.messages.unique_external_id')) unless account.unique_contact_identifier_enabled?
  end

  def only_primary_email
    self.errors.add(:base, I18n.t('activerecord.errors.messages.agent_email')) unless (self.user_emails.length == 1)
  end

  def user_email_presence
    self.errors.add(:base, I18n.t("activerecord.errors.messages.user_emails")) if has_no_emails_with_ui_feature?
  end

  def max_user_emails
    self.errors.add(:base, I18n.t('activerecord.errors.messages.max_user_emails')) if (self.user_emails.reject(&:marked_for_destruction?).length > MAX_USER_EMAILS)
  end

  def has_no_emails_with_ui_feature?
    primary_email.blank? and self.user_emails.reject(&:marked_for_destruction?).empty?
  end

  def max_user_companies
    self.errors.add(:base, I18n.t('activerecord.errors.messages.max_user_companies', :max_companies => user_companies_limit)) \
      if (self.user_companies.reject(&:marked_for_destruction?).length > user_companies_limit)
  end

  def has_multiple_companies_feature?
    account.multiple_user_companies_enabled?
  end

  def tickets_api_relaxation?
    User.current.privilege?(:admin_tasks) && account.skip_mandatory_checks_enabled?
  end

  attr_accessor :import, :highlight_name, :highlight_job_title, :created_from_email, :sbrr_fresh_user,
                :primary_email_attributes, :tags_updated, :keep_user_active, :escape_liquid_attributes, 
                :role_ids_changed, :detect_language, :tag_use_updated, :user_companies_updated, 
                :perishable_token_reset, :prev_tags, :latest_tags, :model_changes, :custom_fields_hash, :user_emails_updated, :access_all_agent_groups, :uniqueness_validated
  # (This role_ids_changed used to forcefully call user callbacks only when role_ids are there.
  # As role_ids are not part of user_model(it is an association_reader), 
  # agent.update_attributes won't trigger user callbacks since user doesn't have any change.
  # Hence user.safe_send(:attribute_will_change!, :role_ids_changed) is being called in api_agents_controller.)

  attr_accessible :name, :email, :password, :password_confirmation, :primary_email_attributes,
                  :user_emails_attributes, :second_email, :job_title, :phone, :mobile, :twitter_id,
                  :description, :time_zone, :customer_id, :avatar_attributes, :company_id,
                  :company_name, :tag_names, :import_id, :deleted, :fb_profile_id, :language,
                  :address, :client_manager, :helpdesk_agent, :role_ids, :parent_id, :string_uc04,
                  :contractor, :skill_ids, :user_skills_attributes, :unique_external_id, :twitter_profile_status, :twitter_followers_count

  TWITTER_REQUESTER_FIELDS_MAPPING = {
    boolean_uc01: :twitter_profile_status,
    long_uc01: :twitter_followers_count
  }.freeze

  TWITTER_REQUESTER_FIELDS_MAPPING.keys.each do |key|
    alias_attribute(TWITTER_REQUESTER_FIELDS_MAPPING[key], key)
  end

  TWITTER_REQUESTER_FIELDS_MAPPING.keys.each do |attribute|
    define_method(attribute.to_s) do
      flexifield.send(attribute)
    end

    define_method("#{attribute}?") do
      flexifield.send(attribute)
    end

    define_method("#{attribute}=") do |value|
      flexifield.send("#{attribute}=", value)
    end
  end

  def time_zone
    tz = self.read_attribute(:time_zone)
    tz = "Kyiv" if tz.eql?("Kyev")
    tz
  end

  def avatar_url(profile_size = :thumb)
    (avatar ? avatar.expiring_url(profile_size, 7.days.to_i) : is_user_social(profile_size)) if present?
  end

  def allow_password_update?
    valid_user? && email.present? && !agent?
  end

  def allow_password_reset?
    valid_user? && email.present?
  end

  def valid_user?
    !deleted? && !spam? && !blocked?
  end

  def is_user_social(profile_size)
    if fb_profile_id
      profile_size = (profile_size == :medium) ? "large" : "square"
      facebook_avatar(fb_profile_id, profile_size)
    else
      "/assets/misc/profile_blank_#{profile_size}.gif"
    end
  end

  def was_agent?
    preferences[:user_preferences][:was_agent]
  end

  def agent_deleted_forever?
    preferences[:user_preferences][:agent_deleted_forever]
  end

  def marked_for_hard_delete?
    preferences[:user_preferences][:marked_for_hard_delete]
  end

  def simple_outreach_unsubscribe?
    preferences[:user_preferences][:simple_outreach_unsubscribe]
  end

  def facebook_avatar( facebook_id, profile_size = "square")
    "https://graph.facebook.com/#{facebook_id}/picture?type=#{profile_size}"
  end

  def ebay_user?
    (self.external_id && self.external_id =~ /\Afbay-/) ? true : false
  end

  def has_edit_access?(user_id)
    account.agent_groups.permissible_user(self.accessible_groups.pluck(:id), user_id).exists?
  end

  # Make sure we keep the key in va_rules as segments, (evaluate_on.send(condition.dispatcher_key))
  def segments(segment_ids = nil)
    return [] if agent?
    @contact_segment ||= Segments::Match::Contact.new self
    @contact_segment.ids(segment_ids: segment_ids)
  end

  class << self # Class Methods
    #Search display
    def search_display(user)
      "#{user.excerpts.name} - #{user.excerpts.email}"
    end
    #Search display ends here

    def filter(letter, page, state = "verified", per_page = 50,order_by = 'name')
      begin
        where(filter_condition(state, letter)).order(order_by).preload(:flexifield).paginate(per_page: per_page, page: page)
      rescue Exception =>exp
        raise "Invalid fetch request for contacts"
      end
    end

    def filter_condition(state, letter)
      conditions = case state
        when "verified", "unverified"
           [ ' deleted = ? and active = ? and deleted_at IS NULL and blocked = false ',
            false , state.eql?("verified") ]
        when "deleted", "all"
          [ ' deleted = ? and deleted_at IS NULL and blocked = false',
            state.eql?("deleted")]
        when "blocked"
          [ ' ((blocked = ? and blocked_at <= ?) or (deleted = ? and  deleted_at <= ?)) and whitelisted = false ',
            true, (Time.zone.now+5.days).to_s(:db), true, (Time.zone.now+5.days).to_s(:db) ]
      end

      unless letter.blank?
        conditions[0] = "#{conditions[0]} and name like ? "
        conditions.push("#{letter}%")
      end
      conditions
    end

    def find_by_email_or_name(value)
      conditions = {}
      if value =~ /(\b[-a-zA-Z0-9.'’_%+]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}\b)/
        conditions[:email] = value
      else
        conditions[:name] = value
      end
      user = self.where(conditions).first
      user
    end

    def find_by_an_unique_id(options = {})
      options.delete_if { |key, value| value.blank? }

      # return self.find(options[:id]) if options.key?(:id)
      return UserEmail.user_for_email(options[:email]) if options.key?(:email)
      return self.where(twitter_id: options[:twitter_id]).first if options.key?(:twitter_id)
      return self.where(fb_profile_id: options[:fb_profile_id]).first if options.key?(:fb_profile_id)
      return self.where(external_id: options[:external_id]).first if options.key?(:external_id)
      return self.where(phone: options[:phone]).first if options.key?(:phone)
      return self.where(unique_external_id: options[:unique_external_id]).first if options.key?(:unique_external_id)
    end

    def update_posts_count
      self.class.update_posts_count id
    end

    def update_posts_count(id)
      User.where(['id = ?', id]).update_all(['posts_count = ?', Post.where(user_id: id, published: true).count(:id)])
    end

    def reset_current_user
      User.current = nil
    end

    def run_without_current_user
      doer = User.current
      User.reset_current_user
      Rails.logger.debug "Running block without Current User"
      yield
    rescue Exception => e
      Rails.logger.debug "Something is wrong run_without_current_user Account id:: #{Account.current.id} #{e.message}"
      NewRelic::Agent.notice_error(e)
      raise e
    ensure
      doer.make_current if doer
    end

    # Used by API V2
    def contact_filter(contact_filter)
      {
        deleted: {
          conditions: { deleted: true }
        },
        verified: {
          conditions: { deleted: false, active: true, blocked: false }
        },
        unverified: {
          conditions: { deleted: false, active: false, blocked: false }
        },
        blocked: {
          conditions: [ "((blocked = true and blocked_at <= ?) or (deleted = true and deleted_at <= ?)) and whitelisted = false", Time.zone.now+5.days, Time.zone.now+5.days ]
        },
        default: {
          conditions: { deleted: false, blocked: false }
        },
        company_id: {
          joins: :user_companies,
          conditions: {
            user_companies:  {
              company_id: contact_filter.company_id,
              account_id: Account.current.id
            }
          }
        },
        email: {
          joins: :user_emails,
          # It is guranteed that all contacts in FD have atleast one entry in user_emails table.
          conditions: { user_emails: { email: contact_filter.email }}
        },
        phone: {
          conditions: { phone: contact_filter.phone }
        },
        mobile: {
          conditions: { mobile: contact_filter.mobile }
        },
        _updated_since: {
          conditions: ['updated_at >= ?', contact_filter.try(:_updated_since).try(:to_time).try(:utc)]
        },
        unique_external_id: {
          conditions: { unique_external_id: contact_filter.unique_external_id}
        },
        twitter_id: {
          conditions: { twitter_id: contact_filter.twitter_id }
        },
        facebook_id: {
            conditions: {fb_profile_id: contact_filter.facebook_id}
        }
      }
    end

    # protected :find_by_email_or_name, :find_by_an_unique_id
  end

  def client_manager=(checked)
    if customer? && default_user_company.present?
      default_user_company.client_manager = (checked == "true" || checked == true)
    end
  end

  def client_manager
    has_company? ? company_client_manager? : false
  end

  def contractor?
    privilege?(:contractor)
  end

  def contractor_ticket? ticket
    privilege?(:contractor) && company_ids.include?(ticket.company_id) &&
      user_companies.where(:company_id => ticket.company_id).first.client_manager
  end

  def chk_email_presence?
    (is_not_deleted?) and !email.blank?
  end

  def chk_email_validation?
    (is_not_deleted?) and (twitter_id.blank? || !email.blank?) and (fb_profile_id.blank? || !email.blank?) and
                          (external_id.blank? || !email.blank?) and (phone.blank? || !email.blank?) and
                          (mobile.blank? || !email.blank?) and (unique_external_id.blank? || !email.blank?)
  end

  def email_required?
    is_not_deleted? and twitter_id.blank? and fb_profile_id.blank? and external_id.blank? and phone.blank? and mobile.blank? and
                        unique_external_id.blank?
  end

  def add_tag(tag)
    # Tag the users if he is not already tagged
    self.tags.push tag unless tag.blank? or self.tagged?(tag.id)
  end

  def parent_id
    string_uc04.to_i
  end

  def parent_id?
    !parent_id.zero?
  end

  def parent_id=(p_id)
    self.string_uc04 = p_id.to_s
  end

  def tag_names= updated_tag_names
    unless updated_tag_names.nil? # Check only nil so that empty string will remove all the tags.
      updated_tag_names = updated_tag_names.split(",").map(&:strip).reject(&:empty?)
      existing_tag_names = tags.collect(&:name)
      self.tag_use_updated = true if updated_tag_names.sort != existing_tag_names.sort
      self.tags = account.tags.assign_tags(updated_tag_names)
    end
  end

  def tag_names
    tags.collect{|tag| tag.name}.join(', ')
  end

  def tags_array
    tags.collect(&:name)
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

  def toggle_ui_preference
    new_pref = { :falcon_ui => !self.preferences[:agent_preferences][:falcon_ui] }
    self.merge_preferences = { :agent_preferences => new_pref }
    save!
  end

  def disable_falcon_ui
    new_pref = { :falcon_ui => false }
    self.merge_preferences = { :agent_preferences => new_pref }
    save!
  end

  def is_falcon_pref?
    self.preferences[:agent_preferences][:falcon_ui] || Account.current.disable_old_ui_enabled?
  end

  def old_notes_first?
    if self.preferences[:agent_preferences][:oldest_on_top].to_s.blank?
      nil # will take account settings preference
    else
      self.preferences[:agent_preferences][:oldest_on_top]
    end
  end

  def falcon_invite_eligible?
    (account.falcon_ui_enabled? && !account.disable_old_ui_enabled? && self.preferences_without_defaults.try(:[], :agent_preferences).try(:[],:falcon_ui).nil?)
  end

  def enabled_undo_send?
    Account.current.undo_send_enabled? && preferences[:agent_preferences][:undo_send]
  end

  def toggle_undo_send(pref)
    new_pref = { undo_send: pref }
    self.merge_preferences = { agent_preferences: new_pref }
    save
  end

  def set_notes_pref(pref = true)
    new_pref = { oldest_on_top: (pref.to_s.to_bool rescue true) }
    self.merge_preferences = { agent_preferences: new_pref }
    save
  end

  def update_csat_rating(rating)
    self.merge_preferences = { csat_rating: rating }
    save
  end

  def last_csat_rating
    preferences[:csat_rating]
  end

  def update_attributes(params) # Overriding to normalize params at one place
    normalize_params(params) # hack to facilitate contact_fields & deprecate customer
    self.active = params["active"] if params["active"]
    if [:tag_names, :tags].any?{|attr| # checking old key for API & prevents resetting tags if its not intended
     params.include?(attr)} && params[:tags].is_a?(String)
      tags = params.delete(:tags)
      params[:tag_names]||= tags
    end
    super(params)
  end

  def update_companies(params)
    if has_multiple_companies_feature?
      if params[:user][:removed_companies].present?
        to_be_removed = JSON.parse params[:user][:removed_companies]
        remove_ids = to_be_removed.map{ |company_name| 
          c = companies.find { |c| c.name.downcase == company_name.downcase}
          c.id if c.present?
        }.compact
        UserCompany.destroy_all(:account_id => account_id,
                                :user_id => id,
                                :company_id => remove_ids) if remove_ids.any?
        self.user_companies.reload
      end

      if params[:user][:added_companies].present?
        to_be_added = JSON.parse params[:user][:added_companies]
        to_be_added.each do |comp|
          new_comp = find_or_create_company(comp['company_name'])
          next if new_comp.blank?

          user_companies.build(company_id: new_comp.id,
                               client_manager: comp['client_manager'],
                               default: comp['default_company'])
        end
      end

      if params[:user][:edited_companies].present?
        to_be_edited = JSON.parse params[:user][:edited_companies]
        to_be_edited.each do |comp|
          next if comp['company_name'].blank?

          u_comp = user_companies.find { |uc| uc.company_id == comp['id'] }
          new_comp = find_or_create_company(comp['company_name'])
          next if new_comp.blank?

          u_comp.company_id = new_comp.id
          u_comp.default = comp['default_company']
          u_comp.client_manager = comp['client_manager']
        end
      end
    end
  end

  def build_user_attributes(params)
    normalize_params(params[:user]) # hack to facilitate contact_fields & deprecate customer
    params[:user][:tag_names] = params[:user][:tags] unless params[:user].include?(:tag_names)
    self.name = params[:user][:name]
    self.phone = params[:user][:phone]
    self.mobile = params[:user][:mobile]
    self.twitter_id = params[:user][:twitter_id]
    self.external_id = params[:user][:external_id]
    self.unique_external_id = params[:user][:unique_external_id]
    self.description = params[:user][:description]
    self.company_name = params[:user][:company_name] if params[:user].include?(:company_name)
    self.company_id = params[:user][:company_id] if params[:user].include?(:company_id)
    self.job_title = params[:user][:job_title]
    self.helpdesk_agent = params[:user][:helpdesk_agent] || false
    update_companies(params) if params[:user][:added_companies].present?
    self.client_manager = params[:user][:client_manager]
    self.role_ids = params[:user][:role_ids] || []
    self.time_zone = params[:user][:time_zone]
    self.import_id = params[:user][:import_id]
    self.fb_profile_id = params[:user][:fb_profile_id]
    self.email = params[:user][:email].strip if params[:user][:email].present?
    self.language = params[:user][:language]
    self.address = params[:user][:address]
    self.tag_names = params[:user][:tag_names] # update tags in the user object
    self.custom_field = params[:user][:custom_field]
    self.avatar_attributes=params[:user][:avatar_attributes] unless params[:user][:avatar_attributes].nil?
    self.user_emails_attributes = params[:user][:user_emails_attributes] if params[:user][:user_emails_attributes].present?
    self.deleted = true if (email.present? && email =~ /MAILER-DAEMON@(.+)/i)
    self.created_from_email = params[:user][:created_from_email]
    self.detect_language = params[:user][:detect_language]
    if params[:user][:user_skills_attributes] && Account.current.skill_based_round_robin_enabled?
      self.skill_ids = params[:user][:user_skills_attributes].sort_by { |user_skill| 
        user_skill["rank"] }.map { |user_skill| 
          user_skill["skill_id"] }
    end
  end

  def signup!(params, portal = nil, send_activation = true, build_user_attributes = true)
    build_user_attributes(params) if build_user_attributes
    return false unless save_without_session_maintenance
    enqueue_activation_email(params[:email_config], portal) if !deleted and !email.blank? and send_activation and !Thread.current[:create_sandbox_account]
    true
  end

  def enqueue_activation_email(email_config = nil, portal = nil)
    portal.make_current if portal
    active_freshid_agent = active_freshid_agent?
    if self.language.nil?
      email_type = active_freshid_agent ? :deliver_agent_invitation! : :deliver_activation_instructions!
      args = active_freshid_agent ? [portal] : [ portal, false, email_config]
      Delayed::Job.enqueue(Delayed::PerformableMethod.new(self, email_type, args),
        nil, 5.minutes.from_now)
    else
      active_freshid_agent ? deliver_agent_invitation!(portal) : deliver_activation_instructions!(portal, false, email_config)
    end
  end

  # Used by API V2
  def create_contact!(status)
    self.avatar = self.avatar
    self.active = status if status
    begin
      return false unless save_without_session_maintenance
    rescue ActiveRecord::RecordNotUnique => e
      self.errors.add(:base, I18n.t("activerecord.errors.messages.email_not_unique")) if self[:email] and self[:account_id].present?
      Rails.logger.debug('::::::::API v2:#{e.message} error in contact create::::::::')
      return false
    end
    return true if import_id.present?

    if (!self.deleted and !self.email.blank?)
      portal = nil
      force_notification = false
      args = [ portal, force_notification ]
      if Thread.current["notifications_#{account_id}"].nil?
        Delayed::Job.enqueue(Delayed::PerformableMethod.new(self, :deliver_activation_instructions!, args), nil, 2.minutes.from_now)
      else
        deliver_activation_instructions!(*args)
      end
    end
    true
  end

  #This scope is currently used only for failure searches through ES for contact_merge search

  scope :matching_users_from, -> (search) {
          select(%(users.id, name, users.account_id, users.string_uc04, users.email, GROUP_CONCAT(user_emails.email) as `additional_email`,
            twitter_id, fb_profile_id, phone, mobile, job_title)).
          joins(%(left join user_emails on user_emails.user_id=users.id and
            user_emails.account_id = users.account_id) % { :str => "%#{search}%" }).
          where(%((name like '%<str>s' or user_emails.email
            like '%<str>s' and deleted = 0)) % {
            str: "%#{search}%"
          }).
          group('users.id')
        }

  scope :without, -> (source) { where("users.id <> %<id>i" % { id: source.id}) }

  #Used for importing google contacts
  def signup(portal=nil)
    return false unless save_without_session_maintenance
    deliver_activation_instructions!(portal,false) if (!deleted and self.email.present?)
    true
  end

  def active?
    active
  end

  def has_email?
    !self.email.blank?
  end


  def activate!(params)
    self.transaction do
      self.active = true
      params[:user][:name] = params[:user][:name] || (params[:user][:first_name] + ' ' + params[:user][:last_name])
      self.assign_attributes(params[:user].slice(*ACTIVATION_ATTRIBUTES))
      update_account_info_and_verify(params[:user]) if can_verify_account?
      self.user_emails.first.update_attributes({:verified => true}) unless self.user_emails.blank?
      #self.openid_identifier = params[:user][:openid_identifier]
      save!
    end
  end

  def delete_forever!
    new_pref = { :marked_for_hard_delete => true }
    self.merge_preferences = { :user_preferences => new_pref }
    self.save!
    Users::ContactDeleteForeverWorker.perform_in(HARD_DELETE_DELAY, user_id: id)
  end

  def update_account_info_and_verify(user_params)
    self.account.update_attributes!({:name => user_params[:company_name]}) if user_params.key?(:company_name) 
    self.account.main_portal.update_attributes!({:name => user_params[:company_name]}) if user_params.key?(:company_name)
    self.account.account_configuration.update_contact_company_info!(user_params)
  end

  def exist_in_db?
    !(id.blank?)
  end

  def has_no_credentials?
    self.crypted_password.blank? && active? && !account.sso_enabled? && !deleted && self.authorizations.empty? && self.twitter_id.blank? && self.fb_profile_id.blank? && self.external_id.blank? && self.unique_external_id.blank?
  end

  def first_name
    name_part("given").split.first
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
    company_client_manager?
  end

  def company_client_manager?
    default_user_company.present? && default_user_company.client_manager
  end

  # Marketplace
  def developer?
    marketplace_developer_application = Doorkeeper::Application.find_by_name(Marketplace::Constants::DEV_PORTAL_NAME)
    developer_privilege = access_tokens.find_by_application_id(marketplace_developer_application.id) if self.access_tokens
    !developer_privilege.blank?
  end

  def can_assume?(user)
    # => Not himself
    # => User is not deleted
    # => And the user does not have any admin privileges (He is an agent)
    # => the user does not have privilege to view secure information
    !((user == self) || user.deleted? || user.privilege?(:view_admin) || user.privilege?(:view_secure_field))
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
    return "#{format_name} <#{email}>" unless email.blank?
    return "#{name} (#{phone})" unless phone.blank?
    return "#{name} (#{mobile})" unless mobile.blank?
    return "@#{twitter_id}" unless twitter_id.blank?
    return "#{name} (#{unique_external_id})" if  (unique_external_id.present? && account.unique_contact_identifier_enabled?)
    name
  end

  def search_data
    if self.user_emails.present?
      self.user_emails.map{|x| {:id => id, :details => "#{format_name} <#{x.email}>", :value => name, :email => x.email}}
    else
      [{:id => id, :details => self.name_details, :value => name, :email => email.to_s }]
    end
  end

  ##Authorization copy ends here

  def url_protocol
    if account.main_portal_from_cache.portal_url.blank?
      return account.ssl_enabled? ? 'https' : 'http'
    else
      return account.main_portal_from_cache.ssl_enabled? ? 'https' : 'http'
    end
  end

  def can_edit_agent?(agent)
    !(agent.user.deleted? || (agent.user.privilege?(:manage_account) && !self.privilege?(:manage_account)))
  end

  def to_s
    user_display_text = name.blank? ? (email.blank? ? (phone.blank? ? mobile : phone) : email) : name
    user_display_text.to_s
  end

  def to_liquid
    @user_drop ||= UserDrop.new self
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
    (email) || (twitter_id.presence) || (external_id) || (unique_external_id) || (name)
  end

  #Used in ticket export api
  alias_method :contact_id, :get_info

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

  alias :all_tickets_permission?      :can_view_all_tickets?
  alias :group_tickets_permission?    :group_ticket_permission
  alias :assigned_tickets_permission? :assigned_ticket_permission

  # group_ticket?  have only write access groups in its operations
  # read_or_write_group_ticket?? have both read and write access groups in its operations
  # read_group_ticket? have only read access groups in its operations
  def read_or_write_group_ticket?(ticket)
    read_or_write_group_ticket_member?(ticket.group_id) ||
      (Account.current.shared_ownership_enabled? ? read_or_write_group_ticket_member?(ticket.internal_group_id) : false) # TODO: check whether shared_ownership check required?
  end

  def read_or_write_group_ticket_member?(group_id)
    group_id && all_associated_group_ids.include?(group_id)
  end

  def read_group_ticket?(ticket)
    read_group_ticket_member?(ticket.group_id)
  end

  def read_group_ticket_member?(group_id)
    group_id && read_associated_group_ids.include?(group_id)
  end

  # associated_group_ids have only write access groups
  # all_associated_group_ids have both read and write access groups
  def all_associated_group_ids
    agent.all_agent_groups_from_cache.map(&:group_id)
  end

  def associated_group_ids
    agent.all_agent_groups_from_cache.select{ |record| record.write_access.present? }.map(&:group_id)
  end

  def read_associated_group_ids
    @read_associated_group_ids ||= agent.all_agent_groups_from_cache.select{ |record| record.write_access.blank? }.map(&:group_id)
  end

  def group_ticket?(ticket, agent_group_ids = nil)
    group_member?(ticket.group_id, agent_group_ids) ||
      (Account.current.shared_ownership_enabled? ? group_member?(ticket.internal_group_id, agent_group_ids) : false)
  end

  def group_member?(group_id, agent_group_ids = nil)
    group_id && (agent_group_ids.nil? ? associated_group_ids.include?(group_id) : agent_group_ids.include?(group_id))
  end

  
  def ticket_agent?(ticket)
    ticket.responder_id == self.id || (Account.current.shared_ownership_enabled? ? ticket.internal_agent_id == self.id : false)
  end

  def has_ticket_permission?(ticket, agent_group_ids = nil)
    (ticket_agent?(ticket) && !read_group_ticket?(ticket)) || can_view_all_tickets? || (group_ticket_permission && group_ticket?(ticket, agent_group_ids))
  end

  def has_read_ticket_permission?(ticket)
    ticket_agent?(ticket) || can_view_all_tickets? || (group_ticket_permission && read_or_write_group_ticket?(ticket))
  end

  def only_read_ticket_permission?(ticket)
    # Shouldn't have write access privilege , but only read access
    has_read_ticket_permission?(ticket) && !has_ticket_permission?(ticket)
  end

  # For a customer we need to check if he is the requester of the ticket
  # Or if he is allowed to view tickets from his company
  def has_customer_ticket_permission?(ticket)
    (self.id == ticket.requester_id) or
    (is_client_manager? && self.company_id && ticket.company_id && (self.company_ids.include?(ticket.company_id)) ) or
    (self.contractor_ticket? ticket)
  end

  def restricted?
    !can_view_all_tickets?
  end

  def to_xml(options=USER_API_OPTIONS)
    process_api_options USER_API_OPTIONS, options
    super options do |builder|
      unless helpdesk_agent
        builder.custom_field do
          custom_field.each do |name, value|
            builder.tag!(name,value) unless value.nil?
          end
        end
      end
    end
  end

  def as_json(options = nil, do_not_process_options = false)
    default_options = helpdesk_agent? ? USER_API_OPTIONS : CONTACT_API_OPTIONS
    options ||= default_options
    process_api_options default_options, options unless do_not_process_options
    super(options)
  end

  def has_company?
    customer? and company_ids.any?
  end

  def company_segment_ids
    company_segments = []
    companies.each do |c| 
      company_segments << Segments::Match::Company.new(c).ids
    end    
    company_segments.flatten.uniq
  end

  def has_company_segment?
    customer? and company_segment_ids.present?
  end

  def company_segment_ids_str
    company_segment_ids.join(",")
  end

  def company_name= name
    if name.present?
      comp = find_or_create_company(name)
      build_or_update_company(comp.id) if comp.present?
    else
      mark_user_company_destroy
    end
  end

  def company_name
    if has_multiple_companies_feature?
      uc = user_companies.find { |uc| uc.default }
      uc.company.name if uc.present? && uc.company.present?
    else
      default_user_company.company.name if default_user_company.present? && default_user_company.company.present?
    end
  end

  def company_id= comp_id
    if comp_id.present?
      build_or_update_company(comp_id)
    else
      mark_user_company_destroy
    end
  end

  def company_id
    default_user_company.company_id if default_user_company.present?
  end

  def company_ids
    user_companies.map(&:company_id)
  end

  def has_contact_segment?
    customer? and segments.present? #checks for contact segment
  end

  def contact_segment_ids_str
    segments.join(",")
  end

  def company_names
    companies.map(&:name)
  end

  def company_names_for_export
    company_names.join(" || ")
  end

  def emails_for_export
    self.emails.join(" || ")
  end

  def client_managers_for_export
    user_companies.map(&:client_manager).join(" || ")
  end

  def company_ids_str
    contractor? ? company_ids.join(",") : company_id
  end

  def client_manager_companies
    companies.where("user_companies.client_manager = 1")
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

  def reset_primary_email(primary = nil, primary_user_email = nil)
    # Web does not allow a new email to be the primary_email for a contact, but it should be allowed via API
    return true if primary.nil? && primary_user_email.nil?

    if primary_user_email
      new_primary = primary_user_email
    else
      new_primary = self.user_emails.find(primary.to_i)
    end

    if new_primary
      self.user_emails.update_all(:primary_role => false)
      new_primary.toggle!(:primary_role) #can refactor
    end
    return true
  end

  def make_customer
    return true if customer?
    set_company_name
    self.helpdesk_agent = false
    self.deleted = false
    new_pref = { :was_agent => true }
    self.merge_preferences = { :user_preferences => new_pref }

    if self.save
      self.cti_phone = nil
      agent.destroy
      deliver_password_reset_instructions!(nil) if freshid_integration_enabled_account?
      freshfone_user.destroy if freshfone_user

      expiry_period = self.user_policy ? FDPasswordPolicy::Constants::GRACE_PERIOD : FDPasswordPolicy::Constants::NEVER.to_i.days
      self.set_password_expiry({:password_expiry_date =>
              (Time.now.utc + expiry_period).to_s})
      return true
    end
    return false
  end

  def make_agent(args = {})
    ActiveRecord::Base.transaction do
      self.user_emails = [self.primary_email]
      self.deleted = args[:deleted] || false
      self.helpdesk_agent = true
      self.address = nil
      self.role_ids = args[:role_ids] || default_agent_role(args[:type])
      self.tags.clear
      self.user_companies.delete_all
      self.user_companies.reload
      self.customer_id = nil
      agent = build_agent()
      agent.occasional = !!args[:occasional]
      agent.group_ids = args[:group_ids] if args.key?(:group_ids)
      agent.ticket_permission = fetch_agent_ticket_scope(args)
      agent.signature_html = args[:signature_html] if args.key?(:signature_html)
      agent.agent_type = args[:type].present? ? AgentType.agent_type_id(args[:type]) : Agent::SUPPORT_AGENT_TYPE


      expiry_period = self.user_policy ? FDPasswordPolicy::Constants::GRACE_PERIOD : FDPasswordPolicy::Constants::NEVER.to_i.days
      self.set_password_expiry({:password_expiry_date =>
          (Time.now.utc + expiry_period).to_s}, false)
      reset_persistence_token
      self.active = self.primary_email.verified = false if freshid_integration_enabled_account?
      save ? true : (raise ActiveRecord::Rollback)
    end
  end

  def fetch_agent_ticket_scope(args)
    default_ticket_permission = args[:type] == Agent::FIELD_AGENT ? Agent::PERMISSION_KEYS_BY_TOKEN[:assigned_tickets] : Agent::PERMISSION_KEYS_BY_TOKEN[:all_tickets]
    args[:ticket_permission] || default_ticket_permission
  end

  def default_agent_role(agent_type)
    if agent_type == Agent::FIELD_AGENT
      account.roles.field_agent.map(&:id)
    else
      account.roles.agent.map(&:id)
    end
  end

  def update_search_index
    SearchSidekiq::IndexUpdate::UserTickets.perform_async({ :user_id => id }) if Account.current.esv1_enabled?
  end

  def moderator_of?(forum)
    moderatorships.where(['forum_id = ?', (forum.is_a?(Forum) ? forum.id : forum)]).count == 1
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

  def language_object
    Language.find_by_code(language.to_s)
  end

  def language_name
    Language.find_by_code(self.language.to_s).try(:name)
  end

  def supported_language
    # added defined check to handle boolean value
    @supported_language = (Account.current.supported_languages.include?(language) && language_object.to_key) unless defined?(@supported_language)
    @supported_language
  end

  def custom_form
    helpdesk_agent? ? nil : (Account.current || account).contact_form # memcache this
  end

  def custom_field_aliases
    @custom_field_aliases ||= (helpdesk_agent? || (Account.current || account).blank?) ? [] : custom_form.custom_contact_fields.map(&:name)
  end

  def custom_field_types
    @custom_field_types ||= (helpdesk_agent? || (Account.current || account).blank?) ? {} : custom_form.custom_contact_fields.inject({}) { |types,field| types.merge(field.name => field.field_type) }
  end

  def custom_field= custom_field_hash
    self.custom_fields_hash = custom_field_hash
    unless custom_field_hash.blank?
      @custom_field = nil # resetting to reflect the assignments properly
      assign_ff_values custom_field_hash
    end
  end

  def self.search_by_name search_by, account_id, options = { :load => true, :page => 1, :size => 10, :preference => :_primary_first }
    return [] if search_by.blank? || (search_by = search_by.gsub(/[\^\$]/, '')).blank?
    begin
      Search::EsIndexDefinition.es_cluster(account_id)
      item = Tire.search Search::EsIndexDefinition.searchable_aliases([User], account_id), options do |search|
        search.query do |query|
          query.filtered do |f|
            if SearchUtil.es_exact_match?(search_by)
              f.query { |q| q.match ["name", "email", "user_emails.email"], SearchUtil.es_filter_exact(search_by), :type => :phrase }
            else
              f.query { |q| q.string SearchUtil.es_filter_key(search_by), :fields => ['name', 'email', 'user_emails.email'], :analyzer => "include_stop" }
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


  # Hack to sanitize phone, mobile from api when passed as integer
  def phone=(value)
    value = value.nil? ? value : value.to_s
    write_attribute(:phone, RailsFullSanitizer.sanitize(value))
  end

  def mobile=(value)
    value = value.nil? ? value : value.to_s
    write_attribute(:mobile, RailsFullSanitizer.sanitize(value))
  end
  # Hack ends here

  def company
    companies.sorted.first
  end

  def accessible_groups
    privilege?(:admin_tasks) ? Account.current.groups : self.groups
  end

  def accessible_roundrobin_groups
    self.accessible_groups.round_robin_groups
  end

  def no_of_assigned_tickets group
    # Only for skill based round robin
    queue_aggregator = SBRR::QueueAggregator::User.new self, :group => group
    queue = queue_aggregator.relevant_queues.first
    if queue
      score = queue.zscore(self.id)
      assigned_tickets_count = SBRR::ScoreCalculator::User.new(nil, score.to_i).old_assigned_tickets_in_group
    end
    SBRR.log "User #{self.id} Accessed assigned_tickets_count : #{assigned_tickets_count}" 
    assigned_tickets_count
  end

  def match_sbrr_conditions?(_ticket)
    _ticket.match_sbrr_conditions?(self)
  end

  def assign_company comp_name
    if has_multiple_companies_feature?
      comp = find_or_create_company(comp_name)
      self.user_companies.build(company_id: comp.id) if comp.present? &&
        self.user_companies.find_by_company_id(comp.id).blank?
    else
      self.company_name = comp_name
    end
  end

  def assign_external_id ext_id
    if Account.current.unique_contact_identifier_enabled?
      user_with_ext_id = Account.current.all_users.where("id != ? AND unique_external_id = ?", id, ext_id).first if ext_id.present?
      self.unique_external_id = ext_id if user_with_ext_id.nil?
    end
  end

  def sync_to_export_service
    scheduled_ticket_exports.each do |schedule|
      schedule.sync_to_service("update")
    end
  end

  def can_verify_account?
    !account.verified? && self.privilege?(:admin_tasks)
  end

  def gdpr_pending?
    agent_preferences[:gdpr_acceptance]
  end

  def current_user_gdpr_admin
      Account.current.agents_details_from_cache.find{ |n| n.id == agent_preferences[:gdpr_admin_id]}.try(:name) if gdpr_pending?
  end

  def agent_preferences
    self.preferences[:agent_preferences]
  end

  def email_id_changed?
    email_changed? && case_insensitive_value_changed?(email_change)
  end

  def active_and_verified?
    active? && primary_email.verified?
  end

  def proactive_email_outreach_unsubscribe
    new_pref = { simple_outreach_unsubscribe: true }
    self.merge_preferences = { user_preferences: new_pref }
    save
  end

  def privilege?(privilege)
    if CONTACT_COMPANY_PRIVILEGES_SPLIT.include?(privilege) &&
       !account.launched?(:contact_company_split)
      privilege = privilege == :manage_companies ? :manage_contacts : :delete_contact
    end
    super
  end

  def twitter_requester_fields
    {
      'twitter_profile_status'  => twitter_profile_status,
      'twitter_followers_count' => twitter_followers_count
    }
  end

  def preferred_source
    Helpdesk::Source.ticket_source_token_by_key[preferences[:preferred_source]]
  end

  def add_preferred_source(source)
    unless preferences[:preferred_source] && preferences[:preferred_source] == source
      self.merge_preferences = { preferred_source: source }
      save
    end
  end

  def mark_perishable_token_expiry
    set_others_redis_key(perishable_token_expiry_key, true, 30.minutes)
  end

  def perishable_token_expired?
    value = get_others_redis_key(perishable_token_expiry_key)
    value.blank? || value != 'true'
  end

  private

    def perishable_token_expiry_key
      format(PERISHABLE_TOKEN_EXPIRY, account_id: account_id, user_id: id)
    end

    def find_or_create_company(name)
      if User.current.present?
        if User.current.privilege?(:manage_companies)
          account.companies.where(name: name).first_or_create
        else
          account.companies.find_by_name(name)
        end
      else
        account.companies.where(name: name).first_or_create
      end
    end

    def name_part(part)
      part = parsed_name[part].blank? ? "particle" : part unless parsed_name.blank? and part == "family"
      parsed_name[part].blank? ? name : parsed_name[part]
    end

    def trim_attributes
      self.unique_external_id = self.unique_external_id.try(:strip).presence
    end

    def parsed_name
      @parsed_name ||= Namae::Name.parse(self.name)
    end

    def backup_user_changes
      @all_changes = self.changes.clone.to_hash
      @all_changes.merge!(flexifield.changes)
      @all_changes.merge!(tag_names: self.tags.map(&:name)) if self.tags_updated
      @all_changes.merge!({ tags: [] }) if self.tags_updated #=> Hack for when only tags are updated to trigger ES publish
      @all_changes.symbolize_keys!
    end

    def helpdesk_agent_updated?
      @all_changes.has_key?(:helpdesk_agent)
    end

    def converted_to_agent?
      helpdesk_agent_updated? and agent?
    end

    def converted_to_contact?
      helpdesk_agent_updated? and !agent?
    end

    def email_updated?
      @all_changes.key?(:email) && case_insensitive_value_changed?(@all_changes[:email])
    end

    def case_insensitive_value_changed?(change_values)
      change_values.include?(nil) || change_values[0].casecmp(change_values[1]) != 0
    end

    def converted_to_agent_or_email_updated?
      converted_to_agent? || email_updated?
    end

    def deleted_updated?
       @all_changes.has_key?(:deleted)
    end

    def blocked_updated?
       @all_changes.has_key?(:blocked)
    end

    def time_zone_updated?
      @all_changes.has_key?(:time_zone)
    end

    def clear_redis_for_agent
      if helpdesk_agent_changed? and !agent?
        self.agent_groups.each do |ag|
          group = ag.group
          group.remove_agent_from_round_robin(self.id) if group.lbrr_enabled?
        end
      end
    end

    def touch_add_role_change(role)
      touch_role_change(role)
    end

    def touch_remove_role_change(role)
      touch_role_change(role, true)
    end

    def touch_role_change(role, remove = false)
      if self.agent.present?
        role_info = { id: role.id, name: role.name }
        self.agent.user_changes ||= {"roles" => {added: [], removed: []}}
        roles_key = remove ? :removed : :added
        self.agent.user_changes["roles"].present? ? 
          self.agent.user_changes["roles"][roles_key].push(role_info) :
          self.agent.user_changes["roles"] = { roles_key => [role_info] }
      end
      privileges_will_change!
      @role_change_flag = true
    end

    def roles_changed?
      !!@role_change_flag
    end

    def has_role?
      self.errors.add(:base, I18n.t("activerecord.errors.messages.user_role")) if
        ((@role_change_flag or new_record?) && self.roles.blank?)
    end

    def password_updated?
      @all_changes.has_key?(:crypted_password)
    end

    #This is the current login method. It is fed to authlogic in user_sessions.rb

    def self.find_by_user_emails(login)
      # Without using select will results in making the user object readonly.
      # http://stackoverflow.com/questions/639171/what-is-causing-this-activerecordreadonlyrecord-error
      user = User.select("`users`.*").joins("INNER JOIN `user_emails` ON `user_emails`.`user_id` = `users`.`id` AND `user_emails`.`account_id` = `users`.`account_id`").where(account_id: Account.current.id, user_emails: {email: login}).first
      user if user and user.active? and !user.blocked?
    end

    def process_api_options default_options, current_options
      default_options.each do |key, value|
        current_options[key] = current_options.key?(key) ? current_options[key] & default_options[key] : default_options[key]
      end
    end

    def format_name
      (name =~ SPECIAL_CHARACTERS_REGEX and name !~ /".+"/) ? "\"#{name}\"" : name
    end

    def build_or_update_company comp_id
      default_user_company.present? ? (self.default_user_company.company_id = comp_id) :
        self.build_default_user_company(:company_id => comp_id)
      user_comp = self.user_companies.find { |uc| uc.default }
      if user_comp.present?
        user_comp.company_id = default_user_company.company_id
      else
        self.user_companies = [default_user_company] if default_user_company.valid?
      end
    end

    def mark_user_company_destroy
      uc = default_user_company
      if uc
        self.default_user_company_attributes = { :id => uc.id,
                                            :company_id => uc.company_id,
                                            :user_id => uc.user_id,
                                            :_destroy => true }
        self.customer_id = nil
      end
    end

    def check_roles_for_field_agents
      valid_role = true
      if (self.role_ids - account.roles.field_agent.map(&:id)).present?
        self.errors.add(:role_ids, :field_agent_roles, role: 'field technician')
        valid_role = false
      end
      valid_role
    end

    def validate_agent
      agent = self.agent
      return if agent.valid?
      agent.errors.messages.each do |attr, msg|
        self.errors.add(attr, msg[0])
      end
      false
    end
end
