require 'spec_helper'

RSpec.describe TopicMailer do

  self.use_transactional_fixtures = false

  before(:each) do
    @forum_category = create_test_category
    @forum = create_test_forum(@forum_category)
    @topic = create_test_topic(@forum)
  end

  describe "Notification for new follower" do

    before(:all) do
      @follower = add_test_agent(@account) 
    end

    before(:each) do
      ActionMailer::Base.perform_deliveries = false
      @monitorship = monitor_forum(@forum,@follower,@account.main_portal.id)
      @mail = TopicMailer.notify_new_follower(@topic,@follower,@monitorship)
    end

    it 'renders the receiver email' do
        @mail.to.to_s.should == @follower.email
     end

    it 'should set the subject to the correct subject' do
      @mail.subject.should == "Added as Topic Follower - #{@topic.title}"
    end

    it 'renders the sender email' do  
        @mail.from.to_s.should == email_from_friendly_email(@monitorship.sender_and_host[0])
     end

  end

end