class Support::Solutions::ArticlesController < SupportController 
  
  include Helpdesk::TicketActions
  
  before_filter { |c| c.requires_permission :portal_knowledgebase }
  before_filter :load_and_check_permission

  rescue_from ActionController::UnknownAction, :with => :handle_unknown

  newrelic_ignore :only => [:thumbs_up,:thumbs_down]

  def handle_unknown
     redirect_to send(Helpdesk::ACCESS_DENIED_ROUTE)
  end
  
  def index
    redirect_to support_solutions_path
  end
  
  def show
    wrong_portal and return unless(main_portal? || 
        (@article.folder.category_id == current_portal.solution_category_id))

    @page_title = @article.article_title
    @page_description = @article.article_description
    @page_keywords = @article.article_keywords
    @page_canonical = support_article_url(@article)

    set_portal_page :article_view   
  end
   
  def thumbs_up
    # Voting up the article
    @article.increment!(:thumbs_up)

    render :text => I18n.t('solution.articles.article_useful')
  end

  def thumbs_down
    # Voting down the article
    @article.increment!(:thumbs_down)
    
    # Getting a new object for submitting the feeback for the article
    @ticket = Helpdesk::Ticket.new

    # Rendering the feedback form for the user... to get his comments
    render :partial => "feedback_form", :locals => { :ticket => @ticket, :article => @article }
  end
  
  def create_ticket
    # Message to the user based on success of ticket submission
    render :text => (create_the_ticket) ? 
     I18n.t('solution.articles.article_not_useful') : I18n.t(:'solution.articles.error_message', :error_msg => @ticket.errors )
  end

  private
    def load_and_check_permission      
      @article = current_account.solution_articles.find_by_id!(params[:id], :include => :folder)
      unless @article && @article.folder.visible?(current_user)    
        flash[:warning] = t(:'flash.general.access_denied')
        redirect_to support_solutions_path and return
      end
    end
end
