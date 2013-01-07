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

  def profile_path
    @profile_path ||= source.profile_path
  end

  def forums_home_path
    support_discussions_path
  end

  def solutions_home_path
    @solutions_home_path ||= support_solutions_path
  end

  def can_signup_feature?
    allowed_in_portal? :signup_link
  end
  
  def tabs
    @tabs ||= load_tabs
  end
  
  def total_solution_categories
    @total_solution_categories ||= @source.solution_categories.reject(&:is_default?).size
  end

  def solution_categories
    @solution_categories ||= @source.solution_categories.reject(&:is_default?)
  end

  def total_articles
    @total_articles ||= articles_count_for_portal
  end

  def total_forum_categories
    @total_forum_categories ||= @source.forum_categories.size
  end
  
  def forum_categories
    @forum_categories ||= @source.forum_categories
  end

  # def forums
  #   @forums ||= @source.portal_forums.visible(User.current)
  # end

  def total_topics
    @total_topics ||= source.portal_forums.visible(User.current).map{ |t| t.topics_count }.sum
  end

  def logo_url
    @logo_url ||= source.logo.content.url(:logo) if source.logo.present?
  end

  def linkback_url
    @linkback_url ||= source.preferences[:logo_link] || support_home_path
  end

  def contact_info
    @contact_info ||= source.preferences.fetch(:contact_info, "")
  end

  def current_user
    @current_user ||= User.current
  end

  def ticket_export_url
    @ticket_export_url ||= configure_export_support_tickets_path
  end

  def tickets_path
    @tickets_path ||= support_tickets_path
  end

  def popular_topics
    @popular_topics ||= popular_topics_from_portal
  end
  
  private
    def load_tabs
      tabs = [  [ support_home_path,        :home,		    true ],
					      [ support_solutions_path,   :solutions,	  User.current || allowed_in_portal?(:open_solutions) ],
				        [ support_discussions_path, :forums, 	    User.current || allowed_in_portal?(:open_forums) ],
				        [ support_tickets_path,     :tickets,     User.current ]]

			tabs.map do |s| 
				next unless s[2] 
	      	TabDrop.new( :name => s[1].to_s, :url => s[0], :label => (s[3] || I18n.t("header.tabs.#{s[1].to_s}")), :tab_type => s[1].to_s )
		    end
    end    

    def popular_topics_from_portal
      source.main_portal? ? source.account.portal_topics.popular.filter(@per_page, @page) :
        source.forum_category ? source.forum_category.portal_topics.popular.filter(@per_page, @page) : []
    end

    def topics_count_for_portal
      if source.main_portal?
        source.account.portal_forums.visible(User.current).map{ |t| t.topics_count }.sum
      elsif source.forum_category.present?
        source.forum_category.forums.visible(User.current).map{ |t| t.topics_count }.sum
      else
        0
      end
    end

    def articles_count_for_portal
      if source.main_portal? 
        source.account.published_articles.size
      elsif source.solution_category
        source.solution_category.published_articles.size
      else
        0
      end
    end
end