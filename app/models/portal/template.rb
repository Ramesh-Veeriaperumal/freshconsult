class Portal::Template < ActiveRecord::Base    
	
	set_table_name "portal_templates"
	
  belongs_to :account
  belongs_to :portal
  
  has_many :pages, :dependent => :destroy
  
  before_create { |template| template.account ||= Account.current }
end
