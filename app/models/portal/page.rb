class Portal::Page < ActiveRecord::Base
	self.table_name =  "portal_pages"
  self.primary_key = :id
	
	include MemcacheKeys

	belongs_to_account
	belongs_to :template	
	
	validates_uniqueness_of :page_type, :scope => [:template_id]	

	after_commit :clear_cache
  
	#!PORTALCSS Need to move these constances to lib

	# Editable pages of the portal
	# Page id keys are added [2] as part of the array obj. itself 
	# so that it can be uniq even if the obj gets reorganized at a later period
	PAGE_TYPES = [
		# General pages
		[:portal_home,        	1,  "support/home/index.portal", "support_home_path"],    
		[:user_signup,        	2,  "support/signups/new.portal", "support_signup_path"],
		[:user_login,         	3,  "support/login/new.portal", "support_login_path"],
		[:profile_edit,       	4,  "support/profiles/edit.html.erb", "edit_support_profile_path"],
		[:search,    		  	5,  "support/search/show.portal", "support_search_path"],

		# Solution pages
		[:solution_home,      	6,   "support/solutions/index.portal", "support_solutions_path"],
		[:solution_category,    18,  "support/solutions/show.portal", "support_solutions_path"],
		[:article_list,       	7,   "support/solutions/folders/show.portal", 
			"support_solutions_folder_path", "public_folders"],
		[:article_view,       	8,   "support/solutions/articles/show.portal", 
			"support_solutions_article_path", "published_articles"],

		# Discussion or Forum pages
		[:discussions_home,   	9,   "support/discussions/index.portal", "support_discussions_path"],
		[:discussions_category,  20,  "support/discussions/show.portal", "support_discussions_path"],
		[:topic_list,         	10,  "support/discussions/forums/show.portal", 
			"support_discussions_forum_path", "portal_forums"],
		[:topic_view,         	11,  "support/discussions/topics/show.portal", 
			"support_discussions_topic_path", "portal_topics"],
		[:new_topic,          	12,  "support/discussions/topics/new.portal", 
			"new_support_discussions_topic_path"],
		[:my_topics, 			19, "support/discussions/topics/my_topics.portal",
			"my_topics_support_discussions_topics_path"],
		
		# Ticket pages
		[:submit_ticket,      	13,  "support/tickets/new.portal", "new_support_ticket_path"],
		[:ticket_list,        	14,  "support/tickets/index.portal", "support_tickets_path"],
		[:ticket_view,        	15,  "support/tickets/show.portal", 
			"support_ticket_path", "tickets"],

		# Password reset with perishable token
		[:password_reset,       16,  "password_resets/edit.portal"],
		[:activation_form,      17,  "activations/new.portal"],
		[:csat_survey,      		21,  "support/custom_surveys/new.portal"],


		[:facebook_home,      101,  "support/facebook/index.portal", "support_home_path"],

		[:archive_ticket_list,        	102,  "support/archive_tickets/index.portal", "support_archive_tickets_path"],
		[:archive_ticket_view,        	103,  "support/archive_tickets/show.portal", 
			"support_archive_ticket_path", "archive_tickets"],
		
	]

	# Manually organizing them as groups to avoid direct db save dependency
	PAGE_GROUPS = [
		{ :general 		=> [:portal_home, :user_signup, :user_login, :search] },
		{ :solutions 	=> [:solution_home, :article_list, :article_view, :solution_category] }, 
		{ :discussions 	=> [:discussions_home, :discussions_category, :topic_list, :my_topics, :topic_view, :new_topic] },
		{ :tickets 		=> [:submit_ticket, :ticket_list, :ticket_view] }
	]

	# Restricted pages from editing
	# Hiding customization for profile_edit, ticket_list, ticket_view and password_reset
	RESTRICTED_PAGES = [:profile_edit, :password_reset, :activation_form, :facebook_home]
	
	# Helper constants for access of PAGE_TYPES
	PAGE_TYPE_OPTIONS      	= PAGE_TYPES.collect { |i| [i[0], i[1]] }	
	# PAGE_TYPE_NAME_BY_KEY 	= Hash[*PAGE_TYPES.map { |i| [i[2], i[1]] }.flatten]
	PAGE_TYPE_TOKEN_BY_KEY	= Hash[*PAGE_TYPES.map { |i| [i[1], i[0]] }.flatten]
	PAGE_TYPE_KEY_BY_TOKEN 	= Hash[*PAGE_TYPES.map { |i| [i[0], i[1]] }.flatten]
	# PAGE_TYPE_NAME_BY_TOKEN = Hash[*PAGE_TYPES.map { |i| [i[1], i[2]] }.flatten]
	PAGE_FILE_BY_TOKEN 		= Hash[*PAGE_TYPES.map { |i| [i[0], i[2]] }.flatten]

	PAGE_REDIRECT_ACTION_BY_TOKEN 		= Hash[*PAGE_TYPES.map { |i| [i[0], i[3]] }.flatten]
	PAGE_MODEL_ACTION_BY_TOKEN 		= Hash[*PAGE_TYPES.map { |i| [i[0], i[4]] }.flatten]
	ARCHIVE_TICKETS = [:archive_ticket_list, :archive_ticket_view]
  
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
	  @page_drop ||= PageDrop.new self
	end

	private
	  def clear_cache
	    key = PORTAL_TEMPLATE_PAGE % { :account_id => self.account_id, 
	    	:template_id => self.template_id, :page_type => self.page_type }
	    MemcacheKeys.delete_from_cache key
	  end

end
