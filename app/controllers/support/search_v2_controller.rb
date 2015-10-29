# encoding: utf-8
class Support::SearchV2Controller < SupportController
  
  extend NewRelic::Agent::MethodTracer
  include ActionView::Helpers::TextHelper

  before_filter :initialize_search_parameters

  attr_accessor :current_filter, :es_results, :result_set, :search_results, :search, :pagination

  # To-do: Verify uses:
  # :results, :related_articles, :container, :longest_collection

  @@esv2_spotlight_models = {
    "ticket"  => { model: "Helpdesk::Ticket",   associations: [ :ticket_old_body ] }, 
    "note"    => { model: "Helpdesk::Note",     associations: [ :note_old_body ] }, 
    "topic"   => { model: "Topic",              associations: [] }, 
    "article" => { model: "Solution::Article",  associations: [ :folder, :article_body ] }
  }

  # Unscoped customer-side spotlight search
  #
  def all
    @@searchable_klasses = esv2_klasses
    @current_filter = :all  
    search
  end

  # Tickets scoped customer-side spotlight search
  #
  def tickets
    require_user_login unless current_user

    @@searchable_klasses = ['Helpdesk::Ticket', 'Helpdesk::Note']
    @current_filter = :tickets
    search
  end
  
  # Forums scoped customer-side spotlight search
  #
  def topics
    require_user_login unless forums_enabled?

    @@searchable_klasses = ['Topic']
    @current_filter = :topics
    search
  end
  
  # Solutions scoped customer-side spotlight search
  #
  def solutions
    require_user_login unless allowed_in_portal?(:open_solutions)

    @@searchable_klasses = ['Solution::Article']
    @current_filter = :solutions
    search
  end

  # To-do: Establish usecases
  #
  def suggest_topic
    # @results = search_portal([Topic])
    @@searchable_klasses = ['Topic']
    render :layout => false
  end

  # To-do: Establish usecases
  # To-do: Need to do it here rather than model
  #
  def related_articles
    # article = current_account.solution_articles.find(params[:article_id])
    # @related_articles = article.related(current_portal, params[:limit])
    # @container = params[:container]
    # render :layout => false
  end

  private

    # Need to add provision to pass params & context
    #
    def search
      @es_results = Search::V2::SearchRequestHandler.new(searchable_types, current_account.id).fetch(@search_key)
      @result_set = Search::Utils.load_records(@es_results, @@esv2_spotlight_models.dclone, current_account.id)

      # Trying out with pagination hack
      # To-do: Bring under common wrapper
      @result_set = Search::Filters::Docs::Results.new(@result_set, { 
                                                        page: 1, 
                                                        from: 0, 
                                                        total_entries: @es_results['hits']['total'] 
                                                      })

      process_results
      handle_rendering
    end

    # Types to be passed to service code to scan
    #
    def searchable_types
      @@searchable_klasses.collect {
        |klass| klass.demodulize.downcase
      }
    end

    # Overriding for Support portal models
    #
    def esv2_klasses
      Array.new.tap do |model_names|
        model_names.concat(['Helpdesk::Ticket', 'Helpdesk::Note'])  if current_user
        model_names.push('Topic')                                   if forums_enabled?
        model_names.push('Solution::Article')                       if allowed_in_portal?(:open_solutions)
      end
    end

    # Overriding to handle support rendering
    #
    def handle_rendering
      respond_to do |format|
        format.html{ 
          # Hack having a temp pagination file to handle the pagination for search
          @pagination = render_to_string :partial => '/support/search/pagination', 
              :object => main_portal? ? @result_set : @longest_collection # To-do: Verify with arvinth

          @search = SearchDrop.new search_drop
          set_portal_page :search
          render 'support/search/show'
        }
        format.json{ 
          if (params[:need_count].to_bool.present? rescue false) # need_count used by feedback widget
            render :json => {
                              :count => @result_set.total_entries,
                              :item => @search_results
                            }.to_json, :callback => params[:callback]
          else
            render :json => @search_results.to_json, :callback => params[:callback]
          end
        }
      end
    end

    def search_drop
      { :term => @search_key, 
        :search_results => @search_results,
        :current_filter => @current_filter,
        :pagination => @pagination }
    end

    # Overriding to handle support result construction
    #
    def process_results
      @search_results = []
      @result_set.each do |item|
        next if item.nil?
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
        when 'Helpdesk::Note'
          note_result(item)
      end
    end

    ##################################
    ### Model based JSON responses ###
    ##################################

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
        'desc' => h(truncate(topic.posts.first.body, :length => truncate_length)).html_safe,
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

    def require_user_login
      redirect_to send(Helpdesk::ACCESS_DENIED_ROUTE)
    end
   
    # def search_portal(f_classes)
    #   @result_set, @search_results, @def_search_val = [], [], SearchUtil::DEFAULT_SEARCH_VALUE
    #   es_search_portal(f_classes) unless f_classes.blank?
    # end

    # def es_search_portal(search_in)
    #   begin
    #     @search_lang = ({ :language => current_portal.language }) if current_portal and current_account.features_included?(:es_multilang_solutions)
    #     Search::EsIndexDefinition.es_cluster(current_account.id)
    #     options = { :load => true, :page => (params[:page] || 1), :size => (params[:max_matches] || 20), :preference => :_primary_first }
    #     @es_items = Tire.search Search::EsIndexDefinition.searchable_aliases(search_in, current_account.id, @search_lang), options do |search|
    #       search.query do |query|
    #         query.filtered do |f|
    #           if SearchUtil.es_exact_match?(params[:term])
    #             f.query { |q| q.match :_all, SearchUtil.es_filter_exact(params[:term]), :type => :phrase }
    #           else
    #             f.query { |q| q.match :_all, SearchUtil.es_filter_key(params[:term], false), :analyzer => SearchUtil.analyzer(@search_lang) }
    #           end
    #           f.filter :term, { :account_id => current_account.id }
    #           f.filter :or, { :not => { :exists => { :field => :status } } },
    #                         { :not => { :term => { :status => SearchUtil::DEFAULT_SEARCH_VALUE } } }

    #           f.filter :or, { :not => { :exists => { :field => 'folder.visibility' } } },
    #                         { :terms => { 'folder.visibility' => visibility_opts(Solution::Constants::VISIBILITY_KEYS_BY_TOKEN) } }
    #           f.filter :or, { :not => { :exists => { :field => 'forum.forum_visibility' } } },
    #                         { :terms => { 'forum.forum_visibility' => visibility_opts(Forum::VISIBILITY_KEYS_BY_TOKEN) } }

    #           if current_user
    #             f.filter :or, { :not => { :exists => { :field => :deleted } } },
    #                           { :term => { :deleted => false } }
    #             f.filter :or, { :not => { :exists => { :field => :spam } } },
    #                           { :term => { :spam => false } }
    #             f.filter :or, { :not => { :exists => { :field => 'private' } } },
    #                           { :term => { 'private' => false } }
    #             f.filter :or, { :not => { :exists => { :field => :notable_deleted } } },
    #                           { :term => { :notable_deleted => false } }
    #             f.filter :or, { :not => { :exists => { :field => :notable_spam } } },
    #                           { :term => { :notable_spam => false } }
    #             f.filter :or, { :not => { :exists => { :field => :notable_requester_id } } },
    #                           { :term => { :notable_requester_id => current_user.id } }
    #             if current_user.has_company?
    #               f.filter :or, { :not => { :exists => { :field => 'forum.customer_forums.customer_id' } } },
    #                             { :term => { 'forum.customer_forums.customer_id' => current_user.company_id } }
    #               f.filter :or, { :not => { :exists => { :field => 'folder.customer_folders.customer_id' } } },
    #                             { :term => { 'folder.customer_folders.customer_id' => current_user.company_id } }
    #             end
    #             if privilege?(:client_manager)
    #               f.filter :or, { :not => { :exists => { :field => :company_id } } },
    #                             { :term => { :company_id => current_user.company_id } }
    #             else
    #               f.filter :or, { :not => { :exists => { :field => :requester_id } } },
    #                             { :term => { :requester_id => current_user.id } }
    #             end
    #           end
    #           if search_in.include?(Solution::Article)
    #             f.filter :or, { :not => { :exists => { :field => 'folder.category_id' } } },
    #                           { :terms => { 'folder.category_id' => current_portal.portal_solution_categories.map(&:solution_category_id) } }
    #           end
    #           if search_in.include?(Topic)
    #               f.filter :or, { :not => { :exists => { :field => 'forum.forum_category_id' } } },
    #                           { :terms => { 'forum.forum_category_id' => current_portal.portal_forum_categories.map(&:forum_category_id) } }
    #           end
    #         end
    #       end
    #       search.from options[:size].to_i * (options[:page].to_i-1)
    #       search.highlight :desc_un_html, :title, :description, :subject, :options => { :tag => '<span class="match">', :fragment_size => 200, :number_of_fragments => 4, :encoder => 'html' }
    #     end

    #     @result_set = @es_items.results
    #     @longest_collection = @es_items.results unless main_portal?
    #     params[:term].gsub!(/\\/,'')
    #     process_results

    #   rescue Exception => e
    #     @search_results = []
    #     @result_set = []
    #     NewRelic::Agent.notice_error(e)
    #   end
    # end

    # def visibility_opts visiblity_class
    #     visiblity = [ @def_search_val ]
    #     if current_user
    #       visiblity.push( visiblity_class[:logged_users] )          
    #       visiblity.push( visiblity_class[:company_users] ) if current_user.has_company?
    #     end
    #     visiblity
    # end

    def initialize_search_parameters
      @search_key   = params[:term] || params[:search_key] || ''
      @es_results   = []
    end

end
