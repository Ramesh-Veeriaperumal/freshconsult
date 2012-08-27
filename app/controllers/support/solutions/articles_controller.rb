class Support::Solutions::ArticlesController < SupportController 
  
  include Helpdesk::TicketActions
  
  before_filter { |c| c.requires_permission :portal_knowledgebase }

  before_filter :only => :show do |c|
    c.send(:set_portal_page, :article_view)
  end
  
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
        format.html { render :partial => "/support/shared/feedback_form" ,:locals =>{ :ticket => @ticket,:article => @article }}
        format.xml  { head 200}
      end
    
    
  end
  
   def thumbs_up
     @article = current_account.solution_articles.find(params[:id])
     @article.increment!(:thumbs_up)
     respond_to do |format|
        format.html { render :text => "Glad we could be helpful. Thanks for the feedback." }
        format.xml  { head 200}
      end
  end
  
  def create_ticket
    render :text => (create_the_ticket) ? "Thanks for the feedback. We will improve this article." : 
                  "There is an error #{@ticket.errors}"
  end

end
