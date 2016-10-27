# encoding: utf-8
class Support::SearchV2::SpotlightController < SupportController

  include ActionView::Helpers::TextHelper
  include Search::V2::AbstractController

  # Unscoped customer-side spotlight search
  #
  def all
    @klasses        = esv2_klasses
    @current_filter = :all
    @search_context = :portal_spotlight_global
    search(esv2_portal_models)
  end

  # Tickets scoped customer-side spotlight search
  #
  def tickets
    require_user_login unless current_user

    @klasses        = ['Helpdesk::Ticket', 'Helpdesk::ArchiveTicket']
    @current_filter = :tickets
    @search_context = :portal_spotlight_ticket
    search(esv2_portal_models)
  end

  # Forums scoped customer-side spotlight search
  #
  def topics
    require_user_login unless forums_enabled?

    @klasses        = ['Topic']
    @current_filter = :topics
    @search_context = :portal_spotlight_topic
    search(esv2_portal_models)
  end

  # Solutions scoped customer-side spotlight search
  #
  def solutions
    require_user_login unless allowed_in_portal?(:open_solutions)

    @klasses        = ['Solution::Article']
    @current_filter = :solutions
    @search_context = :portal_spotlight_solution
    search(esv2_portal_models)
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
          es_params[:article_visibility]        = visibility_opts(Solution::Constants::VISIBILITY_KEYS_BY_TOKEN)
          es_params[:article_company_id]        = current_user.company_ids if current_user
          es_params[:article_category_id]       = current_portal.portal_solution_categories.map(&:solution_category_meta_id)
        end

        if searchable_klasses.include?('Topic')
          es_params[:topic_visibility]          = visibility_opts(Forum::VISIBILITY_KEYS_BY_TOKEN)
          es_params[:topic_category_id]         = current_portal.portal_forum_categories.map(&:forum_category_id)
          es_params[:topic_company_id]          = current_user.company_ids if current_user
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
      redirect_to send(Helpdesk::ACCESS_DENIED_ROUTE)
    end

    # ESType - [model, associations] mapping
    # Needed for loading records from DB
    #
    def esv2_portal_models
      @@esv2_portal_spotlight ||= {
        'ticket'        => { model: 'Helpdesk::Ticket',         associations: [ :ticket_old_body, :group, :requester, :company ] },
        'archiveticket' => { model: 'Helpdesk::ArchiveTicket',  associations: [] },
        'topic'         => { model: 'Topic',                    associations: [ :forum ] },
        'article'       => { model: 'Solution::Article',        associations: [:article_body, { :solution_folder_meta => :solution_category_meta } ] }
      }
    end

end