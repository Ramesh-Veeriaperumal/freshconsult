require 'spec_helper'
#include ActionController::TestProcess

describe Helpdesk::AttachmentsController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    file = fixture_file_upload('/files/attachment.txt', 'text/plain', :binary)
    @test_ticket = create_ticket({ 
      :status => 2, 
      :attachments => { 
        :resource => file,
        :description => Faker::Lorem.characters(10) 
      } 
    })    
  end

  before(:each) do
    log_in(@agent)
    stub_s3_writes
  end

  it "should show an attachment" do
    get :show, :id => @test_ticket.attachments.first.id
    response.should be_redirect
    response.body.should =~ /#{S3_CONFIG[:access_key_id]}/
    response.body.should =~ /attachment.txt/
  end

  it "should show an attachment to a customer" do
    user = add_new_user(@account)
    ticket = create_ticket({ :status => 2, 
                             :requester_id => user.id,
                             :attachments => { :resource => fixture_file_upload('/files/attachment.txt', 'text/plain', :binary),
                                               :description => Faker::Lorem.characters(10) 
                                              } })
    log_in(user)
    get :show, :id => ticket.attachments.first.id
    response.should be_redirect
    response.body.should =~ /#{S3_CONFIG[:access_key_id]}/
    response.body.should =~ /attachment.txt/
  end

  it "should show a solution article's attachment" do
    category = create_category
    folder = create_folder(:category_id => category.id)
    article = create_article(:folder_id => folder.id)
    attachment = article.attachments.build(:content => fixture_file_upload('/files/attachment.txt', 'text/plain', :binary), 
                                            :description => Faker::Name.first_name, 
                                            :account_id => article.account_id)
    attachment.save
    get :show, :id => attachment.id
    response.should be_redirect
    response.body.should =~ /#{S3_CONFIG[:access_key_id]}/
    response.body.should =~ /attachment.txt/
  end

  it "should show an account's logo" do
    logo = @account.build_logo(:content => fixture_file_upload('files/image.gif', 'image/gif', :binary), 
                               :description => "logo", 
                               :account_id => @account.id)
    logo.save
    get :show, :id => logo.id
    response.should be_redirect
    response.body.should =~ /#{S3_CONFIG[:access_key_id]}/
    response.body.should =~ /image.gif/
  end

  it "should show a forum post's attachment" do
    post = quick_create_post
    attachment = post.attachments.create(:content => fixture_file_upload('/files/attachment.txt', 'text/plain', :binary), 
                                        :description => Faker::Lorem.characters(10), 
                                        :account_id => @account.id)
    get :show, :id => attachment.id
    response.should be_redirect
    response.body.should =~ /#{S3_CONFIG[:access_key_id]}/
    response.body.should =~ /attachment.txt/
  end

  it "should show a freshfone call's attachment" do
    create_test_freshfone_account
    call = create_freshfone_call
    attachment = call.create_recording_audio(:content => fixture_file_upload('/files/attachment.txt', 'text/plain', :binary), 
                                            :description => Faker::Lorem.characters(10), 
                                            :account_id => @account.id)
    user = add_new_user(@account)
    ticket = create_ticket(:requester_id => user.id)
    call.update_attributes(:customer_id => user.id, :notable_id => ticket.id, :notable_type => 'Helpdesk::Ticket')
    log_in(user)
    get :show, :id => attachment.id
    response.should be_redirect
    response.body.should =~ /#{S3_CONFIG[:access_key_id]}/
    response.body.should =~ /attachment.txt/
  end

  it "should show a data export's attachment" do
    data_export = FactoryGirl.build(:data_export, :account_id => @account.id, :user_id => @agent.id)
    data_export.create_attachment(:content => fixture_file_upload('/files/attachment.txt', 'text/plain', :binary), 
                                  :description => Faker::Lorem.characters(10), 
                                  :account_id => @account.id)
    data_export.save
    get :show, :id => data_export.attachment.id
    response.should be_redirect
    response.body.should =~ /#{S3_CONFIG[:access_key_id]}/
    response.body.should =~ /attachment.txt/
  end


  it "should render the content of an attached file" do
    unstub_s3_writes
    ticket = create_ticket({ :status => 2, 
                             :attachments => { :resource => fixture_file_upload('/files/attachment.txt', 'text/plain', :binary),
                                               :description => Faker::Lorem.characters(10) 
                                              } })
    get :text_content, :id => ticket.attachments.first.id
    response.body.force_encoding("UTF-8").should be_eql(File.read("#{Rails.root}/spec/fixtures/files/attachment.txt"))
  end

  
  # Delete actions
  it "should delete a shared attachment" do
    now = (Time.now.to_f*1000).to_i
    canned_response = create_response( {:title => "Recent Canned_Responses Hepler #{now}",:content_html => Faker::Lorem.paragraph,
      :visibility => Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:group_agents],
      :attachments => { :resource => fixture_file_upload('files/attachment.txt', 'text/plain', :binary), 
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
    delete :unlink_shared, :note_id => note.id, :id => note.shared_attachments.first.attachment.id
    note.reload
    note.shared_attachments.first.should be_nil
  end

  it "should delete a ticket's attachment" do
    delete :destroy, :id => @test_ticket.attachments.first.id
    @test_ticket.reload
    @test_ticket.attachments.first.should be_nil
  end

  it "should delete a solution article's attachment" do
    category   = create_category
    folder     = create_folder(:category_id => category.id)
    article    = create_article(:folder_id => folder.id)
    attachment = article.attachments.build(:content => fixture_file_upload('/files/attachment.txt', 'text/plain', :binary), 
                                            :description => Faker::Name.first_name, 
                                            :account_id => article.account_id)
    attachment.save    

    delete :destroy, :id => article.attachments.first.id
    article.reload
    article.attachments.first.should be_nil
  end

  it "should delete an account's logo" do
    logo = @account.build_logo(:content => fixture_file_upload('files/image.gif', 'image/gif', :binary), 
                               :description => "logo", 
                               :account_id => @account.id)
    logo.save
    delete :destroy, :id => logo.id
    @account.reload
    @account.logo.should be_nil
  end

  it "should delete a forum post's attachment" do
    post = quick_create_post
    attachment = post.attachments.build(:content => fixture_file_upload('/files/attachment.txt', 'text/plain', :binary), 
                                        :description => Faker::Lorem.characters(10), 
                                        :account_id => @account.id)
    attachment.save
    delete :destroy, :id => attachment.id
    post.reload
    post.attachments.first.should be_nil
  end

  it "should delete a customer's avatar" do
    user = add_new_user(@account)
    attachment = user.build_avatar(:content => fixture_file_upload('files/image.gif', 'image/gif'), 
                                   :description => Faker::Lorem.characters(10), 
                                   :account_id => @account.id)
    attachment.save
    delete :destroy, :id => attachment.id
    user.reload
    user.avatar.should be_nil
  end
end
