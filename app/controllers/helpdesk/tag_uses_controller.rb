class Helpdesk::TagUsesController < ApplicationController

  before_filter { |c| c.requires_permission :manage_tickets }

  def create
    ticket = Helpdesk::Ticket.find_by_param(params[:ticket_id], current_account)
    raise ActiveRecord::RecordNotFound unless ticket

    tag = Helpdesk::Tag.find_by_name_and_account_id(params[:name], current_account) || Helpdesk::Tag.new(:name => params[:name], 
      :account_id => current_account.id)

    begin
      ticket.tags << tag
    rescue ActiveRecord::RecordInvalid => e
    end

    flash[:notice] = t(:'ticket.tags.create_success')

    redirect_to :back
  end

  def destroy
    ticket = Helpdesk::Ticket.find_by_param(params[:ticket_id], current_account)
    raise ActiveRecord::RecordNotFound unless ticket

    tag = ticket.tags.find_by_id(params[:id])
    raise ActiveRecord::RecordNotFound unless tag

    taggable_type = params[:taggable_type] || "Helpdesk::Ticket"
    # ticket.tags.delete(tag) does not call tag_use.destroy, so it won't 
    # decrement the counter cache. This is a workaround. need to re-work..now this will work only for ticket module
    
    Helpdesk::TagUse.find_by_taggable_id_and_tag_id_and_taggable_type(ticket.id, tag.id,taggable_type ).destroy
    count = tag.tag_uses_count - 1
    tag.update_attribute(:tag_uses_count,count )
    
    flash[:notice] = t(:'ticket.tags.destroy_success')
    redirect_to :back
    
  end
  
  
end
