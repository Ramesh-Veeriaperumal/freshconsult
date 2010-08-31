class Helpdesk::SubscriptionsController < ApplicationController
  layout 'helpdesk/default'

  before_filter { |c| c.requires_permission :manage_tickets }

  before_filter :load_parent_ticket

  include HelpdeskControllerMethods

protected

  def scoper
    @parent.subscriptions
  end

  def item_url
    :back
  end

  def create_error
    redirect_to :back
  end
  
end
