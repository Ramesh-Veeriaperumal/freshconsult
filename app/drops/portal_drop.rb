class PortalDrop < BaseDrop
  
  include ActionController::UrlWriter
  
  liquid_attributes << :name << :language

  def initialize(source)
    super source
  end

  def context=(current_context)
    @current_tab = current_context['current_tab']
    @current_page = current_context['current_page_token']
    @context = current_context
    
    super
  end

  # Portal branding related information
  def logo_url
    @logo_url ||= MemcacheKeys.fetch(["v2","portal","logo_href",source]) do
      source.logo.present? ? 
        AWS::S3::S3Object.url_for(source.logo.content.path(:logo), source.logo.content.bucket_name,:use_ssl => true) : 
        "/images/logo.png"
    end
  end

  def linkback_url
    @linkback_url ||= source.preferences.fetch(:logo_link, support_home_path)
  end

  def contact_info
    @contact_info ||= source.preferences[:contact_info].presence
  end

  # Portal links
  def login_url
    @login_url ||= support_login_path(url_options)
  end
  
  def can_signup_feature
    allowed_in_portal? :signup_link
  end

  def can_submit_ticket_without_login
    allowed_in_portal? :anonymous_tickets
  end
  
  def signup_url
    @signup_url ||= support_signup_path(url_options)
  end

  def logout_url
    @logout_url ||= logout_path(url_options)
  end
  
  def new_ticket_url
    @new_ticket_url ||= new_support_ticket_path(url_options)
  end

  def new_topic_url    
    _opts = url_options.merge({ :forum_id => @context['forum'].id }) if @context['forum'].present?
    @new_topic_url ||= new_support_discussions_topic_path( _opts )
  end

  def profile_url
    @profile_url ||= edit_support_profile_path(url_options)
  end

  def user
    @user ||= portal_user
  end

  def has_user_signed_in
    @has_user_signed_in ||= user ? true : false
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

  def current_page
    @current_page ||= @current_page
  end

  def tabs
    @tabs ||= load_tabs
    (@tabs.size > 1) ? @tabs : [] 
  end

  # Access to Discussions
  def has_forums
    (feature?(:forums) && allowed_in_portal?(:open_forums) && forums.present?)
  end

  def forum_categories
    @forum_categories ||= @source.forum_categories
  end

  def forums
    @forums ||= (forum_categories.map{ |c| c.forums.visible(portal_user) }.reject(&:blank?) || []).flatten
  end

  def recent_popular_topics
    @recent_popular_topics ||= source.recent_popular_topics(portal_user, 30.days.ago)
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
    @folders ||= (solution_categories.map { |c| c.folders.visible(portal_user) }.reject(&:blank?) || []).flatten
  end

  # !MODEL-ENHANCEMENT Need to make published articles for a 
  # folder to be tracked inside the folder itself... similar to fourms
  def articles_count
    @articles_count ||= folders.map{ |f| f.published_articles.count }.sum
  end

  def url_options
    { :host => source.host }    
  end

  def paid_account
    @paid_account ||= portal_account.subscription.paid_account?
  end
  
  private
    def load_tabs
      tabs = [  [ support_home_path,        :home,		    true ],
					      [ support_solutions_path,   :solutions,	  has_solutions ],
				        [ support_discussions_path, :forums, 	    has_forums ],
				        [ support_tickets_path,     :tickets,     portal_user ]]

			tabs.map { |s|
  	    HashDrop.new( :name => s[1].to_s, :url => s[0], 
          :label => (s[3] || I18n.t("header.tabs.#{s[1].to_s}")), :tab_type => s[1].to_s ) if s[2]
      }.reject(&:blank?)
    end
    
end