class Support::TicketsController < SupportController
  #validates_captcha_of 'Helpdesk::Ticket', :only => [:create]
  helper SupportTicketControllerMethods
  include SupportTicketControllerMethods 
  include Support::TicketsHelper
  include ExportCsvUtil

  before_filter { |c| c.requires_permission :portal_request }
  before_filter :only => [:new, :create] do |c| 
    c.check_portal_scope :anonymous_tickets
  end
  before_filter :check_user_permission, :only => [:show]
  before_filter :require_user_login, :only => [:show, :index, :filter, :close, :update, :add_people]
  before_filter :load_item, :only =>[:show, :update, :close, :add_people]

  before_filter :set_mobile, :only => [:filter, :show, :update, :close]
  before_filter :set_date_filter, :only => [:export_csv]  

  def show
    @visible_ticket_fields = current_portal.ticket_fields(:customer_visible).reject{ |f| !f.visible_in_view_form? }

    @agent_visible = @visible_ticket_fields.any? { |tf| tf[:field_type] == "default_agent" }
    # @editable_ticket_fields = current_portal.ticket_fields(:customer_editable).reject{ |f| !f.visible_in_view_form? }

    set_portal_page :ticket_view
  end
  
  def index    
    build_tickets
    @page_title = t("helpdesk.tickets.views.#{@current_filter}")    
    set_portal_page :ticket_list
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
    set_portal_page :ticket_list
    respond_to do |format|
      format.html { render :partial => "ticket_list" }
      format.js
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
    @csv_headers = export_fields(true)
    render :layout => false
    # render :partial => "helpdesk/tickets/configure_export", :locals => {:csv_headers => export_fields(true)}
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

  def close
    status_id = Helpdesk::Ticketfields::TicketStatus::CLOSED
    if @item.update_attribute(:status , status_id)
     flash[:notice] = I18n.t('ticket_close_success')
    else
     flash[:notice] = I18n.t('ticket_close_failure')
    end
    redirect_to :back
  end

  def add_people
    cc_params = params[:helpdesk_ticket][:cc_email][:cc_emails].split(/,/)
    @ticket.cc_email[:cc_emails] = cc_params.delete_if {|x| !valid_email?(x)}
    @ticket.save
    flash[:notice] = "Email(s) successfully added to CC."
    redirect_to support_ticket_path(@ticket)
  end  

  protected 

    def cname
      @cname ||= controller_name.singularize
    end

    def load_item
      @ticket = @item = Helpdesk::Ticket.find_by_param(params[:id], current_account) 
      @item || raise(ActiveRecord::RecordNotFound)      
    end

    def redirect_url
      current_user ? support_ticket_url(@ticket) : root_path
    end
  
    def build_tickets
      @company = current_user.customer.presence
      @filter_users = current_user.customer.users if 
            @company && current_user.client_manager? && @company.users.size > 1 

      @requested_by = current_requested_by

      date_added_ticket_scope = (params[:start_date].blank? or params[:end_date].blank?) ? 
          ticket_scope.tickets : 
          ticket_scope.tickets.created_at_inside(params[:start_date], params[:end_date])

      @tickets = TicketsFilter.filter(current_filter, current_user, date_added_ticket_scope)
      per_page = mobile? ? 30 : params[:wf_per_page] || 10
      @tickets = @tickets.paginate(:page => params[:page], :per_page => per_page, 
          :order => "#{current_wf_order} #{current_wf_order_type}") 

      @tickets ||= []
    end

    def many_employees_in_company?
      current_user.client_manager? && has_company? && customer.user > 1
    end


    # Used for scoping of filters
    def ticket_scope
      if current_user.client_manager?
        if @requested_by.to_i == 0
          current_user.customer
        else
          @requested_item = current_account.users.find_by_id(@requested_by)
        end
      else
        @requested_item = current_user
      end
    end
   
    def require_user_login
      return redirect_to(send(Helpdesk::ACCESS_DENIED_ROUTE)) unless current_user
    end

    def check_user_permission
      if current_user and current_user.agent? and session[:preview_button].blank?
        return redirect_to helpdesk_ticket_url(:format => params[:format])
      end
    end

  
end
