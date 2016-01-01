# encoding: utf-8
class Support::SearchV2::SpotlightController < SupportController

  include ActionView::Helpers::TextHelper

  before_filter :initialize_search_parameters

  attr_accessor :size, :page, :current_filter, :es_results, :result_set, 
                :search_results, :search, :pagination, :results, :no_render,
                :related_articles, :container, :search_context

  # ESType - [model, associations] mapping
  # Needed for loading records from DB
  #
  @@esv2_spotlight_models = {
    'ticket'        => { model: 'Helpdesk::Ticket',         associations: [ :ticket_old_body ] },
    'archiveticket' => { model: 'Helpdesk::ArchiveTicket',  associations: [] },
    'topic'         => { model: 'Topic',                    associations: [] },
    'article'       => { model: 'Solution::Article',        associations: [ :folder, :article_body ] }
  }

  # Unscoped customer-side spotlight search
  #
  def all
    @searchable_klasses = esv2_klasses
    @current_filter     = :all
    @search_context     = :portal_spotlight_global
    search
  end

  # Tickets scoped customer-side spotlight search
  #
  def tickets
    require_user_login unless current_user

    @searchable_klasses = ['Helpdesk::Ticket', 'Helpdesk::ArchiveTicket']
    @current_filter     = :tickets
    @search_context     = :portal_spotlight_ticket
    search
  end

  # Forums scoped customer-side spotlight search
  #
  def topics
    require_user_login unless forums_enabled?

    @searchable_klasses = ['Topic']
    @current_filter     = :topics
    @search_context     = :portal_spotlight_topic
    search
  end

  # Solutions scoped customer-side spotlight search
  #
  def solutions
    require_user_login unless allowed_in_portal?(:open_solutions)

    @searchable_klasses = ['Solution::Article']
    @current_filter     = :solutions
    @search_context     = :portal_spotlight_solution
    search
  end

  def suggest_topic
    @no_render          = true
    @searchable_klasses = ['Topic']
    @search_context     = :portal_spotlight_topic
    search
    @results            = @search_results

    render template: '/support/search/suggest_topic', :layout => false
  end

  private

    # Need to add provision to pass params & context
    #
    def search
      begin
        @es_results = Search::V2::SearchRequestHandler.new(current_account.id,
                                                            @search_context,
                                                            searchable_types
                                                          ).fetch(construct_es_params)
        @result_set = Search::Utils.load_records(
                                                  @es_results, 
                                                  @@esv2_spotlight_models.dclone, 
                                                  {
                                                    current_account_id: current_account.id,
                                                    page: @page,
                                                    from: @offset
                                                  }
                                                )

        process_results
      rescue Exception => e
        @search_results = []
        @result_set = []

        Rails.logger.error "Exception encountered - #{e.message}"
        NewRelic::Agent.notice_error(e)
      end

      handle_rendering unless @no_render
    end

    # Types to be passed to service code to scan
    #
    def searchable_types
      @searchable_klasses.collect {
        |klass| klass.demodulize.downcase
      }
    end

    # Constructing params for ES
    #
    def construct_es_params
      Hash.new.tap do |es_params|
        if Search::Utils.exact_match?(@search_key)
          es_params[:search_term] = Search::Utils.extract_term(@search_key)
          es_params[:exact_match] = true
        else
          es_params[:search_term] = @search_key
        end

        if current_user
          if privilege?(:client_manager)
            es_params[:ticket_company_id]     = current_user.company_id
          else
            es_params[:ticket_requester_id]   = current_user.id
          end
        end

        if @searchable_klasses.include?('Solution::Article')
          es_params[:language_id]               = Language.for_current_account.id
          es_params[:article_status]            = SearchUtil::DEFAULT_SEARCH_VALUE.to_i
          es_params[:article_visibility]        = visibility_opts(Solution::Constants::VISIBILITY_KEYS_BY_TOKEN)
          es_params[:article_category_id]       = current_portal.portal_solution_categories.map(&:solution_category_id)
          es_params[:article_company_id]        = current_user.company_id if current_user
        end

        if @searchable_klasses.include?('Topic')
          es_params[:topic_visibility]          = visibility_opts(Forum::VISIBILITY_KEYS_BY_TOKEN)
          es_params[:topic_category_id]         = current_portal.portal_forum_categories.map(&:forum_category_id)
          es_params[:topic_company_id]          = current_user.company_id if current_user
        end

        es_params[:size] = @size
        es_params[:from] = @offset
      end.merge(ES_V2_BOOST_VALUES[@search_context])
    end

    # Check tweaking user_visibility in article.rb
    # Reusing from SearchUtil module
    #
    def visibility_opts visiblity_class
      Array.new.tap do |visiblity|
        visiblity.push(visiblity_class[:anyone])
        if current_user
          visiblity.push(visiblity_class[:logged_users])
          visiblity.push(visiblity_class[:company_users]) if current_user.has_company?
        end
      end
    end

    def esv2_klasses
      Array.new.tap do |model_names|
        model_names.concat(['Helpdesk::Ticket', 'Helpdesk::ArchiveTicket']) if current_user
        model_names.push('Topic')                                           if forums_enabled?
        model_names.push('Solution::Article')                               if allowed_in_portal?(:open_solutions)
      end
    end

    def handle_rendering
      respond_to do |format|
        format.html{
          # Hack having a temp pagination file to handle the pagination for search
          @pagination = render_to_string :partial => '/support/search/pagination',
              :object => @result_set

          @search = SearchDrop.new search_drop
          set_portal_page :search
          render 'support/search/show'
        }
        format.json{
          #_Note_:'need_count' is used by feedback widget
          #
          if (params[:need_count].to_bool.present? rescue false)
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
        when 'Helpdesk::ArchiveTicket'
          archive_ticket_result(item)
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

    # To-do: Need to verify group and type
    #
    def archive_ticket_result ticket
      { 'title' => ticket.es_highlight('subject').html_safe,
        'group' => 'Archived Ticket',
        'desc' => truncate(ticket.es_highlight('description').html_safe, :length => truncate_length),
        'type' => 'ARCHIVED TICKET',
        'url' => support_archive_ticket_path(ticket.display_id) }
    end

    def truncate_length
      request.xhr? ? 160 : 220
    end

    def require_user_login
      redirect_to send(Helpdesk::ACCESS_DENIED_ROUTE)
    end

    ######################
    ### Before filters ###
    ######################

    def initialize_search_parameters
      @search_key     = params[:term] || params[:search_key] || ''
      @es_results     = []
      @size           = (params[:max_matches].to_i.zero? or
                        params[:max_matches].to_i < Search::Utils::MAX_PER_PAGE) ? Search::Utils::MAX_PER_PAGE : params[:max_matches]
      @page           = (params[:page].to_i.zero? ? Search::Utils::DEFAULT_PAGE : params[:page].to_i)
      @offset         = @size * (@page - 1)
    end

end
