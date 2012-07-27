class Support::TicketsController < Support::SupportController
  #validates_captcha_of 'Helpdesk::Ticket', :only => [:create]
  include SupportTicketControllerMethods 
  before_filter { |c| c.requires_permission :portal_request }
  before_filter :only => [:new, :create] do |c| 
    c.check_portal_scope :anonymous_tickets
  end
  before_filter :require_user_login , :only =>[:index,:filter,:close_ticket, :update]
  before_filter :load_item, :only =>[:update]
  before_filter :set_mobile, :only => [:filter,:show,:update,:close_ticket]
  
  uses_tiny_mce :options => Helpdesk::TICKET_EDITOR
  
  def index
    @page_title = t('helpdesk.tickets.views.all_tickets')
    build_tickets
    respond_to do |format|
      format.html
      format.xml  { render :xml => @tickets.to_xml }
    end
  end
  
  def update
    if @item.update_attributes(params[:helpdesk_ticket])
      respond_to do |format|
        format.mobile { render :json => { :success => true, :item => @item }.to_json }
        format.html { 
          flash[:notice] = t(:'flash.general.update.success', :human_name => cname.humanize.downcase)
          redirect_to @item 
        }
      end
    end
  end

  def filter   
    @page_title = TicketsFilter::CUSTOMER_SELECTOR_NAMES[current_filter.to_sym]
    build_tickets
    respond_to do |format|
      format.mobile {
        unless @response_errors.nil?
          render :json => {:errors => @response_errors}.to_json
        else
          json = "["; sep=""
          @tickets.each { |tic| 
            #Removing the root node, so that it conforms to JSON REST API standards
            # 19..-2 will remove "{helpdesk_ticket:" and the last "}"
            json << sep + tic.to_json({}, false)[19..-2]; sep=","
          }
          render :json => json + "]"
        end
      }
      format.html {
        render :index
      }
    end 
  end
  
  def close_ticket
    @item = Helpdesk::Ticket.find_by_param(params[:id], current_account)
     status_id = Helpdesk::Ticketfields::TicketStatus::CLOSED
     logger.debug "close the ticket...with status id  #{status_id}"
     res = Hash.new
     mob_json = {}
     if @item.update_attribute(:status , status_id)
       # res["success"] = true
       #        res["status"] = 'Closed'
       #        res["value"]  = status_id
       #        res["message"] = "Successfully updated"
       #        render :json => ActiveSupport::JSON.encode(res)
       flash[:notice] = "Successfully updated"
       mob_json[:success] = true
     else
       # res["success"] = false
       # res["message"] = "closing the ticket failed"
       # render :json => ActiveSupport::JSON.encode(res)      
       flash[:notice] = "Closing the ticket failed"
       mob_json[:failure] = true
     end
     respond_to do |format|
      format.mobile {
        mob_json[:item] = @item;
        render :json => mob_json.to_json
      }
      format.html{
        redirect_to :back
      }
     end
  end
    
  protected 

    def cname
      @cname ||= controller_name.singularize
    end

    def load_item
      @item = Helpdesk::Ticket.find_by_param(params[:id], current_account) 
      @item || raise(ActiveRecord::RecordNotFound)      
    end
    def redirect_url
      current_user ? support_ticket_url(@ticket) : root_path
    end
  
   def current_filter
      params[:id] || 'all'
    end
  
    def build_tickets
    @tickets = TicketsFilter.filter(current_filter.to_sym, current_user, current_user.tickets)
    @tickets = @tickets.paginate(:page => params[:page], :per_page => 10) unless mobile?
    @tickets = @tickets.paginate(:page => params[:page]) if mobile?
    @tickets ||= []    
   end
   
   def require_user_login
     return redirect_to(send(Helpdesk::ACCESS_DENIED_ROUTE)) unless current_user
   end
  
   

end
