class Portal < ActiveRecord::Base
  include ActionController::UrlWriter

  serialize :preferences, Hash
  
  validates_uniqueness_of :portal_url, :allow_blank => true, :allow_nil => true
  validates_format_of :portal_url, :with => %r"^(?!.*\.#{Helpdesk::HOST[Rails.env.to_sym]}$)[/\w\.-]+$", 
  :allow_nil => true, :allow_blank => true

  delegate :friendly_email, :to => :product, :allow_nil => true
  before_save :downcase_portal_url
  
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

  belongs_to :account
  belongs_to :product
  
  #Again, the below two are not in literal 'ER belongs_to', just a one-to-one mapping.
  belongs_to :solution_category, :class_name => 'Solution::Category',
              :foreign_key => 'solution_category_id'
  belongs_to :forum_category

  APP_CACHE_VERSION = "FD41"
  
  def logo_attributes=(icon_attr)
    handle_icon 'logo', icon_attr
  end
  
  def fav_icon_attributes=(icon_attr)
    handle_icon 'fav_icon', icon_attr
  end

  def fav_icon_url
    fav_icon.nil? ? '/images/favicon.ico' : fav_icon.content.url
  end
    
  def solution_categories
    main_portal ? account.portal_solution_categories : (solution_category ? [solution_category] : [])
  end
  
  def forum_categories
    main_portal ? account.forum_categories : (forum_category ? [forum_category] : [])
  end
  
  def portal_forums
    main_portal ? account.forums : 
      forum_category ? forum_category.forums : []
  end

  def recent_popular_topics( user, days_before = (DateTime.now - 30.days) )
    main_portal ? account.portal_topics.visible(user).popular(days_before).limit(10) :
        forum_category ? forum_category.portal_topics.visible(user).popular(days_before).limit(10) : []
  end

  def recent_articles
    main_portal ? account.published_articles.newest(10) : 
        (solution_category ? solution_category.published_articles.newest(10) : [])
  end

  def recent_portal_topics user
    main_portal ? account.portal_topics.visible(user).newest.limit(6) : 
        (forum_category ? forum_category.portal_topics.visible(user).newest.limit(6) : [])
  end

  def my_topics(user, per_page, page)
    main_portal ? user.monitored_topics.filter(per_page, page) :
       forum_category ?  user.monitored_topics.find_by_forum_category_id(forum_category.id).filter(per_page, page) : []
  end

  def my_topics_count(user)
    main_portal ? user.monitored_topics.count :
       forum_category ?  user.monitored_topics.find_by_forum_category_id(forum_category.id).count : 0
  end

  #Yeah.. It is ugly.
  def ticket_fields(additional_scope = :all)
    filter_fields account.ticket_fields.send(additional_scope)
  end
  
  def customer_editable_ticket_fields
    filter_fields account.ticket_fields.customer_editable
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

  private
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
    
    def filter_fields(f_list)
      to_ret = []
      checks = { 'product' => (main_portal && !account.products.empty?) }

      f_list.each { |field| to_ret.push(field) if checks.fetch(field.name, true) }
      to_ret
    end

    

    def cache_version
      key = PORTAL_CACHE_VERSION % { :account_id => self.account_id }
      get_portal_redis_key(key) || "0"
    end
end
