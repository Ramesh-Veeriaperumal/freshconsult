class Support::SearchController < SupportController
  
  extend NewRelic::Agent::MethodTracer
  
  include SearchUtil

  include ActionView::Helpers::TextHelper

  before_filter :forums_allowed_in_portal?, :only => :topics
  before_filter :solutions_allowed_in_portal?, :only => :solutions

  def show
    search_portal(content_classes)
    @current_filter = :all  
    render_search
  end
  
  def solutions
    search_portal([Solution::Article])
    @current_filter = :solutions
    render_search
  end
  
  def topics
    search_portal([Topic])
    @current_filter = :topics
    render_search
  end

  def tickets
    search_portal([Helpdesk::Ticket])
    @current_filter = :tickets
    render_search
  end

  def widget_solutions
    @widget_solutions = true
    solutions
  end

  private

    def forums_allowed_in_portal?
      render :nothing => true and return unless (feature?(:forums) && allowed_in_portal?(:open_forums))
    end
  
    def solutions_allowed_in_portal? #Kinda duplicate
      render :nothing => true and return unless allowed_in_portal?(:open_solutions)
    end

    def search_drop
      { :term => params[:term], 
        :search_results => @search_results,
        :current_filter => @current_filter,
        :pagination => @pagination }
    end

    def content_classes
      to_ret = Array.new
      
      to_ret << Solution::Article if(allowed_in_portal?(:open_solutions))
      to_ret << Topic if(feature?(:forums) && allowed_in_portal?(:open_forums))
      to_ret << Helpdesk::Ticket if(current_user)

      to_ret
    end
   
    def search_portal(f_classes)
      @items, @def_search_val = [], SearchUtil::DEFAULT_SEARCH_VALUE
      begin
        if main_portal?
          @items = ThinkingSphinx.search(filter_key(params[:term]),
                                    :with => with_options, 
                                    :without => without_options,
                                    :include => [ :folder, :forum ],
                                    :classes => f_classes,
                                    :max_matches => params[:max_matches],
                                    :match_mode => :any,
                                    :sphinx_select => sphinx_select,
                                    :page => params[:page], :per_page => 20)
        else
          f_classes.each do |f_class|            
            s_options = with_options

            if(f_class == Solution::Article)
              s_options[:category_id] = current_portal.solution_category_id
            elsif(f_class == Topic)
              s_options[:category_id] = current_portal.forum_category_id
            end

            class_search = f_class.search(filter_key(params[:term]), 
                                    :with => s_options, 
                                    :without => without_options,                                
                                    :match_mode => :any,
                                    :max_matches => params[:max_matches],
                                    :sphinx_select => sphinx_select,
                                    :page => params[:page], :per_page => 10)
            
            @items.concat(class_search)

            @longest_collection = class_search if 
              (!@longest_collection || (class_search.total_pages > @longest_collection.total_pages))

          end
        end

      rescue Exception => e
        @search_results = []
        NewRelic::Agent.notice_error(e)
      end

      process_results
        
    end

    def filter_key(query = "")
      email_regex  = Regexp.new('(\b[-a-zA-Z0-9.\'’_%+]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}\b)', nil, 'u')
      default_regex = Regexp.new('\w+', nil, 'u')
      enu = query.gsub(/("#{email_regex}(.*?#{email_regex})?"|(?![!-])#{email_regex})/u)
      unless enu.count > 0
        enu = query.gsub(/("#{default_regex}(.*?#{default_regex})?"|(?![!-])#{default_regex})/u)
      end
      enu.each do
        pre, proper, post = $`, $&, $'
        is_operator = pre.match(%r{(\W|^)[@~/]\Z}) || pre.match(%r{(\W|^)@\([^\)]*$})
        is_quote    = proper.starts_with?('"') && proper.ends_with?('"')
        has_star    = pre.ends_with?("*") || post.starts_with?("*")
        if is_operator || is_quote || has_star
            proper
        else
           "*#{proper}*"
        end
      end
    end

    def with_options
      opts = {  :account_id => current_account.id, 
                # HACK Using forums visiblity for both solutions and forums 
                :visibility => visibility_opts(Forum::VISIBILITY_KEYS_BY_TOKEN),
                :deleted => false }
      
      if @current_user 
        if @current_user.client_manager?
          opts[:customer_id] = [@def_search_val, current_user.customer_id]
        else
          # Buggy hack... The first users tickets in the first account will also be searched 
          opts[:requester_id] = [@def_search_val, current_user.id]
        end
        opts[:company] = @def_search_val if current_user && current_user.has_company?
      end

      opts
    end

    def without_options
      { :status => @def_search_val }
    end

    def sphinx_select
      visiblity_class = Forum::VISIBILITY_KEYS_BY_TOKEN      
      %{*, IF( IN(customer_ids, #{current_user.customer_id}) \
                 OR IN(visibility, #{ visiblity_class[:anyone] }, #{ visiblity_class[:logged_users] }), \
                 #{ @def_search_val },0) AS company } if 
          current_user && current_user.has_company?
    end

    def visibility_opts visiblity_class
        visiblity = [ @def_search_val ]
        if current_user
          visiblity.push( visiblity_class[:logged_users] )          
          visiblity.push( visiblity_class[:company_users] ) if current_user.has_company?
        end
        visiblity
    end

    def process_results
      @search_results = []
      @items.each do |item|
        result = item_based_selection(item)
        result.merge!('source' => item) if !request.xhr?
        @search_results << result
      end
      @search_results
    end

    def item_based_selection item
      case item.class.name
        when 'Solution::Article'
          solution_result(item)
        when 'Topic'
          topic_result(item)
        when 'Helpdesk::Ticket'
          ticket_result(item)
      end
    end

    def solution_result article
      { 'title' => article.excerpts.title, 
        'group' => article.folder.name, 
        'desc' => article.excerpts.desc_un_html,
        'type' => "ARTICLE",
        'url' => support_solutions_article_path(article) }
    end

    def topic_result topic
      { 'title' => topic.excerpts.title, 
        'group' => topic.forum.name, 
        'desc' => truncate(topic.posts.first.body, 120),
        'type' => "TOPIC", 
        'url' => support_discussions_topic_path(topic) }
    end

    def ticket_result ticket
      { 'title' => ticket.subject, 
        'group' => "Ticket", 
        'desc' => truncate(ticket.description, 120),
        'type' => "TICKET", 
        'url' => support_ticket_path(ticket) }
    end

    def render_search
      respond_to do |format|
        format.html{ 
          # Hack having a temp pagination file to handle the pagination for search
          @pagination = render_to_string :partial => 'pagination', 
              :object => main_portal? ? @items : @longest_collection

          @search = SearchDrop.new search_drop
          set_portal_page :search
          render :show
        }
        format.json { render :json => @search_results.to_json }
      end
    end

end
