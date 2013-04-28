require File.expand_path("#{File.dirname(__FILE__)}/../spec_helper")

module TicketHelper

  def create_ticket(params = {}, group = nil)
  	requester = User.find_by_email("customer@customer.in")
  	test_ticket = Factory.build(:ticket, :status => params[:status],
  						:display_id => params[:display_id], :requester_id =>  requester.id)
  	test_ticket.account_id =  group ? group.account_id : Account.first.id
  	test_ticket.group_id = group ? group.id : nil
  	test_ticket.save(false)
  	test_ticket
  end
end