class PortalDrop < BaseDrop
  
  include ActionController::UrlWriter
  
  liquid_attributes << :name << :language

  def initialize(source)
    super source
  end

  def context=(current_context)
    @current_tab = current_context['current_tab']

    super
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
  def login_url
    @login_url ||= source.portal_login_path
  end
  
  def can_signup_feature
    allowed_in_portal? :signup_link
  end
  
  def signup_url
    @signup_url ||= source.signup_path
  end

  def logout_url
    @logout_url ||= source.portal_logout_path
  end
  
  def new_ticket_url
    @new_ticket_url ||= source.new_ticket_path
  end

  def new_topic_url
    @new_topic_url ||= source.new_topic_path
  end

  def profile_url
    @profile_url ||= source.profile_path
  end

  def user
    @user ||= portal_user
  end

  def has_alternate_login
    (feature?(:twitter_signin) || feature?(:google_signin) || feature?(:facebook_signin))
  end

  def discussions_home_url
    @forums_home_path ||= support_discussions_path
  end

  def solutions_home_url
    @solutions_home_url ||= support_solutions_path
  end

  def tickets_home_url
    @tickets_home_url ||= support_tickets_path
  end

  def ticket_export_url
    @ticket_export_url ||= configure_export_support_tickets_path
  end

  def current_tab
    @current_tab ||= @current_tab
  end

  def tabs
    @tabs ||= load_tabs
  end

  # Access to Discussions
  def has_forums
    (allowed_in_portal?(:open_forums) && forums.present?)
  end

  def forum_categories
    @forum_categories ||= @source.forum_categories
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

  # Access to Solution articles
  def has_solutions
    (allowed_in_portal?(:open_solutions) && folders.present?)
  end

  def solution_categories
    @solution_categories ||= @source.solution_categories.reject(&:is_default?)
  end
  
  def folders
    @folders ||= (portal_account.folders.visible(portal_user).reject(&:blank?) || []).flatten
  end

  # !MODEL-ENHANCEMENT Need to make published articles for a 
  # folder to be tracked inside the folder itself... similar to fourms
  def articles_count
    @articles_count ||= portal_account.published_articles.count
  end
  
  private
    def load_tabs
      tabs = [  [ support_home_path,        :home,		    true ],
					      [ support_solutions_path,   :solutions,	  allowed_in_portal?(:open_solutions) ],
				        [ support_discussions_path, :forums, 	    allowed_in_portal?(:open_forums) ],
				        [ support_tickets_path,     :tickets,     portal_user ]]

			tabs.map { |s|
  	    HashDrop.new( :name => s[1].to_s, :url => s[0], 
          :label => (s[3] || I18n.t("header.tabs.#{s[1].to_s}")), :tab_type => s[1].to_s ) if s[2]
      }.reject(&:blank?)
    end    
    
end