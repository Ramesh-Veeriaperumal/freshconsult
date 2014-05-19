class Support::Mobihelp::TicketsController < SupportController

  include Helpdesk::TicketActions

  before_filter :require_user_login
  before_filter :build_tickets, :only => [:index]
  before_filter :load_ticket, :only => [:show]
  before_filter :check_ticket_permissions, :only => [:show]
  before_filter :pre_process_mobihelp_params, :only => [:create]

  def create
    status = false;
    if create_the_ticket(nil)
      create_tag(@assoc_device.app.name) if @assoc_device && @assoc_device.app
      store_debug_logs
      status = true;
    else
      logger.debug "Ticket Errors is #{@ticket.errors.inspect}"
    end
    respond_to do |format|
      format.json {
        render :json => {:success => status, :ticket => ( status ? @ticket : {})}
      }
    end
  end

  def show
    respond_to do |format|
      format.json {
        render :json => @ticket
      }
    end
  end

  def index
    respond_to do |format|
      format.json {
        render :json => @tickets
      }
    end
  end

  private
    def build_tickets
      if params[:device_uuid] #filter by device id
        @assoc_device = current_user.mobihelp_devices.find_by_device_uuid(params[:device_uuid])
        @tickets = @assoc_device.tickets
      else # fallback to mobihelp filter
        @tickets = current_user.tickets.find_by_source( TicketConstants::SOURCE_KEYS_BY_TOKEN[:mobihelp] );
      end
      @tickets ||= [];
    end

    def pre_process_mobihelp_params
      params[:helpdesk_ticket][:requester_id] = current_user.id # set the user to the current logged in user

      @assoc_device = current_user.mobihelp_devices.find_by_device_uuid(params[:helpdesk_ticket][:external_id])
      unless @assoc_device 
        render :json => unregistered_device
      end
      if params[:helpdesk_ticket][:mobihelp_ticket_info_attributes]  && @assoc_device
        params[:helpdesk_ticket][:mobihelp_ticket_info_attributes][:account_id] = current_account.id;
        params[:helpdesk_ticket][:mobihelp_ticket_info_attributes][:device_id] = @assoc_device.id;
      end
    end

    def create_tag(tag_name)
      begin
        tag = current_account.tags.find_by_name(tag_name) || current_account.tags.create(:name => tag_name)
        @ticket.tags << tag
      rescue ActiveRecord::RecordInvalid => e
      end
    end

    def unregistered_device
      { :success => false, :unregistered => true }
    end

    def store_debug_logs
      @mobihelp_ticket_info = @ticket.mobihelp_ticket_info
      if params[:helpdesk_ticket][:mobihelp_ticket_info_attributes] and params[:helpdesk_ticket][:mobihelp_ticket_info_attributes][:debug_data]
        a = params[:helpdesk_ticket][:mobihelp_ticket_info_attributes][:debug_data];
        @mobihelp_ticket_info.create_debug_data(:content => a[:resource], :description => a[:description],:account_id => @ticket.account_id);
      end
    end

    def load_ticket
      @ticket = @item = Helpdesk::Ticket.find_by_param(params[:id], current_account)
    end

    def check_ticket_permissions
      render :json => { :access_denied => true } unless @ticket and current_user.has_ticket_permission? @ticket
    end
end
