class Support::Mobihelp::TicketsController < SupportController

  include Helpdesk::TicketActions
  include Mobihelp::MobihelpHelperMethods

  before_filter :mobihelp_user_login
  before_filter :validate_user
  before_filter :require_user_login
  before_filter :build_tickets, :only => [:index]
  before_filter :load_ticket, :only => [:show,:notes,:close]
  before_filter :check_ticket_permissions, :only => [:show,:notes,:close]
  before_filter :pre_process_mobihelp_params, :only => [:create]
  skip_before_filter :check_day_pass_usage

  def create
    status = false
    if create_the_ticket(nil)
      create_tag(@assoc_device.app.name) if @assoc_device && @assoc_device.app
      store_debug_logs
      status = true
    else
      logger.debug "Ticket Errors is #{@ticket.errors.inspect}"
    end
    render_json({:success => status, :ticket => ( status ? @ticket : {})})
  end

  def show
    if current_account.features_included?(:limit_mobihelp_results)
      render_json(@ticket.to_mobihelp_json())
    else
      render_json(@ticket)
    end
  end

  def index
    if current_account.features_included?(:limit_mobihelp_results)
      ticket_json_list = []
      @tickets.each do |ticket|
        ticket_json_list << ticket.to_mobihelp_json()
      end
      render_json("[#{ticket_json_list.join(",")}]")
    else
      render_json(@tickets.to_json())
    end
  end

  def close
    status = @ticket.update_attribute(:status , Helpdesk::Ticketfields::TicketStatus::CLOSED)
    render_json({ :success => status })
  end

  def notes
    @note = @ticket.notes.build({
      "incoming" => true,
      "private" => false,
      "source" => Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['note'],
      "user_id" => current_user && current_user.id,
      "account_id" => current_account && current_account.id
    }.merge(params[:helpdesk_note]))
    if params[:helpdesk_note][:attachments]
      attachment_content = params[:helpdesk_note][:attachments]
      @note.attachments.build(:content => attachment_content[:resource], :description => attachment_content[:description])
    end

    success = @note.save_note
    render_json({ :success => success, :item => @note })
  end

  def cache_enabled?
    false
  end

  private
    def build_tickets
      if params[:device_uuid] #filter by device id
        @assoc_device = current_user.mobihelp_devices.find_by_device_uuid(params[:device_uuid])
        @tickets = if current_account.features_included?(:limit_mobihelp_results)
          @assoc_device.tickets.includes(:mobihelp_notes =>  [:note_old_body])
        else
          @assoc_device.tickets.includes(:notes =>  [:note_old_body, :attachments,:schema_less_note])
        end
      else # fallback to mobihelp filter
        @tickets = current_user.tickets.find_by_source( TicketConstants::SOURCE_KEYS_BY_TOKEN[:mobihelp] )
      end
      @tickets ||= []
    end

    def pre_process_mobihelp_params
      params[:helpdesk_ticket][:requester_id] = current_user.id # set the user to the current logged in user

      @assoc_device = current_user.mobihelp_devices.find_by_device_uuid(params[:helpdesk_ticket][:external_id])
      unless @assoc_device
        render_json(unregistered_device)
      end
      if params[:helpdesk_ticket][:mobihelp_ticket_info_attributes]  && @assoc_device
        params[:helpdesk_ticket][:mobihelp_ticket_info_attributes][:account_id] = current_account.id
        params[:helpdesk_ticket][:mobihelp_ticket_info_attributes][:device_id] = @assoc_device.id
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
        a = params[:helpdesk_ticket][:mobihelp_ticket_info_attributes][:debug_data]
        @mobihelp_ticket_info.create_debug_data(:content => a[:resource], :description => a[:description],:account_id => @ticket.account_id)
      end
    end

    def load_ticket
      @ticket = @item = if current_account.features_included?(:limit_mobihelp_results)
        Helpdesk::Ticket.includes(:mobihelp_notes =>  [:note_old_body])
          .where(:display_id => params[:id], :account_id => current_account.id ).first
      else
        Helpdesk::Ticket.includes(:notes =>  [:note_old_body, :attachments,:schema_less_note])
          .where(:display_id => params[:id], :account_id => current_account.id ).first
      end
    end

    def check_ticket_permissions
      render_json({ :access_denied => true }) unless @ticket and current_user.has_ticket_permission? @ticket
    end

    def validate_user
      unless valid_user?
        render_json({:success => false, :status_code => MOBIHELP_STATUS_CODE_BY_NAME[:MHC_USER_DELETED]})
      end
    end
end
