class Public::TicketsController < ApplicationController

include SupportTicketControllerMethods

before_filter :set_selected_tab

  def show
    schema_less_ticket = current_account.schema_less_tickets.find_by_access_token(params[:id])
    unless schema_less_ticket
      access_denied
    else
      @ticket = schema_less_ticket.ticket
      respond_to do |format|
        format.html
        format.mobile {
          		render :json => @ticket.to_mob_json(true)
        	}        
      end
    end
	end

 private
  def set_selected_tab
    @selected_tab = :checkstatus
  end
end
