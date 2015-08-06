class Support::Solutions::ArticlesController < SupportController 
  
  include Helpdesk::TicketActions
  include Solution::Feedback
  include Solution::ArticlesVotingMethods

  before_filter :load_and_check_permission, :except => [:index]

  before_filter :render_404, :unless => :article_visible?, :only => [:show]

  before_filter :load_agent_actions, :only => :show

  before_filter { |c| c.check_portal_scope :open_solutions }

  rescue_from ::AbstractController::ActionNotFound, :with => :handle_unknown

  newrelic_ignore :only => [:thumbs_up,:thumbs_down]
  before_filter :load_vote, :only => [:thumbs_up,:thumbs_down]

  skip_before_filter :verify_authenticity_token, :only => [:thumbs_up,:thumbs_down]

  before_filter :generate_ticket_params, :only => :create_ticket
  after_filter :add_watcher, :add_to_article_ticket, :only => :create_ticket, :if => :no_error

  before_filter :adapt_attachments, :only => [:show]


  def handle_unknown
     redirect_to send(Helpdesk::ACCESS_DENIED_ROUTE)
  end
  
  def index
    redirect_to support_solutions_path
  end
  
  def show
    wrong_portal and return unless(main_portal? || 
        (current_portal.has_solution_category?(@article.folder.category_id)))

    respond_to do |format|
      format.html { 
        draft_preview? ? adapt_article : load_page_meta
        set_portal_page :article_view 
      }
      format.json { render :json => @article.to_json  }
    end
  end

  def hit
    @article.hit! unless agent?
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
    def load_and_check_permission
      @article = current_account.solution_articles.find_by_id!(params[:id], 
                  :readonly => false)### MULTILINGUAL SOLUTIONS - META READ HACK!!
      unless @article && @article.folder.visible?(current_user)    
        unless logged_in?
          session[:return_to] = solution_category_folder_article_path(@article.folder.category_id, @article.folder_id, @article.id)
          redirect_to login_url
        else
          flash[:warning] = t(:'flash.general.access_denied')
          redirect_to support_solutions_path and return
        end
      end
    end

    def article_visible?
      return false unless ((current_user && current_user.agent? && privilege?(:view_solutions)) || @article.published?)
      draft_preview_agent_filter?
    end
    
    def load_agent_actions
      @agent_actions = []
      @agent_actions <<   { :url => edit_solution_category_folder_article_path(@article.folder.category, @article.folder, @article),
                            :label => t('portal.preview.edit_article'),
                            :icon => "edit" } if privilege?(:manage_solutions)
      @agent_actions <<   { :url => solution_category_folder_article_path(@article.folder.category, @article.folder, @article),
                            :label => t('portal.preview.view_on_helpdesk'),
                            :icon => "preview" } if privilege?(:view_solutions)
      @agent_actions
    end
    
    def load_page_meta
      @page_meta ||= {
        :title => @article.article_title,
        :description => @article.article_description,
        :keywords => @article.article_keywords,
        :canonical => support_solutions_article_url(@article, :host => current_portal.host)
      }
    end

    def draft_preview?
      params[:status] == "preview"
    end

    def draft_preview_agent_filter?
      return (current_user && current_user.agent? && (@article.draft.present? || !@article.published?) && privilege?(:view_solutions)) if draft_preview?
      true
    end

    def adapt_article
      draft = @article.draft
      if @article.draft.present?
        @article.attributes.each do |key, value|
          @article.send("#{key}=", draft.send(key)) if draft.respond_to?(key) and key != 'id'
        end
        @article.freeze
      end
      @page_meta = { :title => @article.title }
    end

    def adapt_attachments
      return true unless draft_preview?
      flash[:notice] = t('solution.articles.draft.portal_preview_msg')
      @article[:current_attachments] = active_attachments(:attachments)
      @article[:current_cloud_files] = active_attachments(:cloud_files)
    end

    def active_attachments(att_type)
      return @article.send(att_type) unless @article.draft.present?
      att = @article.send(att_type) + @article.draft.send(att_type)
      deleted_att_ids = []
      if @article.draft.meta.present? && @article.draft.meta[:deleted_attachments].present? && @article.draft.meta[:deleted_attachments][att_type].present?
        deleted_att_ids = @article.draft.meta[:deleted_attachments][att_type]
      end
      return att.select {|a| !deleted_att_ids.include?(a.id)}
    end
    
    def no_error
      !@ticket.errors.any?
    end

end

