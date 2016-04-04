require 'spec_helper'

describe Support::NotesController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @user = FactoryGirl.build(:user)
    @user.save
  end

  before(:each) do
    log_in(@user)
  end

  it "should re-open a closed ticket after a customer reply" do
    test_ticket = create_ticket({:requester_id => @user.id, :status => 5 }, create_group(@account, {:name => "Support"}))
    Resque.inline = true
    post :create, :helpdesk_note => { :note_body_attributes => {:body_html => "<p>New note</p>"} },
                  :ticket_id => test_ticket.display_id
    Resque.inline = false
    reopened_ticket = @account.tickets.find(test_ticket.id)
    reopened_ticket.status.should be_eql(2)
    reopened_ticket.notes.last.full_text_html.should be_eql("<div>New note</div>")
  end

  it "client manager can create note if requester company and client manager company are same" do
    new_company = FactoryGirl.build(:customer, :name => Faker::Name.name)
    new_company.save

    new_contacts = []
    2.times do |index|
      new_contacts.push(FactoryGirl.build(:user, :customer_id => new_company.id,
                                      :name => Faker::Name.name,
                                      :email => Faker::Internet.email,
                                      :privileges => index.eql?(0) ? index : Role.privileges_mask([:client_manager]),
                                      :user_role => 3,
                                      :crypted_password => nil,
                                      :password_salt => nil,
                                      :phone => ""))
      new_contacts[index].save
    end

    log_in(new_contacts[0])
    
    test_ticket = create_ticket({ :requester_id => new_contacts[0].id, :status => 2 })
    test_ticket.cc_email = nil
    test_ticket.save(:validate => false)

    log_in(new_contacts[1])
    Resque.inline = true
    post :create, :helpdesk_note => { :note_body_attributes => {:body_html => "<p>New note by #{new_contacts[0].name} from #{new_company.name} company </p>"} },
                  :ticket_id => test_ticket.display_id
    Resque.inline = false
    client_manager_note = @account.tickets.find(test_ticket.id).notes.last
    client_manager_note.user.company.id.should be_eql(new_company.id)
    client_manager_note.user_id.should be_eql(new_contacts[1].id)
    flash[:notice].should eql "The note has been added to your ticket."
  end

  it "any user with manage tickets permission can create note with attachment to any ticket" do
    new_company = FactoryGirl.build(:customer, :name => Faker::Name.name)
    new_company.save

    new_contact = FactoryGirl.build(:user, :customer_id => new_company.id,
                                 :name => Faker::Name.name,
                                 :email => Faker::Internet.email,
                                 :user_role => 3,
                                 :crypted_password => nil,
                                 :password_salt => nil,
                                 :phone => "")
    new_contact.save

    new_agent = add_agent(@account, { :name => "Agent - #{Faker::Name.name}",
                                  :email => Faker::Internet.email,
                                  :active => 1,
                                  :agent => 1,
                                  :role => 1,
                                  :agent => 1,
                                  :ticket_permission => 1,
                                  :role_ids => ["#{@account.roles.find_by_name("Agent").id}"],
                                  :privileges => @account.roles.find_by_name("Agent").privileges })

    log_in(new_contact)
    test_ticket = create_ticket({ :requester_id => new_contact.id, :status => 2 })

    log_in(new_agent)
    Resque.inline = true
    post :create, :helpdesk_note => { :note_body_attributes => {:body_html => "<p>New note by #{new_agent.name} </p>"},
                                      :attachments =>[{ :resource => fixture_file_upload('files/image4kb.png','image/png'),
                                                        :description => Faker::Lorem.characters(10) 
                                                      }]
                                    },
                  :ticket_id => test_ticket.display_id
    Resque.inline = false
    client_manager_note = @account.tickets.find(test_ticket.id).notes.last
    client_manager_note.user_id.should be_eql(new_agent.id)
    client_manager_note.notable.requester_id.should be_eql(new_contact.id)
    flash[:notice].should eql "The note has been added to your ticket."
  end
end
