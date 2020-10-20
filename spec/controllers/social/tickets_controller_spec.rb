require 'spec_helper'
RSpec.configure do |c|
  c.include GnipHelper
  c.include DynamoHelper
end

RSpec.describe Helpdesk::TicketsController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    Resque.inline = true
    unless GNIP_ENABLED
      GnipRule::Client.any_instance.stubs(:list).returns([]) 
      Gnip::RuleClient.any_instance.stubs(:add).returns(add_response)
    end
    @handle = create_test_twitter_handle
    @default_stream = @handle.default_stream
    @ticket_rule = create_test_ticket_rule(@default_stream)
    update_db(@default_stream) unless GNIP_ENABLED
    @rule = {:rule_value => @default_stream.data[:rule_value] , :rule_tag => @default_stream.data[:rule_tag]}
    Resque.inline = false
   end
  
  before(:each) do
    Resque.inline = false
    log_in(@agent)
  end
    
  it "For twitter tickets, must split the note and add as ticket" do  
    includes = @default_stream.includes
    @ticket_rule.filter_data[:includes] = includes
    @ticket_rule.save
    feed = sample_gnip_feed(@rule)
    tweet = send_tweet_and_wait(feed)
    tweet.should_not be_nil
    tweet.is_ticket?.should be true
    tweet.stream_id.should_not be_nil
    tweet_body = feed["body"]
    ticket = tweet.get_ticket
    @account.reload
    tickets_count = @account.tickets.count
    
    #create a tweet as note
    @account.make_current # doing account.make_current at this point because Account.current is nil. Must figure out the reason
    body_text = Faker::Lorem.sentence
    twt_id = Time.zone.now.to_i * 10000
    note = ticket.notes.build(
      :note_body_attributes => {
        :body_html => body_text
      },
      :incoming   => true, :source => Helpdesk::Source::TWITTER,
      :account_id => @handle.account_id, :user_id    => ticket.requester_id,
      :tweet_attributes => {
        :tweet_id           => twt_id ,
        :tweet_type         => "mention",
        :twitter_handle_id  => @handle.id,
        :stream_id          => @default_stream.id
      }
    )
    note.save_note
    
    post :split_the_ticket, { :id => ticket.display_id,
        :note_id => note.id
    }
    ticket.notes.find_by_id(note.id).should be_nil
    ticket_incremented? tickets_count
    @account.tickets.last.ticket_body.description_html.should =~ /#{body_text}/
  end
    
  after(:all) do
    # destroy the handle
    # @handle.destroy
  end
end