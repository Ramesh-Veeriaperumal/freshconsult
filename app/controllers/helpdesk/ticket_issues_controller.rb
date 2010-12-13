class Helpdesk::TicketIssuesController < ApplicationController
  layout 'helpdesk/layout'
  include HelpdeskControllerMethods

  def item_url
    @item.ticket
  end

end
