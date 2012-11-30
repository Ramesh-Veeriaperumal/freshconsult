class Portal::Page < ActiveRecord::Base
	set_table_name "portal_pages"

	belongs_to :template                  
	belongs_to :account                    
	
	validates_uniqueness_of :content, :scope => [:template_id, :page_type]

	before_create { |page| page.account ||= Account.current }
  
	#!PORTALCSS Need to move these constances to lib

	# Editable pages of the portal
	# Page id keys are added [2] as part of the array obj. itself 
	# so that it can be uniq even if the obj gets reorganized at a later period
	PAGE_TYPES = [
		# General pages
		[:portal_home,        	1,  "home/index.portal"],    
		[:user_signup,        	2,  "support/signup/show.portal"],
		[:user_login,         	3,  "support/new.portal"],
		[:profile_edit,       	4,  "support/profiles/edit.portal"],
		[:search,    		  	5,  "support/search/index"],

		# Solution pages
		[:solution_home,      	6,   "support/solutions/index.portal"],
		[:article_list,       	7,   "support/solutions/folders/show.portal"],
		[:article_view,       	8,   "support/solutions/articles/show.portal"],

		# Discussion or Forum pages
		[:discussions_home,   	9,  "support/discussions/index.portal"],
		[:topic_list,         	10,  "support/discussions/forums/show.portal"],
		[:topic_view,         	11,  "support/discussions/topics/show.portal"],
		[:new_topic,          	12,  "support/discussions/topics/new.portal"],
		
		# Ticket pages
		[:submit_ticket,      	13,  "support/tickets/new.portal"],
		[:ticket_list,        	14,  "support/tickets/index.portal"],
		[:ticket_view,        	15,  "support/tickets/show.portal"]
	]

	# Manually organizing them as groups to avoid direct db save dependency
	PAGE_GROUPS = [
		{ :general 		=> [:portal_home, :user_signup, :user_login, :profile_edit, :search] },
		{ :solutions 	=> [:solution_home, :article_list, :article_view] }, 
		{ :discussions 	=> [:discussions_home, :topic_list, :topic_view, :new_topic] },
		{ :tickets 		=> [:submit_ticket, :ticket_list, :ticket_view] }
	]

	# Helper constants for access of PAGE_TYPES
	PAGE_TYPE_OPTIONS      	= PAGE_TYPES.collect { |i| [i[0], i[1]] }	
	# PAGE_TYPE_NAME_BY_KEY 	= Hash[*PAGE_TYPES.map { |i| [i[2], i[1]] }.flatten]
	PAGE_TYPE_TOKEN_BY_KEY	= Hash[*PAGE_TYPES.map { |i| [i[1], i[0]] }.flatten]
	PAGE_TYPE_KEY_BY_TOKEN 	= Hash[*PAGE_TYPES.map { |i| [i[0], i[1]] }.flatten]
	# PAGE_TYPE_NAME_BY_TOKEN = Hash[*PAGE_TYPES.map { |i| [i[1], i[2]] }.flatten]
	PAGE_FILE_BY_TOKEN 		= Hash[*PAGE_TYPES.map { |i| [i[0], i[2]] }.flatten]
  
	def name
		I18n.t("portal_pages.pages.#{self.token}")
	end

	def token
		PAGE_TYPE_TOKEN_BY_KEY[self.page_type]
	end
	
	def default_page
		PAGE_FILE_BY_TOKEN[self.token]
	end

	def to_param
    	page_type
  	end 

	def to_liquid
	    PageDrop.new self
	end

end
