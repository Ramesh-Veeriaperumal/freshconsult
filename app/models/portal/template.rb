class Portal::Template < ActiveRecord::Base    

	self.table_name =  "portal_templates"
  self.primary_key = :id

  include Redis::RedisKeys
  include Redis::PortalRedis
  include Cache::Memcache::Portal::Template

  belongs_to_account
  belongs_to :portal
  validate :validate_preferences
  
  has_many :pages, :class_name => 'Portal::Page', :dependent => :destroy

  serialize :preferences, Hash

  before_create :set_defaults
  after_commit :clear_memcache_cache

  TEMPLATE_MAPPING = [ 
    [:header,  "portal/header.portal"],    
    [:footer,  "portal/footer.portal"],
    [:layout,  "portal/layout.portal"],
    [:head,    "portal/head.portal"]
  ]

  TEMPLATE_MAPPING_RAILS3 = [ 
    [:header,  "portal/header", :portal],    
    [:footer,  "portal/footer", :portal],
    [:layout,  "portal/layout", :portal],
    [:head,    "portal/head", :portal]
  ]

  TEMPLATE_MAPPING_FILE_BY_TOKEN = Hash[*TEMPLATE_MAPPING.map { |i| [i[0], i[1]] }.flatten]
  TEMPLATE_OPTIONS = Portal::Template::TEMPLATE_MAPPING.map { |i| i[0] }

  # Set of prefrences data that will be used during template creation
  def default_preferences
    {
      :bg_color => "#ffffff", 
      :header_color => "#4c4b4b", 
      :help_center_color => "#f9f9f9", 
      :footer_color => "#777777",
      :tab_color => "#006063", 
      :tab_hover_color => "#4c4b4b",
      :btn_background => "#ffffff", 
      :btn_primary_background => "#6c6a6a",
      :baseFont => "Helvetica Neue", 
      :textColor => "#333333",
      :headingsFont => "Open Sans Condensed", 
      :headingsColor => "#333333",
      :linkColor => "#049cdb", 
      :linkColorHover => "#036690",
      :inputFocusRingColor => "#f4af1a",
      :nonResponsive => false
    }.merge(self.get_portal_pref)
  end

  # Merge with default params for specific portal
  def get_portal_pref
    pref = self.portal.preferences.presence || self.account.main_portal.preferences
    # Selecting only bg_color, tab_color, header_color from the portals preferences
    Hash[*[:bg_color, :tab_color, :header_color].map{ |a| [ a, pref[a] ] }.flatten]
  end
  
  def reset_to_default
    self.pages.each(&:destroy)
    self.preferences = default_preferences
    self.header = nil
    self.footer = nil
    self.custom_css = nil
    self.layout = nil
    self.head = nil
    self.save
    clear_cache!
    Portal::Page::PAGE_TYPE_OPTIONS.map do |page|
      page_label = page[0]
      clear_page_cache!(page_label)
    end
  end

  def draft!
    set_portal_redis_key(draft_key, Marshal.dump(self))
  end

  def get_draft
    cached_template = get_portal_redis_key(draft_key)
    Marshal.load(cached_template) if cached_template
  end

  def soft_reset!(keys)
    cached_template = get_draft
    if cached_template
      db_template = portal.template
      keys.each { |key| cached_template[key.to_sym] = db_template[key.to_sym] }
      cached_template.draft!
      clear_cache! if cached_template.changes.blank?
    end
  end

  def publish!
    self.save
    pages_from_cache.each(&:save)
    clear_cache!
    Portal::Page::PAGE_TYPE_OPTIONS.map do |page|
      page_label = page[0]
      clear_page_cache!(page_label)
    end
  end

  def page_from_cache(page_label)
    key = draft_key(page_label)
    cached_page = get_portal_redis_key(key)
    Marshal.load(cached_page) if cached_page
  end

  def pages_from_cache
    cached_pages = []
    Portal::Page::PAGE_TYPE_OPTIONS.map do |page|
      page_label = page[0]
      cached_pages << page_from_cache(page_label) unless page_from_cache(page_label).nil?
    end
    cached_pages
  end

  def clear_cache!
    remove_portal_redis_key(draft_key)
  end

  def cache_page(page_label, page)
    key = draft_key(page_label)
    set_portal_redis_key(key, Marshal.dump(page))
  end

  def clear_page_cache!(page_label)
    remove_portal_redis_key(draft_key(page_label))
  end

  def validate_preferences
    pref = default_preferences.keys - [:baseFont, :headingsFont, :nonResponsive]
    preferences.each do |key, value|
      preferences[key] = RailsFullSanitizer.sanitize(value) if value.is_a?(String)
      next if value.blank? || pref.exclude?(key.to_sym)
      errors.add(:base, "Please enter a valid hex color value.") and return false unless value =~ Portal::HEX_COLOR_REGEX
    end
  end

  private
    def draft_key(label = "cosmetic")
      PORTAL_PREVIEW % {:account_id => self.account_id, 
                        :template_id => self.id, 
                        :label => label,
                        :user_id => User.current.id }
    end

    def set_defaults
      self.preferences = default_preferences
      self.account = self.portal.account
    end
end
