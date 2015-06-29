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
    post :note, note_params.merge!({:format => 'xml', :ticket_id => Helpdesk::Ticket.first.display_id}),:content_type => 'application/xml'
    result =  parse_xml(response)
    expected = (response.status == 201) && compare(result['helpdesk_note'].keys.sort, APIHelper::NOTE_ATTRIBS.sort,{}).empty?
    expected.should be(true)
  end

  it "should not create a note if user_id is invalid" do
    post :note, note_params({:user_id => 978979}).merge!({:format => 'xml', :ticket_id => Helpdesk::Ticket.first.display_id}),:content_type => 'application/xml'
    result =  parse_xml(response)
    response.status.should be(400)
    expect(result).to eq({"errors"=>{"error"=>"User can't be blank"}})
  end

  it "should create a note with attachments" do
    file = fixture_file_upload('/files/attachment.txt', 'plain/text', :binary)
    post :note, note_params({:file => file}).merge!(:format => 'xml', :ticket_id => Helpdesk::Ticket.first.display_id)
    result =  parse_xml(response)
    expected = (response.status == 201) && compare(result['helpdesk_note']['attachments'].first.keys, APIHelper::ATTACHMENT_ATTRIBS,{}).empty?
    expected.should be(true)
  end

end
