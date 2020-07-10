class PortalDrop < BaseDrop

  include Rails.application.routes.url_helpers

  self.liquid_attributes += [:name, :language]

  MOST_VIEWED_ARTICLES_COUNT = 10
  MAX_ARTICLES_LIMIT = 30
  ARTICLE_CACHE_EXPIRY = 1.day
  USER_LOGIN_PAGE = 'user_login'.freeze

  include Redis::RedisKeys
  include Redis::PortalRedis

  CACHE_METHODS = [:solution_categories, :folders, :articles_count]

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
    @logo_url ||=  MemcacheKeys.fetch(["v8", "portal", "logo_href", source],7.days.to_i) do
            source.logo.nil? ?
              "/assets/misc/logo.png" :
              AwsWrapper::S3.public_url(source.logo.content.bucket_name, source.logo.content.path(:logo)) # PRE-RAILS: only two arguments for v2, removed secure

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
    feature? :signup_link
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


  def is_not_login_page
     (current_page && current_page != USER_LOGIN_PAGE)
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

  def bot_name
    source.bot.name
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

  # !MODEL-ENHANCEMENT Need to make published articles for a
  # folder to be tracked inside the folder itself... similar to fourms
  def articles_count
    @articles_count ||= folders.map{ |f| f.solution_article_meta.published.count }.sum
  end

  def solution_categories_from_cache
    @solution_categories ||= source.solution_categories_from_cache
  end

  def folders_from_cache
    @folders ||= (solution_categories.map { |c| c.visible_folders }.reject(&:blank?) || []).flatten
  end

  def articles_count_from_cache
    @articles_count ||= folders.map{ |f| f.visible_articles_count }.sum
  end

	def most_viewed_articles
		return [] unless Account.current.launched?(:most_viewed_articles)
		@most_viewed_articles ||= begin
			fetched_articles = MemcacheKeys.fetch(view_key, ARTICLE_CACHE_EXPIRY) {
				all_articles_ids = Account.current.solution_articles.most_viewed(MAX_ARTICLES_LIMIT).pluck(:parent_id)
				Account.current.solution_article_meta
					.where(:id => all_articles_ids)
					.preload(:solution_folder_meta, { :solution_category_meta  => [:portal_solution_categories, :portals]}).to_a
			}
			# List of objects from the cache is an array(not collection). So we use ActiveRecord::Associations::Preloader.
			ActiveRecord::Associations::Preloader.new(fetched_articles, :current_article).run
			art_list = []
			sort_articles(fetched_articles).each do |article_meta|
				art_list << article_meta if article_meta.visible?(portal_user) && article_meta.visible_in?(source)
				break if art_list.count == MOST_VIEWED_ARTICLES_COUNT
			end
			art_list
		end
	end

	def sort_articles fetched_articles
		@sort_articles ||= fetched_articles
												.select{ |a| a.current_article.present? && a.current_article.published? }
												.sort{|x,y| y.current_article.hits <=> x.current_article.hits }
	end

  def recent_articles
    @recent_articles ||= source.account.solution_article_meta.for_portal(source).published.newest(10)
  end

  def url_options
    @url_options ||= { :host => source.host }
  end

  def url_options_with_protocol
    @url_options_with_protocol ||= url_options.merge(protocol: source.url_protocol)
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
    source.personalized_articles?
  end

  include Solution::PortalCacheMethods

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

		def view_key
			MemcacheKeys::MOST_VIEWED_ARTICLES % { :account_id => source.account_id, :language_id => Language.current.id, :cache_version => cache_version }
		end

		def cache_version
			key = PORTAL_CACHE_VERSION % { :account_id => source.account_id }
			get_portal_redis_key(key) || "0"
		end

end
