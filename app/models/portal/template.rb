class Portal::Template < ActiveRecord::Base    
	
	set_table_name "portal_templates"
	
  belongs_to :account
  belongs_to :portal
  
  has_many :pages, :class_name => 'Portal::Page', :dependent => :destroy
  
  before_create { |template| template.account ||= Account.current }

  TEMPLATE_MAPPING = [ 
    [:header,         "portal/header.portal"],    
    [:footer,         "portal/footer.portal"],
    [:layout,         "portal/layout.portal"],
    [:contact_info,   "portal/contact_info.portal"]
  ]

  TEMPLATE_MAPPING_FILE_BY_TOKEN = Hash[*TEMPLATE_MAPPING.map { |i| [i[0], i[1]] }.flatten]
  
  def page_types
    default_pages = Portal::Page::PAGE_TYPE_OPTIONS.map{ |a| { :page_type => a[1], :page_name => a[0] } }
  end

end
