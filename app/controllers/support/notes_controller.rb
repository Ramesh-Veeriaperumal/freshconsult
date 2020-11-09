class Support::NotesController < ApplicationController

  skip_before_filter :check_privilege
  include SupportNoteControllerMethods
  
  before_filter :set_mobile , :only => [:create]

  def create
    @ticket = Helpdesk::Ticket.find_by_param(params[:ticket_id], current_account)
    raise ActiveRecord::RecordNotFound unless @ticket
    access = current_user.present? && (@ticket.requester_id == current_user.id ||
     (current_user.company_client_manager?  && current_user.company_ids.include?(@ticket.company_id)) ||
     (current_user.contractor_ticket? @ticket) ||
     (privilege?(:manage_tickets)))

    return redirect_to(safe_send(Helpdesk::ACCESS_DENIED_ROUTE)) unless access
  
    @note = @ticket.notes.build({
        "incoming" => true,
        "private" => false,
        "source" => current_account.helpdesk_sources.note_source_keys_by_token['note'],
        "user_id" => current_user && current_user.id,
        "account_id" => current_account && current_account.id
      }.merge(params[:helpdesk_note].permit(*(Helpdesk::Note::PERMITTED_PARAMS))))
    
    build_attachments
    if @note.save_note
      update_cc_list if current_user.company_client_manager?
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
