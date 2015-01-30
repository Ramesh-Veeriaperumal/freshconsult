class Portal < ActiveRecord::Base
  include ActionController::UrlWriter

  HEX_COLOR_REGEX = /^#([A-Fa-f0-9]{6}|[A-Fa-f0-9]{3})$/

  serialize :preferences, Hash

  attr_protected  :account_id

  xss_sanitize  :only => [:name,:language], :plain_sanitizer => [:name,:language]
  validates_uniqueness_of :portal_url, :allow_blank => true, :allow_nil => true
  validates_format_of :portal_url, :with => %r"^(?!.*\.#{Helpdesk::HOST[Rails.env.to_sym]}$)[/\w\.-]+$",
  :allow_nil => true, :allow_blank => true
  validate :validate_preferences
  before_update :backup_portal_changes , :if => :main_portal
  after_commit_on_update :update_users_language, :if => :main_portal_language_changes?
  delegate :friendly_email, :to => :product, :allow_nil => true
  before_save :downcase_portal_url
  after_save :update_chat_widget
  before_save :update_portal_forum_categories

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

  has_one :template, :class_name => 'Portal::Template'

  has_many :portal_solution_categories,
    :class_name => 'PortalSolutionCategory',
    :foreign_key => :portal_id,
    :order => "position",
    :dependent => :delete_all

  has_many :solution_categories,
    :class_name => 'Solution::Category',
    :through => :portal_solution_categories,
    :order => "portal_solution_categories.position"

  has_many :portal_forum_categories,
    :class_name => 'PortalForumCategory',
    :foreign_key => :portal_id,
    :order => "position",
    :dependent => :delete_all

  # has_many :forum_categories,
  #   :class_name => 'ForumCategory',
  #   :through => :portal_forum_categories,
  #   :order => "portal_forum_categories.position",
  #   :foreign_key => :forum_category_id

  # has_many :forums,
  #   :class_name => 'Forum',
  #   :through => :forum_categories

  has_one :primary_email_config, :class_name => 'EmailConfig', :through => :product

  has_many :monitorships, :dependent => :nullify

  belongs_to_account
  belongs_to :product
  belongs_to :forum_category

  APP_CACHE_VERSION = "FD70"

  def logo_attributes=(icon_attr)
    handle_icon 'logo', icon_attr
  end

  def fav_icon_attributes=(icon_attr)
    handle_icon 'fav_icon', icon_attr
  end

  def fav_icon_url
    fav_icon.nil? ? '/images/favicon.ico' : fav_icon.content.url
  end

  def forum_categories
    main_portal ? account.forum_categories : (forum_category ? [forum_category] : [])
  end

  def portal_forums
    main_portal ? account.forums :
      forum_category ? forum_category.forums : []
  end

  def has_solution_category? category_id
    return true unless portal_solution_categories.find_by_solution_category_id(category_id).nil?
  end

  def recent_popular_topics( user, days_before = (DateTime.now - 30.days) )
    main_portal ? account.portal_topics.visible(user).published.popular(days_before).limit(10) :
        forum_category ? forum_category.portal_topics.visible(user).published.popular(days_before).limit(10) : []
  end

  def recent_articles
    main_portal ? account.published_articles.newest(10) :
      account.solution_articles.articles_for_portal(self).visible.newest(10)
  end

  def recent_portal_topics user
    main_portal ? account.portal_topics.published.visible(user).newest.limit(6) :
        (forum_category ? forum_category.portal_topics.published.visible(user).newest.limit(6) : [])
  end

  def my_topics(user, per_page, page)
    main_portal ? user.monitored_topics.published.filter(per_page, page) :
       forum_category ?  user.monitored_topics.published.find_by_forum_category_id(forum_category.id).filter(per_page, page) : []
  end

  def my_topics_count(user)
    main_portal ? user.monitored_topics.published.count :
       forum_category ?  user.monitored_topics.published.find_by_forum_category_id(forum_category.id).count : 0
  end

  #Yeah.. It is ugly.
  def ticket_fields(additional_scope = :all)
    filter_fields account.ticket_fields.send(additional_scope), ticket_field_conditions
  end

  def customer_editable_ticket_fields
    filter_fields account.ticket_fields.customer_editable, ticket_field_conditions
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

  private

    def update_users_language
      account.all_users.update_all(:language => account.language) unless account.features.multi_language?
    end

    def main_portal_language_changes?
      main_portal and @portal_changes.has_key?(:language)
    end

    def backup_portal_changes
      @portal_changes = self.changes.clone
      @portal_changes.symbolize_keys!
    end

    def handle_icon(icon_field, icon_attr)
      unless send(icon_field)
        icon = send("build_#{icon_field}")
        icon.description = icon_field
        icon.content = icon_attr[:content]
        icon.account_id = account_id
      else
        send(icon_field).update_attributes(icon_attr)
      end
    end

    def downcase_portal_url
      self.portal_url = portal_url.downcase if portal_url
    end

    def validate_preferences
      preferences.each do |key, value|
        if ["header_color", "tab_color", "bg_color"].include?(key)
          errors.add_to_base("Please enter a valid hex color value.") unless value =~ HEX_COLOR_REGEX
        elsif key == 'contact_info'
          preferences[key] = RailsFullSanitizer.sanitize(value)
        end
      end
    end

    def ticket_field_conditions
      { 'product' => (main_portal && !account.products.empty?) }
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
        if product && portal_url_changed?
          site_id = account.chat_setting.display_id
          chat_widget = product.chat_widget
          if chat_widget && chat_widget.widget_id
            Resque.enqueue(Workers::Livechat, 
              {
                :worker_method => "update_widget", 
                :widget_id => chat_widget.widget_id, 
                :siteId => site_id, 
                :attributes => { :site_url => portal_url}
              }
            )
          end
        end
      end
    end

    def update_portal_forum_categories
      if forum_category_id_changed?
        portal_forum_categories.first.delete if !portal_forum_categories.empty?
        portal_forum_categories.build(:forum_category_id => forum_category_id) if forum_category_id?
      end
    end
end
