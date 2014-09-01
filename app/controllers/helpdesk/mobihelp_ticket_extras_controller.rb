class Helpdesk::MobihelpTicketExtrasController < ApplicationController

  before_filter :load_ticket, :only => [:index]

  def index
    respond_to do |format|
      format.html do
        render :index, :layout => false
      end
    end
  end

  private
    def load_ticket
      @ticket = current_account.tickets.find_by_display_id(params[:ticket_id])
      unless @ticket.nil?
        @extra_info = @ticket.mobihelp_ticket_info
      end
    end
end
