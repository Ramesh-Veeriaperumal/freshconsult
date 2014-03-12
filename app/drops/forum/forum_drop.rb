class Forum::ForumDrop < BaseDrop
  
  include ActionController::UrlWriter
  
  liquid_attributes << :name << :description << :topics_count
  
  def initialize(source)
    super source
  end

  def context=(current_context)    

    # Setting the default current topic filter based on params or setting it to recent
    @current_topic_filter = (current_context.registers[:controller].params['filter_topics_by']||"recent").to_sym

    current_context['paginate_url'] = support_discussions_forum_path(source)

    super
  end
  
  def id
    source.id
  end

  def url
    support_discussions_forum_path(source)
  end
  
  # Type of the forum (Announcements, Feature requests, Problems, Questions)
  def type_name
    source.type_name.downcase
  end

  def current_topic_filter
    @current_topic_filter ||= :recent
  end

  def allowed_filters
    @allowed_filters ||= filter_list.map{ |f| { 
              :name => f, 
              :url  => support_discussions_filter_topics_path(source, :filter_topics_by => f.to_s)
            }}
  end
  
  # def visibility
  #   source.forum_visibility
  # end

  def filter_list
    [:recent, :popular].concat(Topic::ALL_TOKENS[source.forum_type])
  end

  def forum_category
    source.forum_category
  end
 
  def problems?
    source.problems?
  end

  def topics
    # By default topics will be recent topics based on lastest reply time and sticky topics on top 
    @topics ||= filter_topics
  end 

  def popular_topics
    @popular_topics ||= filter_topics(:popular)
  end

  # Topics will be filtered based on stamp_type type
  # !PORTALCSS TODO need to make this as dynamic so that methods can be fetched directly from Topic::IDEAS_STAMPS
  def planned_topics
    @planned_topics ||= filter_topics(:planned)
  end

  def implemented_topics
    @implemented_topics ||= filter_topics(:implemented)
  end

  def nottaken_topics
    @not_taken_topics ||= filter_topics(:nottaken)
  end

  def inprogress
    @inprogress ||= filter_topics(:inprogress)
  end

  def deferred
    @deferred ||= filter_topics(:deferred)
  end

  def answered
    @answered ||= filter_topics(:answered)
  end

  def unanswered
    @unanswered ||= filter_topics(:unanswered)
  end

  def solved
    @solved ||= filter_topics(:solved)
  end

  def unsolved
    @unsolved ||= filter_topics(:unsolved)
  end

  private
    def filter_topics filter = self.current_topic_filter
      case filter
        when :popular
          @source.topics.published.popular(3.months.ago).filter(@per_page, @page)

        when :planned, :implemented, :nottaken, :deferred, :inprogress,
            :answered, :unanswered, :solved, :unsolved
            
          _stamp = Topic::STAMPS_BY_KEY[filter.to_sym]
          @source.topics.published.newest.by_stamp(_stamp).filter(@per_page, @page)
          
        else
          @source.recent_topics.published.filter(@per_page, @page)
      end
    end

  
end