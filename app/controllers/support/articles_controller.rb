class Support::ArticlesController < ApplicationController 
  
  
  
  before_filter { |c| c.requires_permission :portal_knowledgebase }
  
  rescue_from ActionController::UnknownAction, :with => :handle_unknown

  def handle_unknown
     redirect_to send(Helpdesk::ACCESS_DENIED_ROUTE)
  end
  
  def index
    @articles = Solution::Article.visible(current_account).paginate(
      :page => params[:page], 
      :conditions => ["title LIKE ?", "%#{params[:v]}%"],
      :per_page => 10
    )
  end
  
  def show
      @article = Solution::Article.find(params[:id], :include => :folder) 
    respond_to do |format|
      format.html
      format.xml  { render :xml => @article.to_xml(:include => :folder) }
    end
     raise ActiveRecord::RecordNotFound unless @article && (@article.account_id == current_account.id) && (@article.is_public?)
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
    @ticket = Helpdesk::Ticket.new(params[:helpdesk_ticket])
    set_default_values
    if  @ticket.save
     @ticket.create_activity(@ticket.requester, "{{user_path}} submitted a new ticket {{notable_path}}", {}, 
                                   "{{user_path}} submitted the ticket")
     if params[:meta]
        @ticket.notes.create(
          :body => params[:meta].map { |k, v| "#{k}: #{v}" }.join("\n"),
          :private => true,
          :source => Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['meta'],
          :account_id => current_account.id
        )
      end
      render :text => "Thanks for the feedback. We will improve this article."
    else
      render :text => "There is an error #{@ticket.errors}"
     end
  end
  
  def set_default_values
   @ticket.status = Helpdesk::Ticket::STATUS_KEYS_BY_TOKEN[:open]
   @ticket.source = Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN[:portal]
   @ticket.requester_id = current_user && current_user.id
   @ticket.account_id = current_account.id
   #@ticket.email = current_account.email
  end
  

end
