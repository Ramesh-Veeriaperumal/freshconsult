require 'spec_helper'

describe Support::Mobihelp::TicketsController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @user_email = "mobihelpuser@customer.in"
    @user_device_id = "11111-22222-3333333-312312312"
    @user = create_mobihelp_user(@account , @user_email, @user_device_id)

    ticket_attributes = get_sample_mobihelp_ticket_attributes("Ticket_controller New test ticket", @user_device_id, @user)
    @test_ticket = create_mobihelp_ticket(ticket_attributes)
  end

  before(:each) do
    log_in(@user)
    stub_s3_writes
  end

  describe "Ticket creation" do
    before(:each) do
      now = (Time.now.to_f*1000).to_i
      @test_subject = "#{Faker::Lorem.sentence(4)} #{now}"
      @ticket_attributes = get_sample_mobihelp_ticket_attributes(@test_subject,@user_device_id, @user)
    end
    it "should create a new mobihelp ticket" do
      post :create, @ticket_attributes
      @account.tickets.find_by_subject(@test_subject).should be_an_instance_of(Helpdesk::Ticket)
    end
    it "should fail for unregistered device" do
      @ticket_attributes[:helpdesk_ticket].merge!(:external_id => "invalid device id")
      post :create, @ticket_attributes
      @account.tickets.find_by_subject(@test_subject).should be_nil
    end
  end

  it "should fetch the ticket attributes" do
    request.env["HTTP_ACCEPT"] = "application/json"
    get :show, { :id => @test_ticket.display_id , :device_uuid => @user_device_id }
    JSON.parse(response.body).should have(1).items
  end

  it "should fetch all the tickets" do
    request.env["HTTP_ACCEPT"] = "application/json"
    get :index
    JSON.parse(response.body).should_not be_empty
  end

  it "should fetch all the tickets when device id is provided" do
    request.env["HTTP_ACCEPT"] = "application/json"
    get :index, :device_uuid => @user_device_id
    JSON.parse(response.body).should_not be_empty
  end

  it "should add note" do
    @request.params['format'] = "json"
    note = {
      :helpdesk_note => {
        :private => "false", 
        :note_body_attributes => {:body_html => "Add Note Test"},
        :incoming => "true", 
        :source => "10",
        },
        :id => @test_ticket.display_id
      }

    post :notes, note
  end

  it "should add note with attachment" do
    @request.params['format'] = "json"
    note = {
      :helpdesk_note => {
        :private => "false", 
        :note_body_attributes => {:body_html => "Add Note with attachment"},
        :incoming => "true", 
        :source => "10",
        :attachments => {:resource => Rack::Test::UploadedFile.new('spec/fixtures/files/mobihelp_attachment.png', 'image/png')}
        },
        :id => @test_ticket.display_id
      }

    post :notes, note
  end

  it "should close a mobihelp ticket" do
    @request.params['format'] = "json"
    ticket_attributes = get_sample_mobihelp_ticket_attributes("Ticket_controller New test ticket", @user_device_id, @user)
    ticket_to_close = create_mobihelp_ticket(ticket_attributes);

    post :close, :id => ticket_to_close.display_id

    ticket_to_close.reload

    @account.tickets.find_by_display_id(ticket_to_close.display_id).status.should be_eql(5)
  end

end
