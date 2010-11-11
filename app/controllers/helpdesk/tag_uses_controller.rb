class Helpdesk::TagUsesController < ApplicationController
  layout 'helpdesk/default'

  before_filter { |c| c.requires_permission :manage_tickets }

  def create
    ticket = Helpdesk::Ticket.find_by_param(params[:ticket_id])
    raise ActiveRecord::RecordNotFound unless ticket

    tag = Helpdesk::Tag.find_by_name_and_account_id(params[:name], current_account) || Helpdesk::Tag.new(:name => params[:name], 
      :account_id => current_account.id)

    begin
      ticket.tags << tag
    rescue ActiveRecord::RecordInvalid => e
    end

    flash[:notice] = "The tag was added"

    redirect_to :back
  end

  def destroy
    ticket = Helpdesk::Ticket.find_by_param(params[:ticket_id])
    raise ActiveRecord::RecordNotFound unless ticket

    tag = ticket.tags.find_by_id(params[:id])
    raise ActiveRecord::RecordNotFound unless tag

    # ticket.tags.delete(tag) does not call tag_use.destroy, so it won't 
    # decrement the counter cache. This is a workaround.
    Helpdesk::TagUse.find_by_ticket_id_and_tag_id(ticket.id, tag.id).destroy

    flash[:notice] = "The tag was removed from this ticket"
    redirect_to :back
    
  end
  
  
end
