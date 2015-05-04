# encoding: utf-8
class Support::SearchController < SupportController
  
  extend NewRelic::Agent::MethodTracer
  
  include SearchUtil

  include ActionView::Helpers::TextHelper

  before_filter :forums_allowed_in_portal?, :only => :topics
  before_filter :solutions_allowed_in_portal?, :only => :solutions
  before_filter :require_user_login, :only => :tickets

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
    klasses = [Helpdesk::Ticket]
    klasses << Helpdesk::Note
    search_portal(klasses)
    @current_filter = :tickets
    render_search
  end

  def suggest_topic
    @results = search_portal([Topic])
    render :layout => false
  end

  def related_articles
    article = current_account.solution_articles.find(params[:article_id])
    @related_articles = article.related(current_portal, params[:limit])
    @container = params[:container]
    render :layout => false
  end

  # def widget_solutions
  #   @widget_solutions = true
  #   solutions
  # end

  private

    def forums_allowed_in_portal?
      render :nothing => true and return unless forums_enabled?
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
      to_ret << Topic if forums_enabled?
      to_ret << Helpdesk::Ticket if(current_user)
      to_ret << Helpdesk::Note if(current_user)
      to_ret
    end
   
    def search_portal(f_classes)
      @items, @search_results, @def_search_val = [], [], SearchUtil::DEFAULT_SEARCH_VALUE
      es_search_portal(f_classes) unless f_classes.blank?
    end

    def es_search_portal(search_in)
      begin
        Search::EsIndexDefinition.es_cluster(current_account.id)
        options = { :load => true, :page => (params[:page] || 1), :size => (params[:max_matches] || 20), :preference => :_primary_first }
        @es_items = Tire.search Search::EsIndexDefinition.searchable_aliases(search_in, current_account.id), options do |search|
          search.query do |query|
            query.filtered do |f|
              if SearchUtil.es_exact_match?(params[:term])
                f.query { |q| q.match :_all, SearchUtil.es_filter_exact(params[:term]), :type => :phrase }
              else
                f.query { |q| q.match :_all, SearchUtil.es_filter_key(params[:term], false), :analyzer => "include_stop" }
              end
              f.filter :term, { :account_id => current_account.id }
              f.filter :or, { :not => { :exists => { :field => :status } } },
                            { :not => { :term => { :status => SearchUtil::DEFAULT_SEARCH_VALUE } } }

              f.filter :or, { :not => { :exists => { :field => 'folder.visibility' } } },
                            { :terms => { 'folder.visibility' => visibility_opts(Solution::Constants::VISIBILITY_KEYS_BY_TOKEN) } }
              f.filter :or, { :not => { :exists => { :field => 'forum.forum_visibility' } } },
                            { :terms => { 'forum.forum_visibility' => visibility_opts(Forum::VISIBILITY_KEYS_BY_TOKEN) } }

              if current_user
                f.filter :or, { :not => { :exists => { :field => :deleted } } },
                              { :term => { :deleted => false } }
                f.filter :or, { :not => { :exists => { :field => :spam } } },
                              { :term => { :spam => false } }
                f.filter :or, { :not => { :exists => { :field => 'private' } } },
                              { :term => { 'private' => false } }
                f.filter :or, { :not => { :exists => { :field => :notable_deleted } } },
                              { :term => { :notable_deleted => false } }
                f.filter :or, { :not => { :exists => { :field => :notable_spam } } },
                              { :term => { :notable_spam => false } }
                f.filter :or, { :not => { :exists => { :field => :notable_requester_id } } },
                              { :term => { :notable_requester_id => current_user.id } }
                if current_user.has_company?
                  f.filter :or, { :not => { :exists => { :field => 'forum.customer_forums.customer_id' } } },
                                { :term => { 'forum.customer_forums.customer_id' => current_user.company_id } }
                  f.filter :or, { :not => { :exists => { :field => 'folder.customer_folders.customer_id' } } },
                                { :term => { 'folder.customer_folders.customer_id' => current_user.company_id } }
                end
                if privilege?(:client_manager)
                  f.filter :or, { :not => { :exists => { :field => :company_id } } },
                                { :term => { :company_id => current_user.company_id } }
                else
                  f.filter :or, { :not => { :exists => { :field => :requester_id } } },
                                { :term => { :requester_id => current_user.id } }
                end
              end
              unless main_portal?
                if search_in.include?(Solution::Article)
                  f.filter :or, { :not => { :exists => { :field => 'folder.category_id' } } },
                                { :terms => { 'folder.category_id' => current_portal.portal_solution_categories.map(&:solution_category_id) } }
                end
                if search_in.include?(Topic)
                    f.filter :or, { :not => { :exists => { :field => 'forum.forum_category_id' } } },
                                { :terms => { 'forum.forum_category_id' => current_portal.portal_forum_categories.map(&:forum_category_id) } }
                end
              end
            end
          end
          search.from options[:size].to_i * (options[:page].to_i-1)
          search.highlight :desc_un_html, :title, :description, :subject, :options => { :tag => '<span class="match">', :fragment_size => 200, :number_of_fragments => 4, :encoder => 'html' }
        end

        @items = @es_items.results
        @longest_collection = @es_items.results unless main_portal?
        params[:term].gsub!(/\\/,'')
        process_results

      rescue Exception => e
        @search_results = []
        @items = []
        NewRelic::Agent.notice_error(e)
      end
    end

    def filter_key(query = "")
      email_regex  = Regexp.new('(\b[-a-zA-Z0-9.\'’_%+]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,15}\b)', nil, 'u')
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
        if privilege?(:client_manager)
          opts[:customer_id] = [@def_search_val, current_user.company_id]
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
      pre_process_results
      @items.each do |item|
        next if item.nil?
        result = item_based_selection(item)
        result.merge!('source' => item) if !request.xhr?
        @search_results << result
      end
      @search_results
    end

    def pre_process_results
      @items.each_with_hit do |result,hit|
        SearchUtil.highlight_results(result, hit) unless hit['highlight'].blank?
      end
    end

    def item_based_selection item
      case item.class.name
        when 'Solution::Article'
          solution_result(item)
        when 'Topic'
          topic_result(item)
        when 'Helpdesk::Ticket'
          ticket_result(item)
        when 'Helpdesk::Note'
          note_result(item)
      end
    end

    def solution_result article
      { 'title' => article.es_highlight('title').html_safe, 
        'group' => h(article.folder.name), 
        'desc' => article.es_highlight('desc_un_html').html_safe,
        'type' => "ARTICLE",
        'url' => support_solutions_article_path(article) }
    end

    def topic_result topic
      { 'title' => topic.es_highlight('title').html_safe, 
        'group' => h(topic.forum.name), 
        'desc' => truncate(h(topic.posts.first.body), :length => truncate_length),
        'type' => "TOPIC", 
        'url' => support_discussions_topic_path(topic) }
    end

    def ticket_result ticket
      { 'title' => ticket.es_highlight('subject').html_safe, 
        'group' => "Ticket", 
        'desc' => truncate(ticket.es_highlight('description').html_safe, :length => truncate_length),
        'type' => "TICKET", 
        'url' => support_ticket_path(ticket) }
    end

    def note_result note
      { 'title' => h(note.notable.subject), 
        'group' => "Note", 
        'desc' => truncate(h(note.body), :length => truncate_length),
        'type' => "NOTE", 
        'url' => support_ticket_path(note.notable) }
    end

    def truncate_length
      request.xhr? ? 160 : 220
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
        format.json{ 
          if (params.has_key?(:need_count) && params[:need_count].to_s == "true")
            render :json => {:count => @items.total_entries,:item => @search_results}.to_json, :callback => params[:callback]
          else
            render :json => @search_results.to_json, :callback => params[:callback]
          end
        }
      end
    end

    def require_user_login
      return redirect_to(send(Helpdesk::ACCESS_DENIED_ROUTE)) unless current_user
    end

end
