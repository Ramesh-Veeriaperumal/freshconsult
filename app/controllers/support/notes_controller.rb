class Support::NotesController < ApplicationController
  def create
    @ticket = Helpdesk::Ticket.find_by_param(params[:ticket_id], current_account)
    raise ActiveRecord::RecordNotFound unless @ticket

    access = (current_user && @ticket.requester_id == current_user.id) || (permission?(:manage_tickets))

    return redirect_to(send(Helpdesk::ACCESS_DENIED_ROUTE)) unless access
  
    @note = @ticket.notes.build({
        "incoming" => true,
        "private" => false,
        "source" => Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['note'],
        "user_id" => current_user && current_user.id,
        "account_id" =>current_account && current_account.id
      }.merge(params[:helpdesk_note]))
    

    if @note.save
      create_attachments
      flash[:notice] = "The note has been added to your ticket."
    else
      flash[:error] = "There was a problem adding the note to your ticket. Please try again."
    end

    redirect_to :back
  end
  

  def create_attachments 
    return unless @note.respond_to?(:attachments)
    (params[:helpdesk_note][:attachments] || []).each do |a| 
      @note.attachments.create(:content => a[:file], :description => a[:description], :account_id => @note.account_id)
    end
  end
  
end
