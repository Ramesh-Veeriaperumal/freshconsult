class Portal::Page < ActiveRecord::Base
	set_table_name "portal_pages"

	belongs_to :portal

	PAGE_TYPES = [
    [ :home,      "Home page",              1 ],
    [ :solution,  "Solutions home page",    2 ],
    [ :forums,    "Forums home page",       3 ],    
  ]

  PAGE_TYPE_OPTIONS      = PAGE_TYPES.map { |i| [i[1], i[2]] }
  PAGE_TYPE_NAMES_BY_KEY = Hash[*PAGE_TYPES.map { |i| [i[2], i[1]] }.flatten]
  PAGE_TYPE_BY_TOKEN     = Hash[*PAGE_TYPES.map { |i| [i[0], i[2]] }.flatten]
  PAGE_TYPE_BY_NAME      = Hash[*PAGE_TYPES.map { |i| [i[1], i[2]] }.flatten]  
  
	def page_name
	  PAGE_TYPE_NAMES_BY_KEY[self.page_type]
	end
	
	
end
