class Support::NotesController < ApplicationController
  def create
    @ticket = Helpdesk::Ticket.find_by_param(params[:ticket_id], current_account)
    raise ActiveRecord::RecordNotFound unless @ticket

    access = (current_user && @ticket.requester_id == current_user.id) ||
      (permission?(:manage_tickets)) ||
      (params[:access_token] && @ticket.access_token == params[:access_token])

    return redirect_to(send(Helpdesk::ACCESS_DENIED_ROUTE)) unless access
    
    @note = @ticket.notes.build(
      {
        :incoming => true,
        :private => false,
        :source => 1,
        :user_id => current_user && current_user.id
      }.merge(params[:helpdesk_note])
    )

    if @note.save
      flash[:notice] = "The note has been added to your request."
    else
      flash[:error] = "There was a problem adding the note to your request. Please try again."
    end

    redirect_to :back
  end
end
