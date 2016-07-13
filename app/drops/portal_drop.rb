class PortalDrop < BaseDrop
  
  include Rails.application.routes.url_helpers
  
  self.liquid_attributes += [:name, :language]
  
  def initialize(source)
    super source
  end

  def context=(current_context)
    @current_tab = current_context['current_tab']
    @current_page = current_context['current_page_token']
    @facebook_portal = current_context['facebook_portal']
    @context = current_context
    
    super
  end

  # Portal branding related information
  def logo_url
    @logo_url ||=  MemcacheKeys.fetch(["v7", "portal", "logo_href", source],30.days.to_i) do
            source.logo.nil? ? 
              "/assets/misc/logo.png" :
              AwsWrapper::S3Object.url_for(source.logo.content.path(:logo), 
                            source.logo.content.bucket_name,
                            :secure => true, 
                            :expires => 30.days.to_i)
                
    end
  end

  def linkback_url
    @linkback_url ||= (source.preferences[:logo_link].presence || support_home_path)
  end

  def contact_info
    @contact_info ||= source.preferences[:contact_info].presence
  end

  # Portal links
  def login_url
    @login_url ||= support_login_path(url_options)
  end

  def topic_reply_url
    @topic_reply_url ||= begin
      if @context['topic'].present?
        reply_support_discussions_topic_path(@context['topic'].id)
      else
        login_url
      end
    end
  end
  
  def can_signup_feature
    allowed_in_portal? :signup_link
  end

  def can_submit_ticket_without_login
    allowed_in_portal? :anonymous_tickets
  end

  def home_url
    @home_url ||= support_home_path
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
  
  def helpdesk_url
    @helpdesk_url ||= root_path
  end

  def my_topics_url
    @my_topics_url ||= my_topics_support_discussions_topics_path
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

  def archive_ticket_export_url
    @archive_ticket_export_url ||= configure_export_support_archive_tickets_path
  end

  def current_tab
    @current_tab ||= @current_tab
  end

  def facebook_portal
    @facebook_portal ||= @facebook_portal
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
    @has_forums ||= (feature?(:forums) && allowed_in_portal?(:open_forums) && !feature?(:hide_portal_forums) && forums.present?)
  end

  def forum_categories
    @forum_categories ||= @source.forum_categories
  end

  def forums
    @forums ||= (forum_categories.map{ |c| c.forums.visible(portal_user) }.reject(&:blank?) || []).flatten
  end

  def recent_portal_topics
    @recent_portal_topics ||= @source.recent_portal_topics(portal_user).presence
  end

  def recent_popular_topics
    @recent_popular_topics ||= @source.recent_popular_topics(portal_user, 30.days.ago).presence
  end

  def my_topics
    @my_topics ||= source.my_topics(portal_user, @per_page, @page) if portal_user
  end

  def my_topics_count
    @my_topics_count ||= source.my_topics_count(portal_user) if portal_user
  end

  def topics_count
    @topics_count ||= forums.map{ |f| f.topics_count }.sum
  end

  # Access to Solution articles
  def has_solutions
    @has_solutions ||= (allowed_in_portal?(:open_solutions) && folders.present?)
  end

  def solution_categories
    @solution_categories ||= @source.solution_category_meta.reject(&:is_default?)
  end

  def folders
    @folders ||= (solution_categories.map { |c|
                    c.solution_folder_meta.visible(portal_user) }.reject(&:blank?) || []).flatten
  end

  def recent_articles
    @recent_articles ||= source.account.solution_article_meta.for_portal(source).published.newest(10)
  end

  # !MODEL-ENHANCEMENT Need to make published articles for a 
  # folder to be tracked inside the folder itself... similar to fourms
  def articles_count
    @articles_count ||= folders.map{ |f| f.solution_article_meta.published.count }.sum
  end
  
  def url_options
    @url_options ||= { :host => source.host }    
  end

  def paid_account
    @paid_account ||= portal_account.subscription.paid_account?
  end
  
  def settings
    @settings ||= source.template.preferences
  end

  def language_list
    source.language_list
  end
  
  def recent_topics
    Forum::RecentTopicsDrop.new(self.source)
  end
  
  def languages
    source.account.all_portal_language_objects
  end
  
  def current_language
    Language.current
  end
  
  def personalized_articles?
    source.preferences[:personalized_articles]
  end

  private
    def load_tabs
      tabs = [  [ support_home_path,        :home,		    true ],
					      [ support_solutions_path,   :solutions,	  has_solutions ],
				        [ support_discussions_path, :forums, 	    has_forums ],
				        [ support_tickets_path,     :tickets,     portal_user ]]

			@load_tabs ||= tabs.map { |s|
  	    HashDrop.new( :name => s[1].to_s, :url => s[0], 
          :label => (s[3] || I18n.t("header.tabs.#{s[1].to_s}")), :tab_type => s[1].to_s ) if s[2]
      }.reject(&:blank?)
    end
    
end