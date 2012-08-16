class Support::TicketsController < ApplicationController

  #validates_captcha_of 'Helpdesk::Ticket', :only => [:create]
  include SupportTicketControllerMethods 
  include Support::TicketsHelper
  include ExportCsvUtil

  before_filter { |c| c.requires_permission :portal_request }
  before_filter :only => [:new, :create] do |c| 
    c.check_portal_scope :anonymous_tickets
  end
  before_filter :require_user_login , :only =>[:index,:filter,:close_ticket, :update]
  before_filter :load_item, :only =>[:update]
  before_filter :set_mobile, :only => [:filter,:show,:update,:close_ticket]
  before_filter :set_date_filter ,    :only => [:export_csv]

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
        format.html { 
          flash[:notice] = t(:'flash.general.update.success', :human_name => cname.humanize.downcase)
          redirect_to @item 
        }
        format.mobile { 
          render :json => { :success => true, :item => @item }.to_json 
        }
      end
    end
  end

  def filter   
    @page_title = TicketsFilter::CUSTOMER_SELECTOR_NAMES[current_filter.to_sym]
    build_tickets
    respond_to do |format|
      format.html {
        if params[:partial].blank?
          render :index
        else
          render :partial => "/support/shared/ticket_list"
        end
      }
      format.mobile {
        unless @response_errors.nil?
          render :json => {:errors => @response_errors}.to_json
        else
          json = "["; sep=""
          @tickets.each { |tic| 
            #Removing the root node, so that it conforms to JSON REST API standards
            # 19..-2 will remove "{helpdesk_ticket:" and the last "}"
            json << sep + tic.to_json({
              :except => [ :description_html, :description ],
              :methods => [ :status_name, :priority_name, :source_name, :requester_name,
                            :responder_name, :need_attention, :pretty_updated_date ]
            }, false)[19..-2]; sep=","
          }
          render :json => json + "]"
        end
      }
    end
  end

  def configure_export
    render :partial => "helpdesk/tickets/configure_export", :locals => {:csv_headers => export_fields(true)}
  end
  
  def export_csv
    params[:wf_per_page] = "100000"
    params[:page] = "1"
    csv_hash = params[:export_fields]
    unless params[:a].blank?
      params[:id] = params[:i]
    end 
    items = build_tickets
    export_data items, csv_hash, true
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
      format.html{
        redirect_to :back
      }
      format.mobile {
        mob_json[:item] = @item;
        render :json => mob_json.to_json
      }
     end
  end

  def add_cc
      @ticket = Helpdesk::Ticket.find_by_id(params[:id])      
      cc_params = params[:ticket][:cc_email][:cc_emails].split(/,/)
      cc_emails_array = @ticket.cc_email[:cc_emails]
      cc_emails_array = Array.new if cc_emails_array.nil?
      cc_emails_array = cc_emails_array | cc_params  
      cc_emails_array = cc_emails_array.delete_if {|x|  !valid_email?(x)}
      @ticket.cc_email[:cc_emails] = cc_emails_array  
      @ticket.save
      flash[:notice] = ['"', cc_params.join(","),'" has been successfully added to CC.'].join()
      redirect_to support_ticket_path(@ticket)
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
  
    def build_tickets
      ticket_scope = (params[:start_date].blank? or params[:end_date].blank?) ? current_user.tickets : current_user.tickets.created_at_inside(params[:start_date], params[:end_date])
    @tickets = TicketsFilter.filter(current_filter.to_sym, current_user, ticket_scope)
    per_page = mobile? ? 30 : params[:wf_per_page] || 10
     @tickets = @tickets.paginate(:page => params[:page], :per_page => per_page, :order=> "#{current_wf_order} #{current_wf_order_type}") 
    @tickets ||= []
   end
   
   def require_user_login
     return redirect_to(send(Helpdesk::ACCESS_DENIED_ROUTE)) unless current_user
   end
  
end
