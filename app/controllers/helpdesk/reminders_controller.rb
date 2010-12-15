class Helpdesk::RemindersController < ApplicationController
  
  before_filter { |c| c.requires_permission :manage_tickets }

  before_filter :optionally_load_parent, :only => [:create]

  include HelpdeskControllerMethods

protected

  def scoper
    (@parent && @parent.reminders) || Helpdesk::Reminder
  end

  def item_url
    :back
  end

  def create_error
    redirect_to :back
  end

end
