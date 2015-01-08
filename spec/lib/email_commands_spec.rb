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
		clear_email_config
		@comp = create_company
		restore_default_feature("reply_to_based_tickets")
		f = { :field_type=>"custom_text", :label=>"abcd", :label_in_portal=>"abcd", :description=>"", :position=>4, :active=>true, :required=>false, :required_for_closure=>false, :visible_in_portal=>true, :editable_in_portal=>true, :required_in_portal=>false, :field_options=>nil, :type=>"text" }
		@invalid_fields ||= []
		create_field(f, @account)
		@account.reload
	end

	after(:each) do
		@account.reload
		@account.make_current
		@ticket_size = @account.tickets.size
		@note_size = @account.notes.size
	end

	before(:each) do
		@account.reload		
		@account.make_current
		@ticket_size = @account.tickets.size
		@note_size = @account.notes.size
	end

	describe "Email commands" do

		it "change priority with sendgrid" do
			email = new_email({:email_config => @account.primary_email_config.to_email, :reply => @agent.user.email})
			email[:from] = @agent.user.email
			email[:text] = %(\n#{@account.email_cmds_delimeter} "priority":"medium" #{@account.email_cmds_delimeter} \n)+email[:text]
			email[:html] = %(\n#{@account.email_cmds_delimeter} "priority":"medium" #{@account.email_cmds_delimeter} \n)+email[:html]
			Helpdesk::ProcessEmail.new(email).perform
			ticket = @account.tickets.last
			ticket_incremented?(@ticket_size)
			ticket.priority.should eql 2
		end

		it "change priority with mailgun" do
			email = new_mailgun_email({:email_config => @account.primary_email_config.to_email, :reply => @agent.user.email})
			email[:from] = @agent.user.email
			email["body-plain"] = %(\n#{@account.email_cmds_delimeter} "priority":"medium" #{@account.email_cmds_delimeter} \n)+email["body-plain"]
			email["body-html"] = %(\n#{@account.email_cmds_delimeter} "priority":"medium" #{@account.email_cmds_delimeter} \n)+email["body-html"]
			Helpdesk::Email::Process.new(email).perform
			ticket = @account.tickets.last
			ticket_incremented?(@ticket_size)
			ticket.priority.should eql 2
		end

		it "change status with sendgrid" do
			email = new_email({:email_config => @account.primary_email_config.to_email, :reply => @agent.user.email})
			email[:from] = @agent.user.email
			email[:text] = %(\n#{@account.email_cmds_delimeter} "status":"closed" #{@account.email_cmds_delimeter} \n)+email[:text]
			email[:html] = %(\n#{@account.email_cmds_delimeter} "status":"closed" #{@account.email_cmds_delimeter} \n)+email[:html]
			Helpdesk::ProcessEmail.new(email).perform
			ticket = @account.tickets.last
			ticket_incremented?(@ticket_size)
			ticket.status.should eql 5
		end

		it "change status with mailgun" do
			email = new_mailgun_email({:email_config => @account.primary_email_config.to_email, :reply => @agent.user.email})
			email[:from] = @agent.user.email
			email["body-plain"] = %(\n#{@account.email_cmds_delimeter} "status":"closed" #{@account.email_cmds_delimeter} \n)+email["body-plain"]
			email["body-html"] = %(\n#{@account.email_cmds_delimeter} "status":"closed" #{@account.email_cmds_delimeter} \n)+email["body-html"]
			Helpdesk::Email::Process.new(email).perform
			ticket = @account.tickets.last
			ticket_incremented?(@ticket_size)
			ticket.status.should eql 5
		end

		it "change agent with sendgrid" do
			email = new_email({:email_config => @account.primary_email_config.to_email, :reply => @agent.user.email})
			email[:from] = @agent.user.email
			email[:text] = %(\n#{@account.email_cmds_delimeter} "agent":"#{@account.agents.last.user.name}" #{@account.email_cmds_delimeter} \n)+email[:text]
			email[:html] = %(\n#{@account.email_cmds_delimeter} "agent":"#{@account.agents.last.user.name}" #{@account.email_cmds_delimeter} \n)+email[:html]
			Helpdesk::ProcessEmail.new(email).perform
			ticket = @account.tickets.last
			ticket_incremented?(@ticket_size)
			ticket.responder.id.should eql @account.agents.last.user.id
		end

		it "change agent with sendgrid assign to me" do
			email = new_email({:email_config => @account.primary_email_config.to_email, :reply => @agent.user.email})
			email[:from] = @agent.user.email
			email[:text] = %(\n#{@account.email_cmds_delimeter} "agent":"me" #{@account.email_cmds_delimeter} \n)+email[:text]
			email[:html] = %(\n#{@account.email_cmds_delimeter} "agent":"me" #{@account.email_cmds_delimeter} \n)+email[:html]
			Helpdesk::ProcessEmail.new(email).perform
			ticket = @account.tickets.last
			ticket_incremented?(@ticket_size)
			ticket.responder.id.should eql @agent.user.id
		end

		it "change agent with sendgrid to email" do
			email = new_email({:email_config => @account.primary_email_config.to_email, :reply => @agent.user.email})
			email[:from] = @agent.user.email
			email[:text] = %(\n#{@account.email_cmds_delimeter} "agent":"#{@account.agents.last.user.email}" #{@account.email_cmds_delimeter} \n)+email[:text]
			email[:html] = %(\n#{@account.email_cmds_delimeter} "agent":"#{@account.agents.last.user.email}" #{@account.email_cmds_delimeter} \n)+email[:html]
			Helpdesk::ProcessEmail.new(email).perform
			ticket = @account.tickets.last
			ticket_incremented?(@ticket_size)
			ticket.responder.id.should eql @account.agents.last.user.id
		end

		it "change agent with mailgun" do
			email = new_mailgun_email({:email_config => @account.primary_email_config.to_email, :reply => @agent.user.email})
			email[:from] = @agent.user.email
			email["body-plain"] = %(\n#{@account.email_cmds_delimeter} "agent":"#{@account.agents.last.user.name}" #{@account.email_cmds_delimeter} \n)+email["body-plain"]
			email["body-html"] = %(\n#{@account.email_cmds_delimeter} "agent":"#{@account.agents.last.user.name}" #{@account.email_cmds_delimeter} \n)+email["body-html"]
			Helpdesk::Email::Process.new(email).perform
			ticket = @account.tickets.last
			ticket_incremented?(@ticket_size)
			ticket.responder.id.should eql @account.agents.last.user.id
		end

		it "change agent with mailgun to me" do
			email = new_mailgun_email({:email_config => @account.primary_email_config.to_email, :reply => @agent.user.email})
			email[:from] = @agent.user.email
			email["body-plain"] = %(\n#{@account.email_cmds_delimeter} "agent":"me" #{@account.email_cmds_delimeter} \n)+email["body-plain"]
			email["body-html"] = %(\n#{@account.email_cmds_delimeter} "agent":"me" #{@account.email_cmds_delimeter} \n)+email["body-html"]
			Helpdesk::Email::Process.new(email).perform
			ticket = @account.tickets.last
			ticket_incremented?(@ticket_size)
			ticket.responder.id.should eql @agent.user.id
		end

		it "change agent with mailgun to email" do
			email = new_mailgun_email({:email_config => @account.primary_email_config.to_email, :reply => @agent.user.email})
			email[:from] = @agent.user.email
			email["body-plain"] = %(\n#{@account.email_cmds_delimeter} "agent":"#{@account.agents.last.user.email}" #{@account.email_cmds_delimeter} \n)+email["body-plain"]
			email["body-html"] = %(\n#{@account.email_cmds_delimeter} "agent":"#{@account.agents.last.user.email}" #{@account.email_cmds_delimeter} \n)+email["body-html"]
			Helpdesk::Email::Process.new(email).perform
			ticket = @account.tickets.last
			ticket_incremented?(@ticket_size)
			ticket.responder.id.should eql @account.agents.last.user.id
		end

		it "change type with sendgrid" do
			email = new_email({:email_config => @account.primary_email_config.to_email, :reply => @agent.user.email})
			email[:from] = @agent.user.email
			email[:text] = %(\n#{@account.email_cmds_delimeter} "type":"Incident" #{@account.email_cmds_delimeter} \n)+email[:text]
			email[:html] = %(\n#{@account.email_cmds_delimeter} "type":"Incident" #{@account.email_cmds_delimeter} \n)+email[:html]
			Helpdesk::ProcessEmail.new(email).perform
			ticket = @account.tickets.last
			ticket_incremented?(@ticket_size)
			ticket.ticket_type.should eql "Incident"
		end

		it "change type with mailgun" do
			email = new_mailgun_email({:email_config => @account.primary_email_config.to_email, :reply => @agent.user.email})
			email[:from] = @agent.user.email
			email["body-plain"] = %(\n#{@account.email_cmds_delimeter} "type":"Incident" #{@account.email_cmds_delimeter} \n)+email["body-plain"]
			email["body-html"] = %(\n#{@account.email_cmds_delimeter} "type":"Incident" #{@account.email_cmds_delimeter} \n)+email["body-html"]
			Helpdesk::Email::Process.new(email).perform
			ticket = @account.tickets.last
			ticket_incremented?(@ticket_size)
			ticket.ticket_type.should eql "Incident"
		end

		it "change group with sendgrid" do
			email = new_email({:email_config => @account.primary_email_config.to_email, :reply => @agent.user.email})
			email[:from] = @agent.user.email
			email[:text] = %(\n#{@account.email_cmds_delimeter} "group":"Sales" #{@account.email_cmds_delimeter} \n)+email[:text]
			email[:html] = %(\n#{@account.email_cmds_delimeter} "group":"Sales" #{@account.email_cmds_delimeter} \n)+email[:html]
			Helpdesk::ProcessEmail.new(email).perform
			ticket = @account.tickets.last
			ticket_incremented?(@ticket_size)
			ticket.group.name.should eql "Sales"
		end

		it "change group with mailgun" do
			email = new_mailgun_email({:email_config => @account.primary_email_config.to_email, :reply => @agent.user.email})
			email[:from] = @agent.user.email
			email["body-plain"] = %(\n#{@account.email_cmds_delimeter} "group":"Sales" #{@account.email_cmds_delimeter} \n)+email["body-plain"]
			email["body-html"] = %(\n#{@account.email_cmds_delimeter} "group":"Sales" #{@account.email_cmds_delimeter} \n)+email["body-html"]
			Helpdesk::Email::Process.new(email).perform
			ticket = @account.tickets.last
			ticket_incremented?(@ticket_size)
			ticket.group.name.should eql "Sales"
		end

		it "change source with sendgrid" do
			email = new_email({:email_config => @account.primary_email_config.to_email, :reply => @agent.user.email})
			email[:from] = @agent.user.email
			email[:text] = %(\n#{@account.email_cmds_delimeter} "source":"chat" #{@account.email_cmds_delimeter} \n)+email[:text]
			email[:html] = %(\n#{@account.email_cmds_delimeter} "source":"chat" #{@account.email_cmds_delimeter} \n)+email[:html]
			Helpdesk::ProcessEmail.new(email).perform
			ticket = @account.tickets.last
			ticket_incremented?(@ticket_size)
			ticket.source.should eql 7
		end

		it "change source with mailgun" do
			email = new_mailgun_email({:email_config => @account.primary_email_config.to_email, :reply => @agent.user.email})
			email[:from] = @agent.user.email
			email["body-plain"] = %(\n#{@account.email_cmds_delimeter} "source":"chat" #{@account.email_cmds_delimeter} \n)+email["body-plain"]
			email["body-html"] = %(\n#{@account.email_cmds_delimeter} "source":"chat" #{@account.email_cmds_delimeter} \n)+email["body-html"]
			Helpdesk::Email::Process.new(email).perform
			ticket = @account.tickets.last
			ticket_incremented?(@ticket_size)
			ticket.source.should eql 7
		end

		it "change custom_field with sendgrid" do
			email = new_email({:email_config => @account.primary_email_config.to_email, :reply => @agent.user.email})
			email[:from] = @agent.user.email
			email[:text] = %(\n#{@account.email_cmds_delimeter} "abcd":"1234" #{@account.email_cmds_delimeter} \n)+email[:text]
			email[:html] = %(\n#{@account.email_cmds_delimeter} "abcd":"1234" #{@account.email_cmds_delimeter} \n)+email[:html]
			Helpdesk::ProcessEmail.new(email).perform
			ticket = @account.tickets.last
			ticket_incremented?(@ticket_size)
			ticket.custom_field["abcd_1"].should eql "1234"
		end

		it "change custom_field with mailgun" do
			email = new_mailgun_email({:email_config => @account.primary_email_config.to_email, :reply => @agent.user.email})
			email[:from] = @agent.user.email
			email["body-plain"] = %(\n#{@account.email_cmds_delimeter} "abcd":"1234" #{@account.email_cmds_delimeter} \n)+email["body-plain"]
			email["body-html"] = %(\n#{@account.email_cmds_delimeter} "abcd":"1234" #{@account.email_cmds_delimeter} \n)+email["body-html"]
			Helpdesk::Email::Process.new(email).perform
			ticket = @account.tickets.last
			ticket_incremented?(@ticket_size)
			ticket.custom_field["abcd_1"].should eql "1234"
		end

		it "private note in mailgun" do
			email = new_mailgun_email({:email_config => @account.primary_email_config.to_email})
			Helpdesk::Email::Process.new(email).perform
			ticket = @account.tickets.last
			another = new_mailgun_email({:email_config => @account.primary_email_config.to_email, :reply => @agent.user.email})
			another["subject"] = another["subject"]+" [##{ticket.display_id}]"
			another[:from] = @agent.user.email
			another["body-plain"] = %(\n#{@account.email_cmds_delimeter} "action":"note" #{@account.email_cmds_delimeter} \n)+another["body-plain"]
			another["body-html"] = %(\n#{@account.email_cmds_delimeter} "action":"note" #{@account.email_cmds_delimeter} \n)+another["body-html"]
			Helpdesk::Email::Process.new(another).perform
			ticket = @account.tickets.last
			ticket_incremented?(@ticket_size)
			@account.notes.size.should eql @note_size+1
			ticket.notes.last.private?.should eql true
		end

		it "private note in sendgrid" do
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
			ticket_incremented?(@ticket_size)
			@account.notes.size.should eql @note_size+1
			ticket.notes.last.private?.should eql true
		end

		it "change multiple with sendgrid" do
			email = new_email({:email_config => @account.primary_email_config.to_email, :reply => @agent.user.email})
			email[:from] = @agent.user.email
			email[:text] = %(\n#{@account.email_cmds_delimeter} "source":"chat", "priority":"medium", "status":"closed", "agent":"me", "abcd":"1234" #{@account.email_cmds_delimeter} \n)+email[:text]
			email[:html] = %(\n#{@account.email_cmds_delimeter} "source":"chat", "priority":"medium", "status":"closed", "agent":"me", "abcd":"1234" #{@account.email_cmds_delimeter} \n)+email[:html]
			Helpdesk::ProcessEmail.new(email).perform
			ticket = @account.tickets.last
			ticket_incremented?(@ticket_size)
			ticket.source.should eql 7
			ticket.priority.should eql 2
			ticket.status.should eql 5
			ticket.responder.id.should eql @agent.user.id
			ticket.custom_field["abcd_1"].should eql "1234"
		end

		it "change multiple with mailgun" do
			email = new_mailgun_email({:email_config => @account.primary_email_config.to_email, :reply => @agent.user.email})
			email[:from] = @agent.user.email
			email["body-plain"] = %(\n#{@account.email_cmds_delimeter} "source":"chat", "priority":"medium", "status":"closed", "agent":"me", "abcd":"1234" #{@account.email_cmds_delimeter} \n)+email["body-plain"]
			email["body-html"] = %(\n#{@account.email_cmds_delimeter} "source":"chat", "priority":"medium", "status":"closed", "agent":"me", "abcd":"1234" #{@account.email_cmds_delimeter} \n)+email["body-html"]
			Helpdesk::Email::Process.new(email).perform
			ticket = @account.tickets.last
			ticket_incremented?(@ticket_size)
			ticket.source.should eql 7
			ticket.priority.should eql 2
			ticket.status.should eql 5
			ticket.responder.id.should eql @agent.user.id
			ticket.custom_field["abcd_1"].should eql "1234"
		end
	end
end