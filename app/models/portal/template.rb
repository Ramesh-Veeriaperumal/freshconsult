class Portal::Template < ActiveRecord::Base    
	
	set_table_name "portal_templates"
	
  belongs_to :account
  belongs_to :portal
  
  has_many :pages, :class_name => 'Portal::Page', :dependent => :destroy
  
  before_create { |template| template.account ||= Account.current }
  
  def page_types
    default_pages = Portal::Page::PAGE_TYPE_OPTIONS.map{ |a| { :page_type => a[1], :page_name => a[0] } }
  end
  
end
