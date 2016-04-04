require 'spec_helper'

RSpec.describe Helpdesk::ConversationsController do

  self.use_transactional_fixtures = false

  before(:each) do
    request.host = @account.full_domain
    http_login(@agent)
    clear_json
    stub_s3_writes
  end
 
  it "should create a note" do
    post :note, note_params.merge!({:format => 'json', :ticket_id => Helpdesk::Ticket.first.display_id}),:content_type => 'application/json'
    result =  parse_json(response)
    expected = (response.status == 200) && compare(result['note'].keys, APIHelper::NOTE_ATTRIBS,{}).empty?
    expected.should be(true)
  end

  it "should not create a note if user_id is invalid" do
    post :note, note_params({:user_id => 978979}).merge!({:format => 'json', :ticket_id => Helpdesk::Ticket.first.display_id}),:content_type => 'application/json'
    result =  parse_json(response)
    response.status.should be(400)
    expect(result).to eq({"user" => ["can't be blank"]} )
  end

  it "should create a note with attachments" do
    file = fixture_file_upload('/files/attachment.txt', 'plain/text', :binary)
    post :note, note_params({:file => file}).merge!(:format => 'json', :ticket_id => Helpdesk::Ticket.first.display_id)
    result =  parse_json(response)
    expected = (response.status == 200) && compare(result['note']['attachments'].first.keys, APIHelper::ATTACHMENT_ATTRIBS,{}).empty?
    expected.should be(true)
  end
end
