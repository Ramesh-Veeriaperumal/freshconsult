class Helpdesk::TicketIssuesController < ApplicationController  
  include HelpdeskControllerMethods

  def item_url
    @item.ticket
  end

end
