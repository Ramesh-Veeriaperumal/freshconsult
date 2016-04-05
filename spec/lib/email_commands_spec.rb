require 'spec_helper'
require "#{Rails.root}/lib/import/custom_field.rb"

RSpec.configure do |c|
  c.include EmailHelper
  c.include MailgunHelper
  c.include Import::CustomField
end

RSpec.describe EmailCommands do
	before(:all) do
		@agent = add_agent_to_account(@account, {:name => Faker::Name.name, :email => Faker::Internet.email, :active => true})
		@user  = create_dummy_customer
		clear_email_config
		@comp = create_company
		restore_default_feature("reply_to_based_tickets")
		f = { :field_type=>"custom_text", :label=>"abcd", :label_in_portal=>"abcd", :description=>"", :position=>4, :active=>true, :required=>false, :required_for_closure=>false, :visible_in_portal=>true, :editable_in_portal=>true, :required_in_portal=>false, :field_options=>nil, :type=>"text" }
		@invalid_fields ||= []
		create_field(f, @account)
		@account.reload

		#create an email ticket
		@ticket = @account.tickets.last
		if @ticket.nil?
			email = new_email({:email_config => @account.primary_email_config.to_email, :reply => @user.email})
			Helpdesk::ProcessEmail.new(email).perform
			@ticket = @account.tickets.last
		end
	end

	after(:each) do
		@account.reload
		@account.make_current
	end

	before(:each) do
		@account.reload		
		@account.make_current
		@ticket.reload
	end

	describe "Email commands(sendgrid)" do

		it "change priority" do
			email = new_email({:email_config => @account.primary_email_config.to_email, :reply => @agent.user.email})
			email[:subject] = "[##{@ticket.display_id}] #{email[:subject]}"
			email[:from] = @agent.user.email
			email[:text] = %(\n#{@account.email_cmds_delimeter} "priority":"medium" #{@account.email_cmds_delimeter} \n)+email[:text]
			email[:html] = %(\n#{@account.email_cmds_delimeter} "priority":"medium" #{@account.email_cmds_delimeter} \n)+email[:html]
			Helpdesk::ProcessEmail.new(email).perform
			@ticket.reload
			@ticket.priority.should eql 2
		end

		it "change status" do
			@ticket.update_column(:status, 2)
			email = new_email({:email_config => @account.primary_email_config.to_email, :reply => @agent.user.email})
			email[:from] = @agent.user.email
			email[:text] = %(\n#{@account.email_cmds_delimeter} "status":"Closed" #{@account.email_cmds_delimeter} \n)+email[:text]
			email[:html] = %(\n#{@account.email_cmds_delimeter} "status":"Closed" #{@account.email_cmds_delimeter} \n)+email[:html]
			email[:subject] = "[##{@ticket.display_id}] #{email[:subject]}"
			Helpdesk::ProcessEmail.new(email).perform
			@ticket.reload
			@ticket.status.should eql 5
		end

		it "change agent" do
			@ticket.update_column(:responder_id, nil)
			email = new_email({:email_config => @account.primary_email_config.to_email, :reply => @agent.user.email})
			email[:from] = @agent.user.email
			email[:text] = %(\n#{@account.email_cmds_delimeter} "agent":"#{@account.agents.last.user.name}" #{@account.email_cmds_delimeter} \n)+email[:text]
			email[:html] = %(\n#{@account.email_cmds_delimeter} "agent":"#{@account.agents.last.user.name}" #{@account.email_cmds_delimeter} \n)+email[:html]
			email[:subject] = "[##{@ticket.display_id}] #{email[:subject]}"
			Helpdesk::ProcessEmail.new(email).perform
			@ticket.reload
			@ticket.responder.id.should eql @account.agents.last.user.id
		end

		it "change agent assign to me" do
			@ticket.update_column(:responder_id, nil)
			email = new_email({:email_config => @account.primary_email_config.to_email, :reply => @agent.user.email})
			email[:from] = @agent.user.email
			email[:text] = %(\n#{@account.email_cmds_delimeter} "agent":"me" #{@account.email_cmds_delimeter} \n)+email[:text]
			email[:html] = %(\n#{@account.email_cmds_delimeter} "agent":"me" #{@account.email_cmds_delimeter} \n)+email[:html]
			email[:subject] = "[##{@ticket.display_id}] #{email[:subject]}"
			Helpdesk::ProcessEmail.new(email).perform
			@ticket.reload
			@ticket.responder.id.should eql @agent.user.id
		end

		it "change agent to email" do
			@ticket.update_column(:responder_id, nil)
			email = new_email({:email_config => @account.primary_email_config.to_email, :reply => @agent.user.email})
			email[:from] = @agent.user.email
			email[:text] = %(\n#{@account.email_cmds_delimeter} "agent":"#{@account.agents.last.user.email}" #{@account.email_cmds_delimeter} \n)+email[:text]
			email[:html] = %(\n#{@account.email_cmds_delimeter} "agent":"#{@account.agents.last.user.email}" #{@account.email_cmds_delimeter} \n)+email[:html]
			email[:subject] = "[##{@ticket.display_id}] #{email[:subject]}"
			Helpdesk::ProcessEmail.new(email).perform
			@ticket.reload
			@ticket.responder.id.should eql @account.agents.last.user.id
		end

		it "change type" do
			email = new_email({:email_config => @account.primary_email_config.to_email, :reply => @agent.user.email})
			email[:from] = @agent.user.email
			email[:text] = %(\n#{@account.email_cmds_delimeter} "type":"Incident" #{@account.email_cmds_delimeter} \n)+email[:text]
			email[:html] = %(\n#{@account.email_cmds_delimeter} "type":"Incident" #{@account.email_cmds_delimeter} \n)+email[:html]
			email[:subject] = "[##{@ticket.display_id}] #{email[:subject]}"
			Helpdesk::ProcessEmail.new(email).perform
			@ticket.reload
			@ticket.ticket_type.should eql "Incident"
		end

		it "change group" do
			@ticket.update_column(:group_id, nil)
			email = new_email({:email_config => @account.primary_email_config.to_email, :reply => @agent.user.email})
			email[:from] = @agent.user.email
			email[:text] = %(\n#{@account.email_cmds_delimeter} "group":"Sales" #{@account.email_cmds_delimeter} \n)+email[:text]
			email[:html] = %(\n#{@account.email_cmds_delimeter} "group":"Sales" #{@account.email_cmds_delimeter} \n)+email[:html]
			email[:subject] = "[##{@ticket.display_id}] #{email[:subject]}"
			Helpdesk::ProcessEmail.new(email).perform
			@ticket.reload
			@ticket.group.name.should eql "Sales"
		end

		it "change source" do
			@ticket.update_column(:source, 1)
			email = new_email({:email_config => @account.primary_email_config.to_email, :reply => @agent.user.email})
			email[:from] = @agent.user.email
			email[:text] = %(\n#{@account.email_cmds_delimeter} "source":"chat" #{@account.email_cmds_delimeter} \n)+email[:text]
			email[:html] = %(\n#{@account.email_cmds_delimeter} "source":"chat" #{@account.email_cmds_delimeter} \n)+email[:html]
			email[:subject] = "[##{@ticket.display_id}] #{email[:subject]}"
			Helpdesk::ProcessEmail.new(email).perform
			@ticket.reload
			@ticket.source.should eql 7
		end

		it "change custom_field" do
			email = new_email({:email_config => @account.primary_email_config.to_email, :reply => @agent.user.email})
			email[:from] = @agent.user.email
			email[:text] = %(\n#{@account.email_cmds_delimeter} "abcd":"1234" #{@account.email_cmds_delimeter} \n)+email[:text]
			email[:html] = %(\n#{@account.email_cmds_delimeter} "abcd":"1234" #{@account.email_cmds_delimeter} \n)+email[:html]
			email[:subject] = "[##{@ticket.display_id}] #{email[:subject]}"
			Helpdesk::ProcessEmail.new(email).perform

			@ticket = @account.tickets.find(@ticket.id) #reload doesnt reload custom_fiels[]
			@ticket.custom_field["abcd_1"].should eql "1234"
		end

		it "private note" do
			ticket_size = @account.tickets.count
			note_size   = @account.notes.count
			email = new_email({:email_config => @account.primary_email_config.to_email})
			Helpdesk::ProcessEmail.new(email).perform
			ticket = @account.tickets.last
			another = new_email({:email_config => @account.primary_email_config.to_email, :reply => @agent.user.email})
			another[:subject] = another[:subject]+" [##{ticket.display_id}]"
			another[:from] = @agent.user.email
			another[:text] = %(\n#{@account.email_cmds_delimeter} "action":"note" #{@account.email_cmds_delimeter} \n)+email[:text]
			another[:html] = %(\n#{@account.email_cmds_delimeter} "action":"note" #{@account.email_cmds_delimeter} \n)+email[:html]
			Helpdesk::ProcessEmail.new(another).perform
			ticket = @account.tickets.last
			ticket_incremented?(ticket_size)
			@account.notes.size.should eql note_size+1
			ticket.notes.last.private?.should eql true
		end

		it "change multiple" do
			ticket_size = @account.tickets.count
			note_size   = @account.notes.count
			email = new_email({:email_config => @account.primary_email_config.to_email})
			Helpdesk::ProcessEmail.new(email).perform
			ticket = @account.tickets.last
			ticket_incremented?(ticket_size)
			
			ticket = @account.tickets.last
			another = new_email({:email_config => @account.primary_email_config.to_email, :reply => @agent.user.email})
			another[:subject] = another[:subject]+" [##{ticket.display_id}]"
			another[:from] = @agent.user.email
			another[:text] = %(\n#{@account.email_cmds_delimeter} "source":"chat", "priority":"medium", "status":"closed", "agent":"me", "abcd":"abcd" #{@account.email_cmds_delimeter} \n) + email[:text]
			another[:html] = %(\n#{@account.email_cmds_delimeter} "source":"chat", "priority":"medium", "status":"closed", "agent":"me", "abcd":"abcd" #{@account.email_cmds_delimeter} \n) + email[:html]
			Helpdesk::ProcessEmail.new(another).perform		

			ticket = @account.tickets.find(ticket.id) #reload doesnt reload custom_fiels[]
			ticket.source.should eql 7
			ticket.priority.should eql 2
			ticket.status.should eql 5
			ticket.responder.id.should eql @agent.user.id
			ticket.custom_field["abcd_1"].should eql "abcd"
		end

	end

	describe "Email commands(mailgun)" do
		it "change priority" do
			@ticket.update_column(:priority, 1)
			email = new_mailgun_email({:email_config => @account.primary_email_config.to_email, :reply => @agent.user.email})
			email[:from] = @agent.user.email
			email["stripped-text"] = %(\n#{@account.email_cmds_delimeter} "priority":"medium" #{@account.email_cmds_delimeter} \n)+email["stripped-text"]
			email["stripped-html"] = %(\n#{@account.email_cmds_delimeter} "priority":"medium" #{@account.email_cmds_delimeter} \n)+email["stripped-html"]
			email["body-plain"]    = email["stripped-text"]
			email["body-html"]     = email["stripped-html"]
			email["subject"]       = "[##{@ticket.display_id}] #{email['subject']}"
			Helpdesk::Email::Process.new(email).perform
			@ticket.reload
			@ticket.priority.should eql 2
		end

		it "change status" do
			@ticket.update_column(:status, 2)
			email = new_mailgun_email({:email_config => @account.primary_email_config.to_email, :reply => @agent.user.email})
			email[:from] = @agent.user.email
			email["stripped-text"] = %(\n#{@account.email_cmds_delimeter} "status":"Closed" #{@account.email_cmds_delimeter} \n) + email["stripped-text"]
			email["stripped-html"] = %(\n#{@account.email_cmds_delimeter} "status":"Closed" #{@account.email_cmds_delimeter} \n) + email["stripped-html"]
			email['subject']       = "[##{@ticket.display_id}] #{email['subject']}"
			email["body-plain"]    = email["stripped-text"]
			email["body-html"]     = email["stripped-html"]
			Helpdesk::Email::Process.new(email).perform
			@ticket.reload
			@ticket.status.should eql 5
		end		

		it "change agent" do
			@ticket.update_column(:responder_id, nil)
			email = new_mailgun_email({:email_config => @account.primary_email_config.to_email, :reply => @agent.user.email})
			email[:from] = @agent.user.email
			email["stripped-text"] = %(\n#{@account.email_cmds_delimeter} "agent":"#{@account.agents.last.user.name}" #{@account.email_cmds_delimeter} \n)+email["stripped-text"]
			email["stripped-html"] = %(\n#{@account.email_cmds_delimeter} "agent":"#{@account.agents.last.user.name}" #{@account.email_cmds_delimeter} \n)+email["stripped-html"]
			email['subject']       = "[##{@ticket.display_id}] #{email['subject']}"
			email["body-plain"]    = email["stripped-text"]
			email["body-html"]     = email["stripped-html"]
			Helpdesk::Email::Process.new(email).perform
			@ticket.reload
			@ticket.responder.id.should eql @account.agents.last.user.id
		end

		it "change agent to me" do
			@ticket.update_column(:responder_id, nil)
			email = new_mailgun_email({:email_config => @account.primary_email_config.to_email, :reply => @agent.user.email})
			email[:from] = @agent.user.email
			email["stripped-text"] = %(\n#{@account.email_cmds_delimeter} "agent":"me" #{@account.email_cmds_delimeter} \n)+email["stripped-text"]
			email["stripped-html"] = %(\n#{@account.email_cmds_delimeter} "agent":"me" #{@account.email_cmds_delimeter} \n)+email["stripped-html"]
			email['subject']       = "[##{@ticket.display_id}] #{email['subject']}"
			email["body-plain"]    = email["stripped-text"]
			email["body-html"]     = email["stripped-html"]
			Helpdesk::Email::Process.new(email).perform
			@ticket.reload
			@ticket.responder.id.should eql @agent.user.id
		end

		it "change agent to email" do
			@ticket.update_column(:responder_id, nil)
			email = new_mailgun_email({:email_config => @account.primary_email_config.to_email, :reply => @agent.user.email})
			email[:from] = @agent.user.email
			email["stripped-text"] = %(\n#{@account.email_cmds_delimeter} "agent":"#{@account.agents.last.user.email}" #{@account.email_cmds_delimeter} \n)+email["stripped-text"]
			email["stripped-html"] = %(\n#{@account.email_cmds_delimeter} "agent":"#{@account.agents.last.user.email}" #{@account.email_cmds_delimeter} \n)+email["stripped-html"]
			email['subject']       = "[##{@ticket.display_id}] #{email['subject']}"
			email["body-plain"]    = email["stripped-text"]
			email["body-html"]     = email["stripped-html"]
			Helpdesk::Email::Process.new(email).perform
			@ticket.reload
			@ticket.responder.id.should eql @account.agents.last.user.id
		end		

		it "change type" do
			@ticket.update_column(:ticket_type, nil)
			email = new_mailgun_email({:email_config => @account.primary_email_config.to_email, :reply => @agent.user.email})
			email[:from] = @agent.user.email
			email["stripped-text"] = %(\n#{@account.email_cmds_delimeter} "type":"Incident" #{@account.email_cmds_delimeter} \n)+email["stripped-text"]
			email["stripped-html"] = %(\n#{@account.email_cmds_delimeter} "type":"Incident" #{@account.email_cmds_delimeter} \n)+email["stripped-html"]
			email['subject']       = "[##{@ticket.display_id}] #{email['subject']}"
			email["body-plain"]    = email["stripped-text"]
			email["body-html"]     = email["stripped-html"]
			Helpdesk::Email::Process.new(email).perform
			@ticket.reload
			@ticket.ticket_type.should eql "Incident"
		end		

		it "change group" do
			@ticket.update_column(:group_id, nil)
			email = new_mailgun_email({:email_config => @account.primary_email_config.to_email, :reply => @agent.user.email})
			email[:from] = @agent.user.email
			email["stripped-text"] = %(\n#{@account.email_cmds_delimeter} "group":"Sales" #{@account.email_cmds_delimeter} \n)+email["stripped-text"]
			email["stripped-html"] = %(\n#{@account.email_cmds_delimeter} "group":"Sales" #{@account.email_cmds_delimeter} \n)+email["stripped-html"]
			email['subject']       = "[##{@ticket.display_id}] #{email['subject']}"
			email["body-plain"]    = email["stripped-text"]
			email["body-html"]     = email["stripped-html"]
			Helpdesk::Email::Process.new(email).perform
			@ticket.reload
			@ticket.group.name.should eql "Sales"
		end		

		it "change source" do
			@ticket.update_column(:source, 1)
			email = new_mailgun_email({:email_config => @account.primary_email_config.to_email, :reply => @agent.user.email})
			email[:from] = @agent.user.email
			email["stripped-text"] = %(\n#{@account.email_cmds_delimeter} "source":"chat" #{@account.email_cmds_delimeter} \n)+email["stripped-text"]
			email["stripped-html"] = %(\n#{@account.email_cmds_delimeter} "source":"chat" #{@account.email_cmds_delimeter} \n)+email["stripped-html"]
			email['subject']       = "[##{@ticket.display_id}] #{email['subject']}"
			email["body-plain"]    = email["stripped-text"]
			email["body-html"]     = email["stripped-html"]
			Helpdesk::Email::Process.new(email).perform
			@ticket.reload
			@ticket.source.should eql 7
		end		

		it "change custom_field" do
			email = new_mailgun_email({:email_config => @account.primary_email_config.to_email, :reply => @agent.user.email})
			email[:from] = @agent.user.email
			email["stripped-text"] = %(\n#{@account.email_cmds_delimeter} "abcd":"xyz" #{@account.email_cmds_delimeter} \n)+email["stripped-text"]
			email["stripped-html"] = %(\n#{@account.email_cmds_delimeter} "abcd":"xyz" #{@account.email_cmds_delimeter} \n)+email["stripped-html"]
			email['subject']       = "[##{@ticket.display_id}] #{email['subject']}"
			email["body-plain"]    = email["stripped-text"]
			email["body-html"]     = email["stripped-html"]
			Helpdesk::Email::Process.new(email).perform

			@ticket = @account.tickets.find(@ticket.id) #reload doesnt reload custom_fiels[]
			@ticket.custom_field["abcd_1"].should eql "xyz"
		end

		it "private note" do
			ticket_size = @account.tickets.count
			note_size   = @account.notes.count
			email = new_mailgun_email({:email_config => @account.primary_email_config.to_email})
			Helpdesk::Email::Process.new(email).perform
			ticket_incremented?(ticket_size)
			ticket = @account.tickets.last
			
			another = new_mailgun_email({:email_config => @account.primary_email_config.to_email, :reply => @agent.user.email})
			another["subject"] = another["subject"]+" [##{ticket.display_id}]"
			another[:from] = @agent.user.email
			another["stripped-text"] = %(\n#{@account.email_cmds_delimeter} "action":"note" #{@account.email_cmds_delimeter} \n)+another["stripped-text"]
			another["stripped-html"] = %(\n#{@account.email_cmds_delimeter} "action":"note" #{@account.email_cmds_delimeter} \n)+another["stripped-html"]
			another["body-plain"]    = email["stripped-text"]
			another["body-html"]     = email["stripped-html"]
			Helpdesk::Email::Process.new(another).perform
			ticket.reload
			@account.notes.size.should eql note_size+1
			ticket.notes.last.private?.should eql true
		end

		it "change multiple" do
			ticket_size = @account.tickets.count
			email = new_mailgun_email({:email_config => @account.primary_email_config.to_email, :reply => @agent.user.email})
			email[:from] = @agent.user.email
			email["stripped-text"] = %(\n#{@account.email_cmds_delimeter} "source":"chat", "priority":"medium", "status":"closed", "agent":"me", "abcd":"1234567" #{@account.email_cmds_delimeter} \n)+email["stripped-text"]
			email["stripped-html"] = %(\n#{@account.email_cmds_delimeter} "source":"chat", "priority":"medium", "status":"closed", "agent":"me", "abcd":"1234567" #{@account.email_cmds_delimeter} \n)+email["stripped-html"]
			email["body-plain"]    = email["stripped-text"]
			email["body-html"]     = email["stripped-html"]
			email["subject"]       = " [##{@ticket.display_id}] #{email['subject']}"
			Helpdesk::Email::Process.new(email).perform
			
			@ticket = @account.tickets.find(@ticket.id) #reload doesnt reload custom_fiels[]
			@ticket.source.should eql 7
			@ticket.priority.should eql 2
			@ticket.status.should eql 5
			@ticket.responder.id.should eql @agent.user.id
			@ticket.custom_field["abcd_1"].should eql "1234567"
		end
	end
end