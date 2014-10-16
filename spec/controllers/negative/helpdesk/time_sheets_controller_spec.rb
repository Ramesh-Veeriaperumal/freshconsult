require 'spec_helper'

describe Helpdesk::TimeSheetsController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:each) do
    login_admin
    controller.class.any_instance.stubs(:privilege?).returns(false)
  end

  it "should not allow an unauthorized user to create a timer" do
    ticket = create_ticket
    user = add_new_user(@account)
    post :create, { :time_entry => { :workable_id => ticket.id,
                                     :user_id => user.id,
                                     :hhmm => "1:30",
                                     :billable => "1",
                                     :executed_at => DateTime.now.strftime("%d/%m/%Y"),
                                     :timer_running => 1},
                    :ticket_id => ticket.display_id
                  }
    flash[:error].should be_eql(I18n.t(:'flash.tickets.timesheet.create_error'))
  end

  it "should not allow an unauthorized user to toggle a timer" do
    ticket = create_ticket
    user = add_new_user(@account)
    time_sheet = FactoryGirl.build(:time_sheet, :user_id => user.id,
                                            :workable_id => ticket.id,
                                            :account_id => @account.id,
                                            :billable => 1,
                                            :timer_running => false)
    time_sheet.save
    put :toggle_timer, :id => time_sheet.id
    flash[:error].should be_eql(I18n.t(:'flash.tickets.timesheet.create_error'))
  end
end
