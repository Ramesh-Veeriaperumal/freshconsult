class Support::Solutions::ArticlesController < SupportController 
  
  include Helpdesk::TicketActions
  include Solution::Feedback

  before_filter :load_and_check_permission, :except => :index

  before_filter :render_404, :unless => :article_visible?, :only => :show

  before_filter :load_agent_actions, :only => :show

  before_filter { |c| c.check_portal_scope :open_solutions }

  rescue_from ::AbstractController::ActionNotFound, :with => :handle_unknown

  newrelic_ignore :only => [:thumbs_up,:thumbs_down]
  before_filter :load_vote, :only => [:thumbs_up,:thumbs_down]

  skip_before_filter :verify_authenticity_token, :only => [:thumbs_up,:thumbs_down]

  before_filter :generate_ticket_params, :only => :create_ticket
  after_filter :add_watcher, :add_to_article_ticket, :only => :create_ticket

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
        load_page_meta
        set_portal_page :article_view 
      }
      format.json { render :json => @article.to_json  }
    end
  end

  def thumbs_up
    update_votes(:thumbs_up, 1)
    render :text => I18n.t('solution.articles.article_useful')
  end

  def thumbs_down
    # Voting down the article
    update_votes(:thumbs_down, 0)
    
    # Getting a new object for submitting the feeback for the article
    @ticket = Helpdesk::Ticket.new
    respond_to do |format|
      format.xml{ head :ok }
      format.json { head :ok }
      format.html {
        render :partial => "feedback_form", :locals => { :ticket => @ticket, :article => @article }
      }
      
    end

  end

  def hit
    @article.hit! unless agent?
    render_tracker
  end
  
  def create_ticket
    # Message to the user based on success of ticket submission
    render :text => (create_the_ticket(nil, true)) ? 
     I18n.t('solution.articles.article_not_useful') : I18n.t(:'solution.articles.error_message', :error_msg => @ticket.errors )
  end

  private
    def load_and_check_permission      
      @article = current_account.solution_articles.find_by_id!(params[:id], :include => :folder)
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
      (current_user && current_user.agent? && privilege?(:view_solutions)) || @article.published?
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

    def update_votes(incr, vote)
      return if agent?
      @article.increment!(incr) and return unless current_user

      @vote.vote = vote
      if @vote.new_record?
        @article.increment!(incr)
      elsif @vote.vote_changed?
        @article.send("toggle_#{incr}!")
      end
      @vote.save
    end

    def load_vote
      @vote = @article.votes.find_or_initialize_by_user_id(current_user.id) if current_user
    end
end

