# encoding: utf-8
class Support::SearchV2::SpotlightController < SupportController

  include ActionView::Helpers::TextHelper
  include Search::V2::AbstractController

  before_filter :force_exact_match
  before_filter :set_es_locale

  NON_UNICODE_LANGUAGES = %w[th ja-JP].freeze

  # Unscoped customer-side spotlight search
  #
  def all
    unless current_user || forums_enabled? || allowed_in_portal?(:open_solutions)
      require_user_login and return
    else
      @klasses        = esv2_klasses
      @current_filter = :all
      @search_context = :portal_spotlight_global
      search(esv2_portal_models)
    end
  end

  # Tickets scoped customer-side spotlight search
  #
  def tickets
    unless current_user
      require_user_login and return
    else
      @klasses        = ['Helpdesk::Ticket', 'Helpdesk::ArchiveTicket']
      @current_filter = :tickets
      @search_context = :portal_spotlight_ticket
      search(esv2_portal_models)
    end
  end

  # Forums scoped customer-side spotlight search
  #
  def  topics
    unless forums_enabled?
      require_user_login and return
    else
      @klasses        = ['Topic']
      @current_filter = :topics
      @search_context = :portal_spotlight_topic
      search(esv2_portal_models)
    end
  end

  # Solutions scoped customer-side spotlight search
  #
  def solutions
    unless allowed_in_portal?(:open_solutions)
      require_user_login and return
    else
      @klasses        = ['Solution::Article']
      @current_filter = :solutions
      @search_context = :portal_spotlight_solution
      search(esv2_portal_models)
    end
  end

  def suggest_topic
    @no_render      = true
    @klasses        = ['Topic']
    @search_context = :portal_spotlight_topic
    search(esv2_portal_models)
    @results = @search_results

    render template: '/support/search/suggest_topic', :layout => false
  end

  private

    # Constructing params for ES
    #
    def construct_es_params
      super.tap do |es_params|
        if current_user
          es_params[:ticket_requester_id]   = current_user.id
          es_params[:ticket_company_id]     = current_user.client_manager_companies.map(&:id)
        end

        if searchable_klasses.include?('Solution::Article')
          es_params[:language_id]               = Language.current.try(:id) || Language.for_current_account.id
          es_params[:article_status]            = SearchUtil::DEFAULT_SEARCH_VALUE.to_i
          es_params[:article_visibility]        = article_visibility_opts(Solution::Constants::VISIBILITY_KEYS_BY_TOKEN)
          if current_user
            es_params[:article_company_id]                = current_user.company_ids
            es_params[:article_company_filter_ids]        = current_user.company_segment_ids  if (@search_context == :portal_spotlight_global)
            es_params[:article_contact_filter_ids]        = current_user.segments if (@search_context == :portal_spotlight_global) #contact segment ids 
            es_params[:query] = @query_condition if (@search_context == :portal_spotlight_solution && soln_search_segments.present?)
          end
          es_params[:article_category_id]       = soln_search_categories
          if current_account.portal_article_filters_enabled?
            es_params[:article_folder_id]         = soln_search_folders if params[:folder_ids]
            es_params[:article_tags]              = params[:tags].to_s.split(',').uniq.join('","') if params[:tags]
          end
        end

        if searchable_klasses.include?('Topic')
          es_params[:topic_visibility]          = visibility_opts(Forum::VISIBILITY_KEYS_BY_TOKEN)
          forum_category_ids                    = current_portal.portal_forum_categories.pluck(:forum_category_id)
          es_params[:topic_category_id]         = params[:forum_category_ids].nil? ? forum_category_ids : search_forum_categories_with_ids(forum_category_ids)
          es_params[:topic_company_id]          = current_user.company_ids if current_user
          es_params[:query]                     = search_forums_with_ids(forum_category_ids) if params[:forum_ids]
        end

        es_params[:size] = @size
        es_params[:from] = @offset
      end
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
          visiblity.push(visiblity_class[:agents]) if current_user.agent?
        end
      end
    end

    def article_visibility_opts visiblity_class
      Array.new.tap do |visiblity|
        visiblity.push(visiblity_class[:anyone])
        if current_user
          visiblity.push(visiblity_class[:logged_users])
          visiblity.push(visiblity_class[:company_users]) if current_user.has_company? || current_user.agent?
          visiblity.push(visiblity_class[:contact_segment]) if current_user.has_contact_segment? || current_user.agent?
          visiblity.push(visiblity_class[:company_segment]) if current_user.has_company_segment? || current_user.agent?
          visiblity.push(visiblity_class[:agents]) if current_user.agent?
        end
      end
    end

    def esv2_klasses
      super.tap do |model_names|
        model_names.concat(['Helpdesk::Ticket', 'Helpdesk::ArchiveTicket']) if current_user
        model_names.push('Topic')                                           if forums_enabled?
        model_names.push('Solution::Article')                               if allowed_in_portal?(:open_solutions)
      end
    end

    def process_results
      @search_results = []
      @result_set.each do |item|
        next if item.nil?
        result = item_based_selection(item)
        next unless result
        result.merge!('source' => item) if !request.xhr?
        @search_results << result
      end
      super
    end

    def item_based_selection item
      case item.class.name
        when 'Solution::Article'
          solution_result(item) if (item.solution_folder_meta.present? && 
            item.solution_folder_meta.solution_category_meta.present?)
        when 'Topic'
          topic_result(item)
        when 'Helpdesk::Ticket'
          ticket_result(item)
        when 'Helpdesk::ArchiveTicket'
          archive_ticket_result(item)
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

    ##################################
    ### Model based JSON responses ###
    ##################################

    def solution_result article
      { 'title' => article.es_highlight('title').html_safe,
        'group' => h(article.solution_folder_meta.name),
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
      redirect_to safe_send(Helpdesk::ACCESS_DENIED_ROUTE)
    end
    
    def set_es_locale
      @es_locale = current_portal.language if (current_portal && current_account.es_multilang_soln?)
    end

    # ESType - [model, associations] mapping
    # Needed for loading records from DB
    #
    def esv2_portal_models
      @@esv2_portal_spotlight ||= {
        'ticket'        => { model: 'Helpdesk::Ticket',         associations: [ :ticket_body, :group, :requester, :company ] },
        'archiveticket' => { model: 'Helpdesk::ArchiveTicket',  associations: [] },
        'topic'         => { model: 'Topic',                    associations: [ :forum ] },
        'article'       => { model: 'Solution::Article',        associations: [:article_body, { :solution_folder_meta => :solution_category_meta } ] }
      }
    end

    def soln_search_categories
      @soln_search_categories ||= begin
        portal_category_meta_ids = current_portal.portal_solution_categories.map(&:solution_category_meta_id)
        if current_account.portal_article_filters_enabled? && params[:category_ids].present?
          filtered_categories = params[:category_ids].split(',').map(&:to_i) & portal_category_meta_ids
          @invalid = true if filtered_categories.empty?
        end
        filtered_categories.presence || portal_category_meta_ids
      end
    end

    def soln_search_folders
      portal_folder_meta_ids = current_portal.account.solution_folder_meta.public_folders(soln_search_categories).map(&:id)
      filtered_folders = params[:folder_ids].split(',').map(&:to_i) & portal_folder_meta_ids
      @invalid = true if filtered_folders.empty?
      filtered_folders.presence || portal_folder_meta_ids
    end

    def soln_search_segments
      filtered_contact_segments = current_user.segments
      filtered_contact_segments.map!(&:to_s)
      query_condition1 = filtered_contact_segments.collect{|id| 'contact_filter_ids:'+id}.join(' OR ')
      filtered_company_segments = current_user.company_segment_ids
      filtered_company_segments.map!(&:to_s)
      query_condition2 = filtered_company_segments.collect{|id| 'company_filter_ids:'+id}.join(' OR ')
      query_condition1 = 'contact_filter_ids:null OR '+ query_condition1 if query_condition1.present?
      query_condition2 = 'company_filter_ids:null OR ' + query_condition2 if query_condition2.present?
      @query_condition = query_condition1.present? && query_condition2.present? ? "("+query_condition1+")" + " AND "+ "("+query_condition2+")" : query_condition1.present? ? "("+query_condition1+")" : query_condition2.present? ? "("+query_condition2+")" : ""
    end

    def search_forums_with_ids(category_ids)
      forum_ids = Account.current.forums.where(forum_category_id: category_ids).pluck(:id)
      filter_forum_ids = params[:forum_ids].split(',').map(&:to_i) & forum_ids
      @invalid = true if filter_forum_ids.empty?
      filtered_ids = filter_forum_ids.presence || forum_ids
      filtered_ids.map!(&:to_s)
      query_condition = filtered_ids.collect{ |x| 'forum_id:' + x }.join(' OR ')
    end

    def search_forum_categories_with_ids(forum_category_ids)
      filter_forum_category_ids = params[:forum_category_ids].split(',').map(&:to_i) & forum_category_ids
      @invalid = true if filter_forum_category_ids.empty?
      filter_forum_category_ids.presence || forum_category_ids
    end

    def force_exact_match
      @exact_match = true if NON_UNICODE_LANGUAGES.include?(Language.current.code)
    end
end
