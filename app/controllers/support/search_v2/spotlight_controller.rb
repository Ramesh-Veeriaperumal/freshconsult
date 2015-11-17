# encoding: utf-8
class Support::SearchV2::SpotlightController < SupportController

  BOOST_VALUES = YAML::load_file(File.join(Rails.root, 'config/search',
                                                  'boost_values.yml'))

  extend NewRelic::Agent::MethodTracer
  include ActionView::Helpers::TextHelper

  before_filter :initialize_search_parameters

  attr_accessor :size, :page, :current_filter, :es_results, :result_set, 
                :search_results, :search, :pagination, :results, :no_render,
                :related_articles, :container, :search_context

  # ESType - [model, associations] mapping
  # Needed for loading records from DB
  #
  @@esv2_spotlight_models = {
    "ticket"  => { model: "Helpdesk::Ticket",   associations: [ :ticket_old_body ] },
    "note"    => { model: "Helpdesk::Note",     associations: [ :note_old_body ] },
    "topic"   => { model: "Topic",              associations: [] },
    "article" => { model: "Solution::Article",  associations: [ :folder, :article_body ] }
  }

  # Unscoped customer-side spotlight search
  #
  def all
    @searchable_klasses = esv2_klasses
    @current_filter = :all
    search
  end

  # Tickets scoped customer-side spotlight search
  #
  def tickets
    require_user_login unless current_user

    @searchable_klasses = ['Helpdesk::Ticket', 'Helpdesk::Note']
    @current_filter = :tickets
    search
  end

  # Forums scoped customer-side spotlight search
  #
  def topics
    require_user_login unless forums_enabled?

    @searchable_klasses = ['Topic']
    @current_filter = :topics
    search
  end

  # Solutions scoped customer-side spotlight search
  #
  def solutions
    require_user_login unless allowed_in_portal?(:open_solutions)

    @searchable_klasses = ['Solution::Article']
    @current_filter = :solutions
    search
  end

  def suggest_topic
    @no_render          = true
    @searchable_klasses = ['Topic']
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
        @result_set = Search::Utils.load_records(@es_results, @@esv2_spotlight_models.dclone, current_account.id)

        # Trying out with pagination hack
        # To-do: Bring under common wrapper
        @result_set = Search::Filters::Docs::Results.new(@result_set, {
                                                          page: @page,
                                                          from: @offset,
                                                          total_entries: @es_results['hits']['total']
                                                        })

        process_results
      rescue Exception => e
        @search_results = []
        @result_set = []

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

    # To-do: Handling phrase queries, add note params
    # Constructing params for ES
    #
    def construct_es_params
      Hash.new.tap do |es_params|
        es_params[:search_term]               = @search_key
        es_params[:account_id]                = current_account.id ##needed?
        es_params[:article_status]            = SearchUtil::DEFAULT_SEARCH_VALUE.to_i
        es_params[:article_visibility]        = visibility_opts(Solution::Constants::VISIBILITY_KEYS_BY_TOKEN)
        es_params[:topic_visibility]          = visibility_opts(Forum::VISIBILITY_KEYS_BY_TOKEN)
        if current_user
          es_params[:article_company_id]     = current_user.company_id.to_i
          es_params[:topic_company_id]       = current_user.company_id.to_i
          if privilege?(:client_manager)
            es_params[:ticket_company_id]     = current_user.company_id.to_i
          else
            es_params[:ticket_requester_id]   = current_user.id
          end
        end
        es_params[:article_category_id]       = current_portal.portal_solution_categories.map(&:solution_category_id) if @searchable_klasses.include?('Solution::Article')
        es_params[:topic_category_id]         = current_portal.portal_forum_categories.map(&:forum_category_id) if @searchable_klasses.include?('Topic')

        es_params[:size]                      = @size
        es_params[:from]                      = @offset

        es_params[:subject_boost]             = BOOST_VALUES['portal_spotlight'][:subject_boost]]
        es_params[:description_boost]         = BOOST_VALUES['portal_spotlight'][:description_boost]]
        es_params[:attachment_boost]          = BOOST_VALUES['portal_spotlight'][:attachment_boost]]
        es_params[:to_emails_boost]           = BOOST_VALUES['portal_spotlight'][:to_emails_boost]] 
        es_params[:es_cc_boost]               = BOOST_VALUES['portal_spotlight'][:es_cc_boost]]
        es_params[:es_fwd_emails_boost]       = BOOST_VALUES['portal_spotlight'][:es_fwd_emails_boost]]
        es_params[:note_attachment_boost]     = BOOST_VALUES['portal_spotlight'][:note_attachment_boost]] 
        es_params[:body_boost]                = BOOST_VALUES['portal_spotlight'][:body_boost]] 
        es_params[:company_description_boost] = BOOST_VALUES['portal_spotlight'][:company_description_boost]] 
        es_params[:company_domains_boost]     = BOOST_VALUES['portal_spotlight'][:company_domains_boost]]
        es_params[:company_name_boost]        = BOOST_VALUES['portal_spotlight'][:company_name_boost]]
        es_params[:user_name_boost]           = BOOST_VALUES['portal_spotlight'][:user_name_boost]] 
        es_params[:user_emails_boost]         = BOOST_VALUES['portal_spotlight'][:user_emails_boost]] 
        es_params[:user_description_boost]    = BOOST_VALUES['portal_spotlight'][:user_description_boost]] 
        es_params[:user_job_boost]            = BOOST_VALUES['portal_spotlight'][:user_job_boost]] 
        es_params[:user_phone_boost]          = BOOST_VALUES['portal_spotlight'][:user_phone_boost]] 
        es_params[:user_mobile_boost]         = BOOST_VALUES['portal_spotlight'][:user_mobile_boost]] 
        es_params[:user_company_boost]        = BOOST_VALUES['portal_spotlight'][:user_company_boost]] 
        es_params[:twitter_boost]             = BOOST_VALUES['portal_spotlight'][:twitter_boost]]
        es_params[:fb_profile_boost]          = BOOST_VALUES['portal_spotlight'][:fb_profile_boost]] 
        es_params[:topic_title_boost]         = BOOST_VALUES['portal_spotlight'][:topic_title_boost]] 
        es_params[:posts_attachment_boost]    = BOOST_VALUES['portal_spotlight'][:posts_attachment_boost]] 
        es_params[:posts_body_boost]          = BOOST_VALUES['portal_spotlight'][:posts_body_boost]] 
        es_params[:article_title_boost]       = BOOST_VALUES['portal_spotlight'][:article_title_boost]] 
        es_params[:article_desc_boost]        = BOOST_VALUES['portal_spotlight'][:article_desc_boost]] 
        es_params[:article_tag_boost]         = BOOST_VALUES['portal_spotlight'][:article_tag_boost]]
        es_params[:article_attachment_boost]  = BOOST_VALUES['portal_spotlight'][:article_attachment_boost]] 


      end
    end

    # To-do: Check if already exists
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
        model_names.concat(['Helpdesk::Ticket', 'Helpdesk::Note'])  if current_user
        model_names.push('Topic')                                   if forums_enabled?
        model_names.push('Solution::Article')                       if allowed_in_portal?(:open_solutions)
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

    ######################
    ### Before filters ###
    ######################

    def initialize_search_parameters
      @search_key     = params[:term] || params[:search_key] || ''
      @es_results     = []
      @size           = (params[:max_matches].to_i.zero? or
                        params[:max_matches].to_i < Search::Utils::MAX_PER_PAGE) ? Search::Utils::MAX_PER_PAGE : params[:max_matches]
      @page           = (params[:page].to_i.zero? ? 1 : params[:page].to_i)
      @offset         = @size * (@page - 1)
      @search_context = :portal_spotlight
    end

end
