class Support::Solutions::ArticlesController < SupportController 
  
  include Helpdesk::TicketActions
  
  before_filter :check_solution_permission
  before_filter { |c| c.requires_permission :portal_knowledgebase }
  
  rescue_from ActionController::UnknownAction, :with => :handle_unknown
  
  newrelic_ignore :only => [:thumbs_up,:thumbs_down]

  def handle_unknown
     redirect_to send(Helpdesk::ACCESS_DENIED_ROUTE)
  end
  
  def index
    redirect_to support_solutions_path
  end
  
  def show
    @article = Solution::Article.find(params[:id], :include => :folder)    
    @category = @article.folder.category
    @folder = @article.folder
    
    set_portal_page :article_view

    respond_to do |format|
      format.html
      format.xml  { render :xml => @article.to_xml(:include => :folder) }
    end

    raise ActiveRecord::RecordNotFound unless @article && (@article.account_id == current_account.id) && (@article.folder.visible?(current_user))
  end
 
  def thumbs_down    
    @article = current_account.solution_articles.find(params[:id])
    @article.increment!(:thumbs_down)
   
    @ticket = Helpdesk::Ticket.new 
    respond_to do |format|
      format.html { render :partial => "/support/shared/feedback_form", :locals => { :ticket => @ticket,:article => @article }} 
      format.js
    end 
  end
  
  def thumbs_up
    @article = current_account.solution_articles.find(params[:id])
    @article.increment!(:thumbs_up)

    respond_to do |format|
      format.html { render :text => "Glad we could be helpful. Thanks for the feedback." }
      format.js
    end
  end
  
  def create_ticket
    render :text => (create_the_ticket) ? 
      "Thanks for the valuable feedback." : 
      "There is an error #{@ticket.errors}"
  end

  private
    def check_solution_permission  
      @solution = current_account.solution_articles.find(params[:id]) 
      unless @solution.folder.visible?(current_user)    
        flash[:notice] = t(:'flash.general.access_denied')
        redirect_to support_solutions_path and return
      end
    end

end
