require_dependency "mobile/actions/portal"
require_dependency "cache/memcache/portal"
class Portal < ActiveRecord::Base

  self.primary_key = :id

  include Redis::OthersRedis
  include Redis::Keys::Others
  HEX_COLOR_REGEX = /^#([A-Fa-f0-9]{6}|[A-Fa-f0-9]{3})$/
  VERIFICATION_HASH_SECRET = 'f1cb366f-c4e7-4fde-b761-995fd5e5fbf7'.freeze

  serialize :preferences, Hash

  attr_protected  :account_id
  attr_accessor :language_list

  publishable on: [:create, :update, :destroy]
  xss_sanitize  :only => [:name,:language], :plain_sanitizer => [:name,:language]
  validates_uniqueness_of :portal_url, :allow_blank => true, :allow_nil => true, :if => :portal_url_changed?
  validates_format_of :portal_url, :with => %r"^(?!.*\.#{Helpdesk::HOST[Rails.env.to_sym]}$)[/\w\.-]+$",
  :allow_nil => true, :allow_blank => true
  validate :cname_owner, :if => :portal_url_changed?
  validates_inclusion_of :language, :in => Language.all_codes, :if => :language_changed?
  validate :validate_preferences
  before_update :backup_portal_changes , :if => :main_portal
  after_commit :update_solutions_language, on: :update, if: :main_portal_language_changes?
  after_commit :update_help_widget_language, on: :update, if: -> { Account.current.help_widget_enabled? && main_portal_language_changes? }
  delegate :friendly_email, :to => :product, :allow_nil => true
  before_save :downcase_portal_url
  after_save :update_chat_widget
  after_commit :update_site_language, :publish_account_central_payload, :if => :main_portal_language_changes?
  before_save :update_portal_forum_categories
  before_save :save_route_info
  after_destroy :destroy_route_info

  before_create :update_custom_portal
  after_create :update_custom_portal
  before_update :update_custom_portal
  after_commit :toggle_autofaq_features, :on => :update, if: :main_portal_language_changes?
  before_save :create_model_changes, on: :update
  before_destroy :save_deleted_portal_info

  include Mobile::Actions::Portal
  include Cache::Memcache::Portal
  include Redis::RedisKeys
  include Redis::PortalRedis

  has_one :logo,
    :as => :attachable,
    :class_name => 'Helpdesk::Attachment',
    :conditions =>  [' description = ? ', 'logo' ],
    :dependent => :destroy

  has_one :fav_icon,
    :as => :attachable,
    :class_name => 'Helpdesk::Attachment',
    :conditions => [' description = ?', 'fav_icon' ],
    :dependent => :destroy

  has_one :helpdesk_logo,
          as: :attachable,
          class_name: 'Helpdesk::Attachment',
          conditions: { attachable_type: AttachmentConstants::ATTACHABLE_TYPES['portal'], description: 'mint_logo' },
          foreign_key: 'attachable_id',
          dependent: :destroy

  has_one :template, :class_name => 'Portal::Template'

  has_one :freddy_bot, class_name: 'Freddy::Bot', dependent: :destroy

  has_many :portal_forum_categories,
    :class_name => 'PortalForumCategory',
    :foreign_key => :portal_id,
    :order => "position",
    :dependent => :delete_all

  has_many :forum_categories,
    :class_name => 'ForumCategory',
    :through => :portal_forum_categories,
    :order => "portal_forum_categories.position"

  has_one :primary_email_config, :class_name => 'EmailConfig', :through => :product

  has_one :bot, class_name: 'Bot', dependent: :destroy

  has_many :monitorships, :dependent => :nullify

  belongs_to_account
  belongs_to :product

  concerned_with :solution_associations, :presenter

  APP_CACHE_VERSION = "FD80"

  def logo_attributes=(icon_attr)
    handle_icon 'logo', icon_attr
  end

  def fav_icon_attributes=(icon_attr)
    handle_icon 'fav_icon', icon_attr
  end

  def fav_icon_url
    fav_icon.nil? ? '/assets/misc/favicon.ico' : fav_icon.content.url
  end

  def portal_forums
    account.forums.in_categories(forum_category_ids)
  end

  def has_solution_category? category_meta_id
    portal_solution_categories.find_by_solution_category_meta_id(category_meta_id).present?
  end

  def has_forum_category? category
    portal_forum_categories.map(&:forum_category_id).include?(category.id)
  end

  def recent_popular_topics( user, days_before = (DateTime.now - 30.days) )
    account.topics.topics_for_portal(self).visible(user).published.popular(days_before).limit(10)
  end

  def recent_portal_topics user, limit = 6
    limit = 100 if limit.to_i > 100
    account.
      topics.topics_for_portal(self).
      published.visible(user).newest.
      preload(:user, :forum, :last_post => {:user => :avatar}).limit(limit)
  end

  def my_topics(user, per_page, page)
    user.monitored_topics.published.topics_for_portal(self).filter(per_page, page)
  end

  def my_topics_count(user)
    user.monitored_topics.published.topics_for_portal(self).count
  end

  # Yeah.. It is ugly.
  def ticket_fields(additional_scope = :all, include_translation = false)
    fields = account.ticket_fields.safe_send(additional_scope)
    fields = fields.preload(preload_translations(include_translation)) if additional_scope == :customer_visible
    filter_fields fields, ticket_field_conditions
  end

  def ticket_fields_including_nested_fields(additional_scope = :all)
    filter_fields account.ticket_fields_including_nested_fields.safe_send(additional_scope), ticket_field_conditions
  end

  def all_ticket_fields(additional_scope = :all)
    all_fields = []
    account.ticket_fields_including_nested_fields.safe_send(additional_scope).each do |field|
      all_fields << field
      all_fields << field.nested_ticket_fields if field.parent_nested_field?
    end
    filter_fields all_fields.flatten.uniq, ticket_field_conditions
  end

  # include_translation is used for whether we need to preload custom_translations or not
  def customer_editable_ticket_fields(include_translation = false, include_secure_fields = false)
    # For Support we should allow secure fields to be editable
    if include_secure_fields
      support_editable_ticket_fields
    else
      filter_fields account.ticket_fields_including_nested_fields.customer_editable.non_secure_fields.preload(preload_translations(include_translation)), ticket_field_conditions
    end
  end

  # this is used only in support ticket details page
  def support_editable_ticket_fields(include_translation = false)
    filter_fields account.ticket_fields_including_nested_fields.customer_editable.preload(preload_translations(include_translation)), ticket_field_conditions
  end

  def layout
    self.template.layout
  end

  def to_liquid
    @portal_drop ||= (PortalDrop.new self)
    # PortalDrop.new self
  end

  def host
    portal_url.blank? ? account.full_domain : portal_url
  end

  def ssl_enabled?
    portal_url.blank? ? account.ssl_enabled : ssl_enabled
  end

  def portal_name
    (name.blank? && product) ? product.name : name
  end

  def logo_url
    logo.content.url(:logo) unless logo.nil?
  end

  def fav_icon_url
    fav_icon.content.url unless fav_icon.nil?
  end

  def cache_prefix
    "#{APP_CACHE_VERSION}/v#{cache_version}/#{language}/#{self.id}"
  end

  def make_current
    Thread.current[:portal] = self
  end

  def self.current
    Thread.current[:portal]
  end

  def self.reset_current_portal
      Thread.current[:portal] = nil
  end

  def url_protocol
    self.ssl_enabled? ? 'https' : 'http'
  end

  def full_url
    main_portal ? "#{Account.current.full_url}/support/home" : "#{url_protocol}://#{portal_url}/support/home"
  end

  def full_name
    main_portal && name.blank? ? Account.current.name : name
  end

  def multilingual?
    @is_multilingual ||= Account.current.multilingual? && (Account.current.portal_languages.present? || (User.current && User.current.agent?))
  end

  def tickets_url
    main_portal ? "#{Account.current.full_url}/support/tickets" : "#{url_protocol}://#{portal_url}/support/tickets"
  end

  def cname_verification_hash
    @cname_verification_hash ||= OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('MD5'),
                              "#{VERIFICATION_HASH_SECRET}-%{#{Account.current.id}}",
                                %{#{Account.current.id}})
  end

  def matches_host?(hostname)
    account_domains = domains_for_recaptcha
    Rails.logger.debug("::::reCAPTCHA response::::: accountId => #{account.id}, domains => #{account_domains.inspect}, reCAPTCHA hostname => #{hostname}")
    account_domains.include?(hostname.downcase) if hostname.present?
  end

  def save_deleted_portal_info
    @deleted_model_info = as_api_response(:central_publish_destroy)
  end

  def publish_account_central_payload
    model_changes = construct_model_changes
    if model_changes.present?
      account.model_changes = model_changes
      # account payload will anyway be sent and hence no need to manual publish
    end
  end

  def construct_model_changes
    changes = {}
    prev_languages = [@portal_changes['language'].first] + account.supported_languages
    current_languages = [language] + account.supported_languages
    changes[:all_languages] = [prev_languages, current_languages]
    changes
  end

  def bot_info
    logo_url = logo.content.url if logo.present?
    bot_name, bot_id = [bot.name, bot.id] if bot
    {
      name: name,
      portal_enabled: true,
      portal_id: id,
      portal_logo: logo_url,
      bot_name: bot_name,
      bot_id: bot_id
    }
  end

  def personalized_articles?
    return false if preferences[:personalized_articles].blank?
    preferences[:personalized_articles].class == String ? preferences[:personalized_articles].to_bool : preferences[:personalized_articles]
  end

  def falcon_portal_enable?
    preferences.key?(:falcon_portal_key)
  end

  def solution_category_metum_ids=(category_attr)
    # The below line is needed, as we created portals before soln categories, while creating an account.
    return if account.solution_category_meta.empty?

    # empty string is passed in param (which is 0 after to_i) and needs to be removed to avoid building it
    category_ids = category_attr.map(&:to_i) - [0]
    default_category_meta = account.solution_category_meta.find_by_is_default(true)
    category_ids |= [default_category_meta.id] if default_category_meta.present?
    portal_solution_categories.where('solution_category_meta_id NOT IN (?)', category_ids).destroy_all
    (category_ids - portal_solution_categories.pluck(:solution_category_meta_id)).each do |category_meta_id|
      portal_solution_categories.build(solution_category_meta_id: category_meta_id)
    end
  end

  private
  
    ### MULTILINGUAL SOLUTIONS - META READ HACK!! - shouldn't be necessary after we let users decide the language
    def update_solutions_language
      Community::HandleLanguageChange.perform_async unless account.features_included?(:enable_multilingual)
    end

    def update_help_widget_language
      Account.current.help_widgets.active.map(&:upload_configs)
    end

    def main_portal_language_changes?
      main_portal && @portal_changes && @portal_changes.has_key?(:language)
    end

    def create_model_changes
      @model_changes = self.changes.to_hash
      @model_changes.symbolize_keys!
    end

    def backup_portal_changes
      @portal_changes = self.changes.clone
    end

    def handle_icon(icon_field, icon_attr)
      unless safe_send(icon_field)
        icon = safe_send("build_#{icon_field}")
        icon.description = icon_field
        icon.content = icon_attr[:content]
        icon.account_id = account_id
      else
        safe_send(icon_field).update_attributes(icon_attr)
      end
    end

    def downcase_portal_url
      self.portal_url = portal_url.downcase if portal_url
    end

    def validate_preferences
      preferences.each do |key, value|
        if ["header_color", "tab_color", "bg_color"].include?(key)
          errors.add(:base, "Please enter a valid hex color value.") unless value =~ HEX_COLOR_REGEX
        elsif key == 'contact_info'
          preferences[key] = RailsFullSanitizer.sanitize(value)
        elsif key == 'logo_link' && preferences[key].present?
          sanitized_value = RailsFullSanitizer.sanitize(value) #Prevent Xss
          uri_validation = account.old_link_back_url_validation_enabled? ? UriParser.valid_url?(value) : UriParser.valid_irl?(value, false)
          errors.add(:base, I18n.t('admin.products.portal.invalid_linkback_url')) unless sanitized_value == value && uri_validation
        end
      end
    end

    def ticket_field_conditions
      { 'product' => (main_portal && !account.products.empty?),
        'company' => account.multiple_user_companies_enabled? && User.current.present? &&
                      (User.current.agent? || User.current.contractor?) }
    end

    def filter_fields(f_list, conditions)
      to_ret = []

      f_list.each { |field| to_ret.push(field) if conditions.fetch(field.name, true) }
      to_ret
    end

    def cache_version
      key = PORTAL_CACHE_VERSION % { :account_id => self.account_id }
      get_portal_redis_key(key) || "0"
    end

    def update_chat_widget
      if account.features?(:chat)
        if product && (portal_url_changed? || language_changed?)
          site_id = account.chat_setting.site_id
          chat_widget = product.chat_widget
          chat_widget.id = chat_widget.widget_id
          if chat_widget && chat_widget.id
            LivechatWorker.perform_async(
              worker_method: 'update_widget',
              widget_id: chat_widget.id,
              siteId: site_id,
              attributes: { site_url: portal_url, language: language }
            )
          end
        end
      end
    end

    def update_site_language
      if account.features?(:chat)
        site_id = account.chat_setting.site_id
        chat_widget = account.main_chat_widget
        chat_widget.id = chat_widget.widget_id
        if chat_widget && chat_widget.id
          LivechatWorker.perform_async(
            worker_method: 'update_site',
            widget_id: chat_widget.id,
            siteId: site_id,
            attributes: { language: language }
          )
        end
      end
    end

    def update_portal_forum_categories
      if forum_category_id_changed?
        portal_forum_categories.first.delete if !portal_forum_categories.empty?
        portal_forum_categories.build(:forum_category_id => forum_category_id) if forum_category_id?
      end
    end

    def toggle_autofaq_features
      unless ismember?(SYSTEM42_SUPPORTED_LANGUAGES, account.language)
        account.reset_feature(:autofaq)
        account.reset_feature(:botflow)
        account.save
      end
    end

    def save_route_info
      if portal_url_changed?
        Rails.logger.info "portal_url changed #{portal_url}"
        destroy_route_info(portal_url_was) unless portal_url_was.blank? #delete old portal url
        Redis::RoutesRedis.set_route_info(portal_url, account_id, account.full_domain) unless portal_url.blank? #add new portal url
      end
    end

    def destroy_route_info(old_portal_url = portal_url)
      Rails.logger.info "Deleting #{old_portal_url} route."
      Redis::RoutesRedis.delete_route_info(old_portal_url) unless old_portal_url.blank?
    end

    def clear_solution_cache(obj=nil)
      Account.current.clear_solution_categories_from_cache
    end

    # * * * POD Operation Methods Begin * * *
    def update_custom_portal
      if Fdadmin::APICalls.non_global_pods? && portal_url_changed? && !portal_url.blank?
        action = (safe_send(:transaction_include_action?, :create) && new_record?) ? :create : :update
        request_parameters = {
          :target_method => :update_domain_mapping_for_pod,
          :operation => action,
          :old_domain => portal_url_was,
          :custom_portal => {
            :portal_id => id,
            :account_id => account_id,
            :domain => portal_url
          }
        }
        begin
          response = Fdadmin::APICalls.connect_main_pod(request_parameters)
          raise ActiveRecord::Rollback unless response["account_id"]
        rescue Exception => e
          errors[:base] << "Portal url has already been taken"
          return false
        end
      end
    end
  # * * * POD Operation Methods End * * *

    # As a security measure, we expect the CNAME entry to match the freshdesk account's domain
    # This can match either the Freshdesk full domain or the elb domain for SSL enabled accounts

    def cname_owner
      return if portal_url.blank? || Account.current.skip_portal_cname_chk_enabled?

      cname_validator = CustomDomain::CnameValidator.new(portal_url, domains_for_account, cname_verification_hash)
      errors.add(:base, I18n.t('flash.portal.update.invalid_cname')) unless cname_validator.cname_mapping?
      errors.add(:base, I18n.t('flash.portal.update.invalid_hash_mapping')) unless cname_validator.txt_mapping?
    end

    def domains_for_account
      valid_domains = [Account.current.full_domain]
      valid_domains << elb_dns_name if elb_dns_name.present?
      unless main_portal
        account_main_portal = Account.current.main_portal_from_cache
        valid_domains << account_main_portal.elb_dns_name if account_main_portal.elb_dns_name.present?
      end
      valid_domains.map { |d| d.downcase.chomp('.') }
    end

    def domains_for_recaptcha
      valid_domains = [account.full_domain]
      valid_domains << portal_url if portal_url.present?
      valid_domains
    end

    def preload_translations(include_translation = false)
      @preload_translations ||= if Account.current.custom_translations_enabled? && include_translation
                                  language = Language.current
                                  language ||= User.current ? User.current.language_object : Language.find_by_code(I18n.locale)
                                  Account.current.supported_languages.include?(language.code) ? ["#{language.to_key}_translation".to_sym, { nested_ticket_fields: { ticket_field: ["#{language.to_key}_translation".to_sym] } }] : []
                                else
                                  []
                                end
    end

end
