require 'spec_helper'
#include ActionController::TestProcess

describe Helpdesk::AttachmentsController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:each) do
    log_in(@agent)
    stub_s3_writes
    file = fixture_file_upload('files/image.gif', 'image/gif')
    @test_ticket = create_ticket({ :status => 2, 
                                   :attachments => { :resource => file,
                                                     :description => Faker::Lorem.characters(10) 
                                                    } })
  end

  it "should not allow an unauthorized user to delete a shared attachment" do
    now = (Time.now.to_f*1000).to_i
    canned_response = create_response( {:title => "Recent Canned_Responses Hepler #{now}",:content_html => Faker::Lorem.paragraph, 
      :visibility => Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:group_agents],
      :attachments => { :resource => fixture_file_upload('files/image.gif', 'image/gif'), 
        :description => Faker::Lorem.characters(10)
      }
    })
    shared_attachment = canned_response.shared_attachments.first
    note = @test_ticket.notes.build(:body => Faker::Lorem.characters(10), 
                              :private => false, 
                              :account_id => @test_ticket.account_id,
                              :user_id => @agent.id)
    note.shared_attachments.build(:account_id => canned_response.account_id, 
                                  :attachment => shared_attachment.attachment)
    note.save
    user = add_new_user(@account)
    log_in(user)
    delete :unlink_shared, :note_id => note.id, :id => note.shared_attachments.first.attachment.id
    note.reload
    note.shared_attachments.first.should be_an_instance_of(Helpdesk::SharedAttachment)
  end

  it "should not allow an unauthorized user to delete an attachment" do
    user = add_new_user(@account)
    log_in(user)
    delete :destroy, :id => @test_ticket.attachments.first.id
    @test_ticket.reload
    @test_ticket.attachments.first.should be_an_instance_of(Helpdesk::Attachment)
  end
end