module TicketHelper

  def create_ticket(params = {}, group = nil)
    requester_id = params[:requester_id] #|| User.find_by_email("rachel@freshdesk.com").id
    unless requester_id
      user = add_new_user(@account)
      requester_id = user.id
    end
    subject = params[:subject] || Faker::Lorem.words(10).join(" ")
    account_id =  group ? group.account_id : @account.id
    test_ticket = FactoryGirl.build(:ticket, :status => params[:status] || 2,
                                         :display_id => params[:display_id], 
                                         :requester_id =>  requester_id,
                                         :subject => subject,
                                         :responder_id => params[:responder_id],
                                         :source => params[:source] || 2,
                                         :cc_email => {:cc_emails => [], :fwd_emails => [], :reply_cc => []},
                                         :created_at => params[:created_at],
                                         :account_id => account_id,
                                         :custom_field => params[:custom_field])
    test_ticket.build_ticket_body(:description => Faker::Lorem.paragraph)
    if params[:attachments]
      test_ticket.attachments.build(:content => params[:attachments][:resource], 
                                    :description => params[:attachments][:description], 
                                    :account_id => test_ticket.account_id)
    end
    test_ticket.group_id = group ? group.id : nil
    test_ticket.save_ticket
    test_ticket
  end

  def ticket_incremented? ticket_size
    @account.reload
    @account.tickets.size.should eql ticket_size+1
  end

  def create_test_time_entry(params = {}, test_ticket = nil)
    ticket = test_ticket.blank? ? create_ticket : test_ticket
    time_sheet = FactoryGirl.build(:time_sheet, :user_id => params[:agent_id] || @agent.id,
                                            :workable_id => ticket.id,
                                            :account_id => @account.id,
                                            :billable => params[:billable] || 1,
                                            :note => Faker::Lorem.sentence(3))
    time_sheet.save
    time_sheet
  end
end
