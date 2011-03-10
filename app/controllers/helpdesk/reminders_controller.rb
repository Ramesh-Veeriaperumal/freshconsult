class Helpdesk::RemindersController < ApplicationController
  
  before_filter { |c| c.requires_permission :manage_tickets }

  before_filter :optionally_load_parent, :only => [:create]

  include HelpdeskControllerMethods
  
   def destroy
    @items.each do |item|
      if item.respond_to?(:deleted)
        item.update_attribute(:deleted, true)
        @restorable = true
      else
        item.destroy
      end
    end

    respond_to do |expects|
      expects.html do       
        redirect_to after_destroy_url
      end
      expects.js do
        render(:update) { |page| @items.each { |i| page.visual_effect('fade', dom_id(i)) } }
      end
    end

  end

protected

  def scoper
    (@parent && @parent.reminders) || Helpdesk::Reminder
  end

  def item_url
    flash[:notice] = "To do has been created."
    :back
  end

  def create_error
    redirect_to :back
  end

end
