class Helpdesk::TicketIssuesController < ApplicationController
  layout 'helpdesk/default'
  include HelpdeskControllerMethods

  def item_url
    @item.ticket
  end

end
