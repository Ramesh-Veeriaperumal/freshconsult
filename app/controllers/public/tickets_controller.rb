class Public::TicketsController < ApplicationController

  include SupportTicketControllerMethods

  skip_before_filter :check_privilege
  before_filter :check_public_ticket_feature, :load_ticket, :check_scope, :set_selected_tab


  def show
    respond_to do |format|
      format.html
      format.mobile {
          	render :json => @ticket.to_mob_json(true)
        }
    end
	end

  private

  def check_public_ticket_feature
    unless current_account.features_included?(:public_ticket_url)
      flash[:notice] = I18n.t(:'flash.general.access_denied')
      redirect_to send(Helpdesk::ACCESS_DENIED_ROUTE)
    end
  end

   def load_ticket
    schema_less_ticket = current_account.schema_less_tickets.find_by_access_token(params[:id])
    unless schema_less_ticket
      load_archived_ticket
    else
      @ticket = schema_less_ticket.ticket
    end
   end

   def load_archived_ticket
     @ticket = current_account.archive_tickets.find_by_access_token(params[:id])
     access_denied unless @ticket
   end

   def check_scope
    # # To avoid 2 redirects.  
    return unless current_user && current_user.agent?  
    case 
    when @ticket.is_a?(Helpdesk::Ticket) && @ticket.accessible_in_helpdesk?(current_user)
      redirect_to helpdesk_ticket_url(@ticket, :format => params[:format])
    when @ticket.is_a?(Helpdesk::Ticket) && @ticket.restricted_in_helpdesk?(current_user)
      redirect_to support_ticket_url(@ticket)
    when @ticket.is_a?(Helpdesk::ArchiveTicket) && @ticket.accessible_in_helpdesk?(current_user)
      redirect_to helpdesk_archive_ticket_url(@ticket.display_id, :format => params[:format])
    when @ticket.is_a?(Helpdesk::ArchiveTicket) && @ticket.restricted_in_helpdesk?(current_user)
      redirect_to support_archive_ticket_url(@ticket.display_id)
    end
   end

  def set_selected_tab
    @selected_tab = :checkstatus
  end
end
