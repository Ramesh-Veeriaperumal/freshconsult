class Portal::Page < ActiveRecord::Base
	 
	set_table_name "portal_pages"
  
	belongs_to :template
end
