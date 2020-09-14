class Support::Solutions::ArticlesController < SupportController 
  
  include Helpdesk::TicketActions
  include Solution::Feedback
  include Solution::ArticlesVotingMethods
  include Solution::PathHelper
  include Helpdesk::Permission::Ticket
  include ApplicationHelper

  before_filter :redirect_to_support, :only => [:show], :if => :facebook?
  before_filter :load_and_check_permission, :except => [:index]

  before_filter :draft_preview_login_filter?, :only => [:show]
  
  before_filter :check_version_availability, :only => [:show]

  before_filter :article_visible?, :only => [:show, :hit]
 
  before_filter :load_agent_actions, :only => :show

  before_filter { |c| c.check_portal_scope :open_solutions }

  rescue_from ::AbstractController::ActionNotFound, :with => :handle_unknown

  newrelic_ignore :only => [:thumbs_up,:thumbs_down]
  before_filter :load_vote, :only => [:thumbs_up,:thumbs_down]
  skip_before_filter :verify_authenticity_token, :only => [:thumbs_up,:thumbs_down]

  before_filter :verify_authenticity_token, :only => [:thumbs_up, :thumbs_down, :create_ticket], :unless => :public_request?
  
  before_filter :filter_params, :only => :create_ticket
  before_filter :check_permissibility, :only => :create_ticket
  before_filter :generate_ticket_params, :only => :create_ticket
  after_filter :add_watcher, :add_to_article_ticket, :only => :create_ticket, :if => :no_error

  before_filter :cleanup_params_for_title, :only => [:show]
  before_filter :load_current_object_id, :only => [:show]
 
  before_filter :set_interaction_source, only: [:hit, :thumbs_up, :thumbs_down]

   CREATE_TICKET_VALID_FIELDS = ["email"]

  def redirect_to_support
    redirect_to "/support/solutions/articles/#{params[:id]}"
  end 

  def handle_unknown
     redirect_to safe_send(Helpdesk::ACCESS_DENIED_ROUTE)
  end
  
  def index
    redirect_to support_solutions_path
  end
  
  def show
    respond_to do |format|
      format.html { 
        draft_preview? ? adapt_article : load_page_meta
        set_portal_page :article_view 
      }
      format.json { render :json => @article.to_json(Solution::Constants::API_OPTIONS)  }
    end
  end

  def hit
    @article.current_article.hit! if !agent? || current_account.solutions_agent_metrics_enabled?
    render_tracker
  end
  
  def create_ticket
    # Message to the user based on success of ticket submission
    create_the_ticket(nil, true) ?
    	render(:text => I18n.t('solution.articles.article_not_useful')) : feedback_error
  end

  def feedback_error
  	render :partial => "feedback_form"
  end

  private

    def set_interaction_source
      @article.current_article.set_portal_interaction_source
    end

    def filter_params
      if params[:helpdesk_ticket].present?
        current_user ? params.except!(:helpdesk_ticket) : params[:helpdesk_ticket].slice!(*CREATE_TICKET_VALID_FIELDS)
      end
    end

    def check_permissibility
      if(params[:helpdesk_ticket].present? && params[:helpdesk_ticket][:email].present?)
        unless can_create_ticket? params[:helpdesk_ticket][:email]
          render(:text => I18n.t('solution.articles.article_not_useful'))
          return false
        end
      end
    end

    def load_and_check_permission
      @solution_item = @article = current_account.solution_article_meta.find_by_id(params[:id])
      render_404 and return if @article && !parent_exists?
      if @article && !@article.visible?(current_user)
        unless logged_in?
          store_location
          redirect_to login_url
        else
          flash[:warning] = t(:'flash.general.access_denied')
          redirect_to support_solutions_path and return
        end
      end
    end
    
    def parent_exists?
      @article.solution_folder_meta.present? && 
      @article.solution_folder_meta.solution_category_meta.present?
    end

    def article_visible?
      unless @article && @article.visible_in?(@portal)
        render_404
        return
      end

      if (!solution_agent? && draft_preview?)
        render_404
        return
      end

      return if @article.status == Solution::Article::STATUS_KEYS_BY_TOKEN[:published]

      unless solution_agent?
        render_404 && return if draft_preview?
        current_account.multilingual? ? version_unavailable : render_404
        return
      end

      render_404 if draft_preview? && !@article.draft.present? #for draft preview of published articles
      render_404 unless draft_preview_agent_filter?
    end

    def solution_agent?
      current_user && current_user.agent? && privilege?(:view_solutions)
    end

    def version_unavailable
      unless @article.current_is_primary?
        flash[:warning] = version_not_available_msg(controller_name.singularize)
        redirect_to(support_home_path) and return
      end
      render_404 #For unpublished primary articles
    end
    
    def load_agent_actions      
      @agent_actions = []
      @agent_actions << { url: agent_actions_path(@article, anchor: 'edit'), label: t('portal.preview.edit_article'), icon: 'edit' } if privilege?(:manage_solutions)
      @agent_actions << { url: agent_actions_path(@article), label: t('portal.preview.view_on_helpdesk'), icon: 'preview' } if privilege?(:view_solutions)
      @agent_actions
    end

    def generate_og_meta
      @og_meta ||= {
        title: @article.article_title,
        short_description: @article.desc_un_html.truncate(250)
      }
      @og_meta[:image_url] = logo_url
        @og_meta[:author] = @article.user.name if @article.user && Account.current.main_portal.personalized_articles?
        @og_meta
    end

    def load_page_meta
      @page_meta ||= {
        :description => @article.article_description,
        :keywords => @article.article_keywords,
        :canonical => support_solutions_article_url(@article, :host => current_portal.host)
      }
      @page_meta.merge!(generate_og_meta)
    end

    def draft_preview?
      params[:status] == "preview"
    end

    def draft_preview_login_filter?
      if !current_user && draft_preview?
        store_location
        redirect_to support_login_path
      end
    end

    def draft_preview_agent_filter?
      return (current_user && current_user.agent? && (@article.draft.present? || 
            !@article.current_article.published?) && privilege?(:view_solutions)) if draft_preview?
      true
    end

    def adapt_article
      draft = @article.draft
      if @article.draft.present?
        @article.attributes.each do |key, value|
          @article.safe_send("#{key}=", draft.safe_send(key)) if draft.respond_to?(key) and key != 'id'
        end
        adapt_attachments
        @article.freeze

        flash[:notice] = t('solution.articles.draft.portal_preview_msg_v2')
      end
      @page_meta = generate_og_meta
    end

    def adapt_attachments
      @article[:current_attachments] = active_attachments(:attachments)
      @article[:current_cloud_files] = active_attachments(:cloud_files)
    end

    def active_attachments(att_type)
      return @article.safe_send(att_type) unless @article.draft.present?
      att = @article.safe_send(att_type) + @article.draft.safe_send(att_type)
      deleted_att_ids = []
      if @article.draft.meta.present? && @article.draft.meta[:deleted_attachments].present? && @article.draft.meta[:deleted_attachments][att_type].present?
        deleted_att_ids = @article.draft.meta[:deleted_attachments][att_type]
      end
      return att.select {|a| !deleted_att_ids.include?(a.id)}
    end
    
    def no_error
      @ticket.present? && !@ticket.errors.any?
    end

    def cleanup_params_for_title
      params.slice!("id", "format", "controller", "action", "status", "url_locale", "portal_type")
    end

    def route_name(language)
      support_solutions_article_path(@solution_item.safe_send("#{language.to_key}_article") || @solution_item, :url_locale => language.code)
    end

    def unscoped_fetch
      @article = current_account.solution_article_meta.unscoped_find(params[:id])
    end

    def default_url
      support_solutions_article_path(@article.primary_article, :url_locale => current_account.language)
    end

    def load_current_object_id
      @current_object = { current_object_id: @article.id }
    end
end

