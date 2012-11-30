class Portal::Template < ActiveRecord::Base    
	include RedisKeys
	set_table_name "portal_templates"
	
  belongs_to_account
  belongs_to :portal
  # before_create :set_default_values
  before_update :create_pages
  after_update :remove_portal_preview_keys
  
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
  
  def page_types
    default_pages = Portal::Page::PAGE_TYPE_OPTIONS.map{ |a| { :page_type => a[1], :page_name => a[0] } }
  end

  def default_values
    HashWithIndifferentAccess.new({
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
    }).merge(self.get_portal_pref)
  end

  # Merge with default params for specific portal
  def get_portal_pref
    pref = self.portal.preferences || Account.current.main_portal.preferences
    Hash[*pref.select {|k,v| LIMIT_PREFERENCES.include?(k)}.flatten]
  end

  def reset_to_default
    self.pages.destroy
    self.preferences = default_values
    self.header = nil
    self.footer = nil
    self.custom_css = nil
    self.layout = nil
    self.send(:update_without_callbacks)
  end

  private

    def page_redis_key(page_label)
      PORTAL_PREVIEW % {:account_id => self.account_id, 
                        :label=> page_label, 
                        :template_id=> self.id, 
                        :user_id => User.current.id }
    end

    def page_redis_content(page_label)
      get_key(page_redis_key(page_label))
    end

    def create_pages
      Portal::Page::PAGE_TYPE_OPTIONS.map do |page|
        page_label = page[0]
        page_type = page[1]  
        portal_page = self.pages.find_by_page_type(page_type) || 
                      self.pages.new( :page_type => page_type )
        portal_page[:content] = page_redis_content(page_label)
        portal_page.save() unless portal_page[:content].nil?
      end
    end

    def remove_portal_preview_keys
      portal_preview_keys = array_of_keys(PORTAL_PREVIEW_PREFIX % {:account_id => self.account_id, 
           :user_id => User.current.id})
       portal_preview_keys.each { |key| remove_key(key) } 
    end

end
