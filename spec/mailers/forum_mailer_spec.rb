require 'spec_helper'

RSpec.describe ForumMailer do

  before(:all) do
    @follower = add_test_agent(@account) 
    @forum_category = create_test_category
    @forum = create_test_forum(@forum_category)
  end

  describe "Notification for new follower" do

    before(:each) do
      ActionMailer::Base.perform_deliveries = false
      @monitorship = monitor_forum(@forum,@follower,@account.main_portal.id)
      @mail = ForumMailer.notify_new_follower(@forum,@follower,@monitorship.portal,@monitorship)
    end

    it 'renders the receiver email' do
        @mail.to.to_s.should == @follower.email
     end

    it 'should set the subject to the correct subject' do
      @mail.subject.should == "Added as Forum Follower - #{@forum.name}"
    end

    it 'renders the sender email' do  
        @mail.from.to_s.should == email_from_friendly_email(@monitorship.sender_and_host[0])
    end
    
  end

end