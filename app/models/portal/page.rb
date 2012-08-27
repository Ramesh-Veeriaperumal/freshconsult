class Portal::Page < ActiveRecord::Base
	set_table_name "portal_pages"

	belongs_to :template                  
	belongs_to :account                    
	
	validates_uniqueness_of :content, :scope => [:template_id, :page_type]

	before_create { |page| page.account ||= Account.current }
  
	#!PORTALCSS Need to move this somewhere by venom
	PAGE_TYPES = [
		[:portal_home,        "Portal home",                  1,   "home/index.portal"],    
		[:discussions_home,   "Discussions home",             2,   "support/discussions/index.portal"],
		[:topic_list,         "Topic list",                   3,   "support/discussions/forums/show.portal"],
		[:topic_view,         "Topic view",                   4,   "support/discussions/topics/show.portal"],
		[:new_topic,          "New topic",                    5,   "support/discussions/topics/new.portal"],
		[:solution_home,      "Solutions home",               6,   "support/solutions/index.portal"],
		[:article_list,       "Article list",                 7,   "support/solutions/folders/show.portal"],
		[:article_view,       "Article view",                 8,   "support/solutions/articles/show.portal"],
		[:submit_ticket,      "New ticket",                   9,   "support/tickets/new.portal"],
		[:tickets_list,       "User or company tickets",      10,  "support/tickets/index.portal"],
		[:ticket_view,        "Ticket details",               11,  "support/tickets/show.portal"],
		[:user_signup,        "New user signup",              12,  "support/registrations/new.portal"],
		[:user_login,         "User login",                   13,  "support/new.portal"],
		[:profile_edit,       "User profile",                 14,  "support/profiles/edit.portal"],
		[:forgot_password,    "Forgot password",              15,  "support/registrations/forgot_password.portal"]
	]

	PAGE_TYPE_OPTIONS      	= PAGE_TYPES.collect { |i| [i[1], i[2]] }
	
	PAGE_TYPE_NAME_BY_KEY 	= Hash[*PAGE_TYPES.map { |i| [i[2], i[1]] }.flatten]
	PAGE_TYPE_TOKEN_BY_KEY	= Hash[*PAGE_TYPES.map { |i| [i[2], i[0]] }.flatten]
	PAGE_TYPE_KEY_BY_TOKEN 	= Hash[*PAGE_TYPES.map { |i| [i[0], i[2]] }.flatten]
	PAGE_TYPE_NAME_BY_TOKEN = Hash[*PAGE_TYPES.map { |i| [i[1], i[2]] }.flatten]
	PAGE_BY_TOKEN 			= Hash[*PAGE_TYPES.map { |i| [i[0], i[3]] }.flatten]
  
	def name
		PAGE_TYPE_NAME_BY_KEY[self.page_type]
	end

	def token
		PAGE_TYPE_TOKEN_BY_KEY[self.page_type]
	end
	
	def default_page
		PAGE_BY_TOKEN[self.token]
	end

end
