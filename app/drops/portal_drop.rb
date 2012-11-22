class PortalDrop < BaseDrop
  
  include ActionController::UrlWriter
  
  liquid_attributes << :name << :language

  def initialize(source)
    super source
  end
  
  def login_path
    @login_path ||= source.portal_login_path
  end
  
  def logout_path
    @logout_path ||= source.portal_logout_path
  end
  
  def signup_path
    @signup_path ||= source.signup_path
  end
  
  def new_ticket_path
    @new_ticket_path ||= source.new_ticket_path
  end

  def new_topic_path
    @new_topic_path ||= source.new_topic_path
  end

  def forums_home_path
    support_discussions_path
  end

  def solutions_home_path
    @solutions_home_path ||= support_solutions_path
  end

  def can_signup_feature? 
    Account.current.features? :signup_link
  end
  
  def tabs
    @tabs ||= load_tabs
  end
  
  def solution_categories
    @solution_categories ||= liquify(*@source.solution_categories.reject(&:is_default?))
  end
  
  def forum_categories
    @forum_categories ||= liquify(*@source.forum_categories)
  end

  def logo
    @portal_logo ||= !source.logo.blank? ? source.logo.content.url(:logo) : "/images/logo.png"
  end

  def forums
    @forums ||= source.portal_forums
  end

  def user
    @current_user ||= User.current
  end

  def google_login
    link_to(image_tag("google.png", :alt => t(".sign_in_using_google")) + "label", "/auth/open_id?openid_url=https://www.google.com/accounts/o8/id", :class => "btn") if Account.current.features? :google_signin
  end

  def contact_info
    @contact_info ||= source.preferences[:contact_info]
  end

  def ticket_export_url
    @ticket_export_url ||= configure_export_support_tickets_path
  end

  private
    def load_tabs
      tabs = [  [ root_path,                :home,		    true ],
					      [ support_solutions_path,   :solutions,	  true ],
				        [ support_discussions_path, :forums, 	    true ],
				        [ support_tickets_path,     :tickets,     User.current ]]
				      	  # company_tickets_tab ]

			tabs.map do |s| 
				next unless s[2]
	      	#tab( s[3] || t("header.tabs.#{s[1].to_s}") , {:controller => s[0], :action => :index}, active && :active ) 
	      	TabDrop.new( :name => s[1].to_s, :url => s[0], :label => (s[3] || I18n.t("header.tabs.#{s[1].to_s}")), :tab_type => s[1].to_s )
		    end
    end
    
    def company_tickets_tab
      [ support_company_tickets_path, :company_tickets, User.current && 
        User.current.customer && User.current.client_manager?, User.current && 
          User.current.customer && User.current.customer.name ]
    end
  
end