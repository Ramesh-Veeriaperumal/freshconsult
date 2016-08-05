class Ember::TicketsController < ApiApplicationController
  include Common::TicketsControllerConcern
  
  def index
    super
    response.api_meta = { :count => tickets_filter.count }
    #TODO-EMBERAPI Optimize the way we fetch the count
    render "tickets/index"
  end
  
  def resource
    :ticket
  end
end
