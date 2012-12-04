class Portal::Template < ActiveRecord::Base    

	set_table_name "portal_templates"

	include MemcacheKeys
  belongs_to_account
  belongs_to :portal
  
  has_many :pages, :class_name => 'Portal::Page', :dependent => :destroy

  serialize :preferences, Hash

  TEMPLATE_MAPPING = [ 
    [:header,  "portal/header.portal"],    
    [:footer,  "portal/footer.portal"],
    [:layout,  "portal/layout.portal"]
  ]

  TEMPLATE_MAPPING_FILE_BY_TOKEN = Hash[*TEMPLATE_MAPPING.map { |i| [i[0], i[1]] }.flatten]
  
  # Selectable preferences from main portal
  # This is limited so that not all carry forward into the template
  LIMIT_PREFERENCES = %w(bg_color tab_color header_color) 
  
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
      :baseFontFamily => "Helvetica Neue", 
      :textColor => "#333333",
      :headingsFontFamily => "Open Sans Condensed", 
      :headingsColor => "#333333",
      :linkColor => "#049cdb", 
      :linkColorHover => "#036690",
      :inputFocusRingColor => "#f4af1a"
    }.merge(self.get_portal_pref)
  end

  # Merge with default params for specific portal
  def get_portal_pref
    pref = self.portal.preferences || Account.current.main_portal.preferences
    Hash[*pref.select {|k,v| LIMIT_PREFERENCES.include?(k)}.flatten]
  end

  def reset_to_default
    self.pages.each(&:delete)
    self.preferences = default_preferences
    self.header = nil
    self.footer = nil
    self.custom_css = nil
    self.layout = nil
    self.save
  end

  def draft!
    MemcacheKeys.cache(draft_key,self)
  end

  def get_draft
    MemcacheKeys.get_from_cache(draft_key)
  end

  def soft_reset!(keys)
    cached_template = MemcacheKeys.get_from_cache(draft_key)
    db_template = portal.template
    keys.each { |key| cached_template[key.to_sym] = db_template[key.to_sym] }
    cached_template.draft!
    clear_cache! if cached_template.changes.blank?
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
    MemcacheKeys.get_from_cache(key)
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
    MemcacheKeys.delete_from_cache draft_key
  end

  def cache_page(page_label, page)
    key = draft_key(page_label)
    MemcacheKeys.cache(key, page)
  end

  def clear_page_cache!(page_label)
    MemcacheKeys.delete_from_cache draft_key(page_label)
  end

  private
    def draft_key(label = "cosmetic")
      PORTAL_PREVIEW % {:account_id => self.account_id, 
                        :template_id=> self.id, 
                        :label => label,
                        :user_id => User.current.id }
    end
end
