class Portal::Template < ActiveRecord::Base    
	
	set_table_name "portal_templates"
	
  belongs_to_account
  belongs_to :portal
  before_create :set_default_values
  
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

  def set_default_values
    self.preferences = HashWithIndifferentAccess.new({
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
end
