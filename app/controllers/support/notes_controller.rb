class Support::NotesController < ApplicationController

  skip_before_filter :check_privilege
  include SupportNoteControllerMethods
  
  before_filter :set_mobile , :only => [:create]

  def create
    @ticket = Helpdesk::Ticket.find_by_param(params[:ticket_id], current_account)
    raise ActiveRecord::RecordNotFound unless @ticket
    access = (current_user && @ticket.requester_id == current_user.id) ||
     (privilege?(:client_manager)  && @ticket.requester.customer == current_user.customer) ||
     (privilege?(:manage_tickets))

    return redirect_to(send(Helpdesk::ACCESS_DENIED_ROUTE)) unless access
  
    @note = @ticket.notes.build({
        "incoming" => true,
        "private" => false,
        "source" => Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['note'],
        "user_id" => current_user && current_user.id,
        "account_id" => current_account && current_account.id
      }.merge(params[:helpdesk_note]))
    
    build_attachments
    if @note.save
      update_cc_list if privilege?(:client_manager)
      flash[:notice] = t(:'flash.tickets.notes.create.success')
    else
      flash[:error] = t(:'flash.tickets.notes.create.failure')
    end
    respond_to do |format|
      format.html{
        redirect_to :back
      }
      format.mobile {
        render :json => {:success => true,:item => @note}.to_json
      }
    end
  end
  
end
