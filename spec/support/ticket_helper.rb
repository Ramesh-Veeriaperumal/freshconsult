require File.expand_path("#{File.dirname(__FILE__)}/../spec_helper")

module TicketHelper

  def create_ticket(params = {}, group = nil)
    requester_id = params[:requester_id] #|| User.find_by_email("rachel@freshdesk.com").id
    unless requester_id
      user = add_new_user(Account.first)
      requester_id = user.id
    end
    subject = params[:subject] || Faker::Lorem.words(10).join(" ")
    account_id =  group ? group.account_id : Account.first.id
    test_ticket = Factory.build(:ticket, :status => params[:status],
                                         :display_id => params[:display_id], 
                                         :requester_id =>  requester_id,
                                         :subject => subject,
                                         :responder_id => params[:responder_id],
                                         :cc_email => {:cc_emails => [], :fwd_emails => []},
                                         :created_at => params[:created_at],
                                         :account_id => account_id)
    test_ticket.build_ticket_body(:description => Faker::Lorem.paragraph)
    test_ticket.group_id = group ? group.id : nil
    test_ticket.save_ticket
    test_ticket
  end
end
