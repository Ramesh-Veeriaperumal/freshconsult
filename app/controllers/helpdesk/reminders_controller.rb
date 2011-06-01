class Helpdesk::RemindersController < ApplicationController
  
  before_filter { |c| c.requires_permission :manage_tickets }

  before_filter :optionally_load_parent, :only => [:create]

  include HelpdeskControllerMethods
  
  before_filter :load_item, :only => [:show, :edit, :update, :complete ]  
  
  def complete
    @item.update_attribute(:deleted, true)
    flash[:notice] = t(:'flash.to_dos.complete.success')
    redirect_to :back
  end
  
  def destroy
  	@items.each do |item|
      item.destroy
    end

    flash[:notice] = t(:'flash.general.destroy.success', :human_name => "To-Do")
    redirect_to :back
  end

 def restore
    @items.each do |item|
      item.update_attribute(:deleted, false)
    end

    redirect_to :back
  end

protected

  def scoper
    (@parent && @parent.reminders) || Helpdesk::Reminder
  end

  def item_url
    flash[:notice] = t(:'flash.general.create.success', :human_name => "To-Do")
    :back
  end

  def create_error
    redirect_to :back
  end

end
