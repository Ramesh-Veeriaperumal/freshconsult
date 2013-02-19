class PortalDrop < BaseDrop
  
  include ActionController::UrlWriter
  
  liquid_attributes << :name << :language

  def initialize(source)
    super source
  end  
  
  def tabs
    @tabs ||= load_tabs
  end
  
  # Solutions related attributes for portal
  def solution_categories
    @solution_categories ||= @source.solution_categories.reject(&:is_default?)
  end

  def has_solutions
    (allowed_in_portal?(:open_solutions) && folders.present?)
  end

  def folders
    @folders ||= (portal_account.folders.visible(portal_user).reject(&:blank?) || []).flatten
  end

  # !MODEL-ENHANCEMENT Need to make published articles for a 
  # folder to be tracked inside the folder itself... similar to fourms
  def articles_count
    @articles_count ||= portal_account.published_articles.count
  end

  # Discussions related attributes for portal
  def forum_categories
    @forum_categories ||= @source.forum_categories
  end

  def has_forums
    (allowed_in_portal?(:open_forums) && forums.present?)
  end

  def forums
    @forums ||= (forum_categories.map{ |c| c.forums.visible(portal_user) }.reject(&:blank?) || []).flatten
  end

  def recent_popular_topics
    @recent_popular_topics ||= source.recent_popular_topics(DateTime.now - 30.days)
  end

  def topics_count
    @topics_count ||= forums.map{ |f| f.topics_count }.sum
  end

  # Portal branding related information
  def logo_url
    @logo_url ||= source.logo.present? ? source.logo.content.url(:logo) : "/images/logo.png"
  end

  def linkback_url
    @linkback_url ||= source.preferences[:logo_link] || support_home_path
  end

  def contact_info
    @contact_info ||= source.preferences.fetch(:contact_info, "")
  end

  # Portal links
  def login_path
    @login_path ||= source.portal_login_path
  end
  
  def logout_path
    @logout_path ||= source.portal_logout_path
  end

  def can_signup_feature?
    allowed_in_portal? :signup_link
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

  def profile_path
    @profile_path ||= source.profile_path
  end

  def forums_home_path
    @forums_home_path ||= support_discussions_path
  end

  def solutions_home_path
    @solutions_home_path ||= support_solutions_path
  end

  def ticket_export_url
    @ticket_export_url ||= configure_export_support_tickets_path
  end

  def tickets_path
    @tickets_path ||= support_tickets_path
  end
  
  def current_user
    @current_user ||= portal_user
  end

  def has_alternate_login
    (feature?(:twitter_signin) || feature?(:google_signin) || feature?(:facebook_signin))
  end
  
  private
    def load_tabs
      tabs = [  [ support_home_path,        :home,		    true ],
					      [ support_solutions_path,   :solutions,	  allowed_in_portal?(:open_solutions) ],
				        [ support_discussions_path, :forums, 	    allowed_in_portal?(:open_forums) ],
				        [ support_tickets_path,     :tickets,     portal_user ]]

			tabs.map { |s|
  	    TabDrop.new( :name => s[1].to_s, :url => s[0], 
          :label => (s[3] || I18n.t("header.tabs.#{s[1].to_s}")), :tab_type => s[1].to_s ) if s[2]
      }.reject(&:blank?)
    end    
    
end