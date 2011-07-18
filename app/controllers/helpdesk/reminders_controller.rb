class Helpdesk::RemindersController < ApplicationController
  
  before_filter { |c| c.requires_permission :manage_tickets }

  before_filter :optionally_load_parent, :only => [:create]

  include HelpdeskControllerMethods
  
  before_filter :load_item, :only => [ :show, :edit, :update, :complete, :restore ]  
  
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

end
