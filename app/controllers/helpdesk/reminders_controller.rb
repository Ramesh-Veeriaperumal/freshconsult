class Helpdesk::RemindersController < ApplicationController
  

  before_filter :optionally_load_parent, :only => [:create]

  include HelpdeskControllerMethods
  
  before_filter :load_item, :only => [ :show, :edit, :update, :complete, :restore ]  
  before_filter :verify_permission, :only => [ :create, :show, :edit, :update, :complete, :restore ]  
  before_filter :verify_items_permission, :only => [:destroy]
  before_filter :reminder_partial
  
  def complete
    @item.update_attribute(:deleted, true)
    #flash.now[:notice] = t(:'flash.to_dos.complete.success')
    render_page
  end
  
  def destroy
  	@items.each do |item|
      item.destroy
    end
    #flash.now[:notice] = t(:'flash.general.destroy.success', :human_name => "To-Do")
    render_page
  end

  def restore
    @item.update_attribute(:deleted, false)
    render_page
  end  

protected

  def scoper
    (@parent && @parent.reminders) || Helpdesk::Reminder
  end

  def item_url
    flash.now[:notice] = t(:'flash.general.create.success', :human_name => "To-Do")
    :back
  end
  
  def render_page
    respond_to do |format|
      format.html { redirect_to :back }
      format.js
    end
  end

  def create_error
    redirect_to :back
  end

  def reminder_partial
    @reminder_partial = (params[:source] && params[:source] == 'ticket_view') ? '/helpdesk/tickets/show/reminders/reminder' : '/helpdesk/reminders/reminder'
  end

  def verify_permission(item = nil)
    item = item || @item
    if item.ticket_id
      verify_ticket_permission(item.ticket)
    else
      verify_user_permission(item)
    end
  end

  def verify_items_permission
    @items.each do |item|
      verify_permission(item)
    end
  end

end
