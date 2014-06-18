require 'spec_helper'
include MailgunHelper

describe Helpdesk::Email::Process do
	before(:all) do
		add_agent_to_account(@account, {:name => "Harry Potter", :email => Faker::Internet.email, :active => true})
		EmailConfig.delete_all "active=0"
		@account.email_configs.first.update_attributes({:primary_role => true})
		@comp = create_company
	end

	before(:each) do
		@ticket_size = Helpdesk::Ticket.all.size
		@note_size = Helpdesk::Note.all.size
		@article_size = Solution::Article.all.size
		@account.make_current
	end

	after(:each) do
		@ticket_size = Helpdesk::Ticket.all.size
		@note_size = Helpdesk::Note.all.size
		@article_size = Solution::Article.all.size
	end

	#All exception handling has been left out except attachment

	#All attachment related tests have been commented out.
	#In order to test spec on attachments please place a test file in spec/fixtures/files
	#Then change the attachment name in the test clause and then run the tests.
	#When checking for attachments please check for those above 15MB too.
	#Also check S3.yml and change the test credentials to that in staging.

	describe "Create ticket" do
		it "Reply-To Based requester" do
			email = new_mailgun_email({:email_config => @account.primary_email_config.to_email})
			reply_to = email["Reply-To"]
			Helpdesk::Email::Process.new(email).perform
			ticket = Helpdesk::Ticket.last
			Helpdesk::Ticket.all.size.should eql @ticket_size+1
			@account.tickets.last.requester.email.downcase.should eql reply_to.downcase
  	end

  	it "from 'From' Based requester" do
			email = new_mailgun_email({:email_config => @account.primary_email_config.to_email})
			email["Reply-To"] = nil
			Helpdesk::Email::Process.new(email).perform
			ticket = Helpdesk::Ticket.last
			Helpdesk::Ticket.all.size.should eql @ticket_size+1
			@account.tickets.last.requester.email.downcase.should eql email[:from].downcase
  	end

  	it "non Reply_to based" do
  		email = new_mailgun_email({:email_config => @account.primary_email_config.to_email})
  		@account.features.reply_to_based_tickets.destroy
			Helpdesk::Email::Process.new(email).perform
			ticket = Helpdesk::Ticket.last
			Helpdesk::Ticket.all.size.should eql @ticket_size+1
  		@account.tickets.last.requester.email.downcase.should eql email[:from].downcase
		end

		it "with kbase in cc by requester" do
			email = new_mailgun_email({:email_config => @account.primary_email_config.to_email, :include_cc => @account.kbase_email})
			Helpdesk::Email::Process.new(email).perform
			ticket = Helpdesk::Ticket.last
			Helpdesk::Ticket.all.size.should eql @ticket_size+1
			Solution::Article.all.size.should eql @article_size
		end

		it "by agent with kbase in cc", :focus => true do
			email = new_mailgun_email({:email_config => @account.primary_email_config.to_email, :include_cc => @account.kbase_email, :reply => @account.agents.first.user.email})
			Helpdesk::Email::Process.new(email).perform
			ticket = Helpdesk::Ticket.last
			Helpdesk::Ticket.all.size.should eql @ticket_size+1
			Solution::Article.all.size.should eql @article_size+1
		end

		it "with attachments" do
			email = new_mailgun_email({:email_config => @account.primary_email_config.to_email, :attachments => 1})
			Helpdesk::Email::Process.new(email).perform
			ticket = Helpdesk::Ticket.last
			Helpdesk::Ticket.all.size.should eql @ticket_size+1
			ticket.attachments.size.should eql 1
		end

		it "with attachments above 15 mb" do
			email = new_mailgun_email({:email_config => @account.primary_email_config.to_email, :attachments => 1, :large => 1})
			Helpdesk::Email::Process.new(email).perform
			ticket = Helpdesk::Ticket.last
			Helpdesk::Ticket.all.size.should eql @ticket_size+1
			ticket.attachments.size.should eql 0
		end

		it "with inline attachments" do
			email = new_mailgun_email({:email_config => @account.primary_email_config.to_email, :attachments => 1, :inline => 1})
			email["body-html"] = email["body-html"] + "<img src=\"#{content_id}\" alt=\"Inline image 1\"><br>"
			Helpdesk::Email::Process.new(email).perform
			ticket = Helpdesk::Ticket.last
			Helpdesk::Ticket.all.size.should eql @ticket_size+1
			ticket.attachments.size.should eql 1
		end

		it "forwarded from agent" do
			email = new_mailgun_email({:email_config => @account.primary_email_config.to_email, :reply => @account.agents.first.user.email})
			email["body-plain"] = add_forward_content+email["body-plain"]
			email["body-html"] = add_forward_content+email["body-html"]
			Helpdesk::Email::Process.new(email).perform
			ticket = Helpdesk::Ticket.last
			Helpdesk::Ticket.all.size.should eql @ticket_size+1
			ticket.requester.email.should_not eql @account.primary_email_config.to_email
		end

		it "with plain text" do
			email = new_mailgun_email({:email_config => @account.primary_email_config.to_email})
			email["body-html"] = ""
			Helpdesk::Email::Process.new(email).perform
			ticket = Helpdesk::Ticket.last
			Helpdesk::Ticket.all.size.should eql @ticket_size+1
		end

		it "to other account with no domain mapping" do
			email = new_mailgun_email({:email_config => "support@localhost2.freshdesk-dev.com"})
			Helpdesk::Email::Process.new(email).perform
			ticket = Helpdesk::Ticket.last
			Helpdesk::Ticket.all.size.should eql @ticket_size
		end

		it "with only html" do
			email = new_mailgun_email({:email_config => @account.primary_email_config.to_email})
			email.delete(:text)
			Helpdesk::Email::Process.new(email).perform
			ticket = Helpdesk::Ticket.last
			Helpdesk::Ticket.all.size.should eql @ticket_size+1
		end

		it "with charset" do
			email = new_mailgun_email({:email_config => @account.primary_email_config.to_email})
			email[:charsets] = charset_hash
			Helpdesk::Email::Process.new(email).perform
			ticket = Helpdesk::Ticket.last
			Helpdesk::Ticket.all.size.should eql @ticket_size+1
		end

		it "from snapengage for chat" do
			email_id = "sample1234@snapengage.com"
			email = new_mailgun_email({:email_config => @account.primary_email_config.to_email, :reply => email_id})
			Helpdesk::Email::Process.new(email).perform
			ticket = Helpdesk::Ticket.last
			Helpdesk::Ticket.all.size.should eql @ticket_size+1
			ticket.source.should eql 7
		end

		it "from blocked user" do
			user1 = add_new_user(@account, {:blocked => true, :email => "sampleone@shdjsjdsd.ccc"})
			email = new_mailgun_email({:email_config => @account.primary_email_config.to_email, :reply => user1.email})
			Helpdesk::Email::Process.new(email).perform
			ticket = Helpdesk::Ticket.last
			Helpdesk::Ticket.all.size.should eql @ticket_size
		end

		it "from deleted user" do
			user1 = add_new_user(@account, {:deleted => true, :email => "sampleone@shdjsjdsd.ccc"})
			email = new_mailgun_email({:email_config => @account.primary_email_config.to_email, :reply => user1.email})
			Helpdesk::Email::Process.new(email).perform
			ticket = Helpdesk::Ticket.last
			Helpdesk::Ticket.all.size.should eql @ticket_size+1
			ticket.spam.should eql true
		end

		it "with email commands" do
			email = new_mailgun_email({:email_config => @account.primary_email_config.to_email, :reply => @account.agents.first.user.email})
			email[:from] = @account.agents.first.user.email
			email["body-plain"] = %(\n#{@account.email_cmds_delimeter} "priority":"medium" #{@account.email_cmds_delimeter} \n)+email["body-plain"]
			email["body-html"] = %(\n#{@account.email_cmds_delimeter} "priority":"medium" #{@account.email_cmds_delimeter} \n)+email["body-html"]
			Helpdesk::Email::Process.new(email).perform
			ticket = Helpdesk::Ticket.last
			Helpdesk::Ticket.all.size.should eql @ticket_size+1
			ticket.priority.should eql 2
		end

		it "with unknown email_config" do
			email = new_mailgun_email({:email_config => "abcde234fg@localhost.freshpo.com"})
			Helpdesk::Email::Process.new(email).perform
			Helpdesk::Ticket.all.size.should eql @ticket_size+1
		end

		it "with unknown and actual email_config" do
			email = new_mailgun_email({:email_config => "abcde234fg@localhost.freshpo.com", :another_config => @account.primary_email_config.to_email})
			Helpdesk::Email::Process.new(email).perform
			Helpdesk::Ticket.all.size.should eql @ticket_size+1
		end

		it "with an additional TO email" do
			new_to_email = Faker::Internet.email
			email = new_mailgun_email({:email_config => @account.primary_email_config.to_email, :include_to => new_to_email})
			Helpdesk::Email::Process.new(email).perform
			Helpdesk::Ticket.all.size.should eql @ticket_size+1
			Helpdesk::Ticket.last.to_emails.should include new_to_email
		end

		it "from auto responders" do
			email = new_mailgun_email({:email_config => @account.primary_email_config.to_email, :auto => true})
			Helpdesk::Email::Process.new(email).perform
			Helpdesk::Ticket.all.size.should eql @ticket_size+1
		end

	end

	describe "Create article" do
		it "once by email" do
			email = new_mailgun_email({:email_config => @account.kbase_email, :reply => @account.agents.first.user.email})
			email[:from] = @account.agents.first.user.email
			Helpdesk::Email::Process.new(email).perform
			Solution::Article.all.size.should eql @article_size+1
		end

		it "article failure - non agent" do
			email = new_mailgun_email({:email_config => @account.kbase_email})
			Helpdesk::Email::Process.new(email).perform
			Solution::Article.all.size.should eql @article_size
		end

		it "with inline attachments" do
			email = new_mailgun_email({:email_config => @account.kbase_email, :reply => @account.agents.first.user.email, :attachments => 1, :inline => 1})
			email["body-html"] = email["body-html"] + "<img src=\"#{content_id}\" alt=\"Inline image 1\"><br>"
			email[:from] = @account.agents.first.user.email
			Helpdesk::Email::Process.new(email).perform
			solution = Solution::Article.last
			Solution::Article.all.size.should eql @article_size+1
			solution.attachments.size.should eql 1
		end
	end

	describe "Create Note" do
		it "by ticket id" do
			email_id = Faker::Internet.email
			email = new_mailgun_email({:email_config => @account.primary_email_config.to_email, :reply => email_id})
			another = new_mailgun_email({:email_config => @account.primary_email_config.to_email, :reply => email_id})
			Helpdesk::Email::Process.new(email).perform
			ticket = Helpdesk::Ticket.last
			another["subject"] = another["subject"]+" [##{ticket.display_id}]"
			Helpdesk::Email::Process.new(another).perform
			Helpdesk::Ticket.all.size.should eql @ticket_size+1
			Helpdesk::Note.all.size.should eql @note_size+1
			ticket.notes.size.should eql 1
		end

		it "by blocked user" do
			user1 = Factory.build(:user, :account => @account,
                    :name => "samplethree", :email => "samplethree@shdjsjdsd.ccc",
                    :time_zone => "Chennai", :active => 0, :delta => 1, :language => "en")
			user1.save(false)
			email = new_mailgun_email({:email_config => @account.primary_email_config.to_email, :reply => user1.email})
			another = new_mailgun_email({:email_config => @account.primary_email_config.to_email, :reply => user1.email})
			Helpdesk::Email::Process.new(email).perform
			ticket = Helpdesk::Ticket.last
			user1.blocked = true
			user1.save(false)
			another["subject"] = another["subject"]+" [##{ticket.display_id}]"
			Helpdesk::Email::Process.new(another).perform
			Helpdesk::Ticket.all.size.should eql @ticket_size+1
			Helpdesk::Note.all.size.should eql @note_size
		end

		it "with email_commands" do
			email = new_mailgun_email({:email_config => @account.primary_email_config.to_email})
			Helpdesk::Email::Process.new(email).perform
			ticket = Helpdesk::Ticket.last
			another = new_mailgun_email({:email_config => @account.primary_email_config.to_email, :reply => @account.agents.first.user.email})
			another["subject"] = another["subject"]+" [##{ticket.display_id}]"
			another[:from] = @account.agents.first.user.email
			another["body-plain"] = %(\n#{@account.email_cmds_delimeter} "priority":"medium" #{@account.email_cmds_delimeter} \n)+another["body-plain"]
			another["body-html"] = %(\n#{@account.email_cmds_delimeter} "priority":"medium" #{@account.email_cmds_delimeter} \n)+another["body-html"]
			Helpdesk::Email::Process.new(another).perform
			ticket = Helpdesk::Ticket.last
			Helpdesk::Ticket.all.size.should eql @ticket_size+1
			Helpdesk::Note.all.size.should eql @note_size+1
			ticket.priority.should eql 2
		end

		it "by span" do
			email_id = Faker::Internet.email
			email = new_mailgun_email({:email_config => @account.primary_email_config.to_email, :reply => email_id})
			another = new_mailgun_email({:email_config => @account.primary_email_config.to_email, :reply => email_id})
			Helpdesk::Email::Process.new(email).perform
			ticket = Helpdesk::Ticket.last
			another["body-html"] = another["body-html"]+" #{span_gen(ticket.display_id)} "+another["body-html"]
			Helpdesk::Email::Process.new(another).perform
			Helpdesk::Ticket.all.size.should eql @ticket_size+1
			Helpdesk::Note.all.size.should eql @note_size+1
			ticket.notes.size.should eql 1
		end 

		it "by style span" do
			email_id = Faker::Internet.email
			email = new_mailgun_email({:email_config => @account.primary_email_config.to_email, :reply => email_id})
			another = new_mailgun_email({:email_config => @account.primary_email_config.to_email, :reply => email_id})
			Helpdesk::Email::Process.new(email).perform
			ticket = Helpdesk::Ticket.last
			another["body-html"] = another["body-html"]+" #{style_span_gen(ticket.display_id)} "+another["body-html"]
			Helpdesk::Email::Process.new(another).perform
			Helpdesk::Ticket.all.size.should eql @ticket_size+1
			Helpdesk::Note.all.size.should eql @note_size+1
			ticket.notes.size.should eql 1
		end 

		it "by header" do
			email_id = Faker::Internet.email
			email = new_mailgun_email({:email_config => @account.primary_email_config.to_email, :reply => email_id})
			another = new_mailgun_email({:email_config => @account.primary_email_config.to_email, :m_id => email["Message-Id"], :reply => email_id})
			Helpdesk::Email::Process.new(email).perform
			ticket = Helpdesk::Ticket.last
			Helpdesk::Email::Process.new(another).perform
			Helpdesk::Ticket.all.size.should eql @ticket_size+1
			Helpdesk::Note.all.size.should eql @note_size+1
			ticket.notes.size.should eql 1
		end

		it "from cc" do
			email_id = Faker::Internet.email
			email = new_mailgun_email({:email_config => @account.primary_email_config.to_email, :include_cc => email_id})
			another = new_mailgun_email({:email_config => @account.primary_email_config.to_email, :reply => email_id})
			Helpdesk::Email::Process.new(email).perform
			ticket = Helpdesk::Ticket.last
			another["body-html"] = another["body-html"]+" #{span_gen(ticket.display_id)} "+another["body-html"]
			Helpdesk::Email::Process.new(another).perform
			Helpdesk::Ticket.all.size.should eql @ticket_size+1
			Helpdesk::Note.all.size.should eql @note_size+1
			ticket.notes.size.should eql 1
		end

		it "from to" do
			email_id = Faker::Internet.email
			email = new_mailgun_email({:email_config => @account.primary_email_config.to_email, :include_to => email_id})
			another = new_mailgun_email({:email_config => @account.primary_email_config.to_email, :reply => email_id})
			Helpdesk::Email::Process.new(email).perform
			ticket = Helpdesk::Ticket.last
			another["body-html"] = another["body-html"]+" #{span_gen(ticket.display_id)} "+another["body-html"]
			Helpdesk::Email::Process.new(another).perform
			Helpdesk::Ticket.all.size.should eql @ticket_size+1
			Helpdesk::Note.all.size.should eql @note_size+1
			ticket.notes.size.should eql 1
		end

		it "by agent" do
			email_id = @account.agents.first.user.email
			email = new_mailgun_email({:email_config => @account.primary_email_config.to_email, :include_cc => email_id})
			another = new_mailgun_email({:email_config => @account.primary_email_config.to_email, :reply => email_id})
			Helpdesk::Email::Process.new(email).perform
			ticket = Helpdesk::Ticket.last
			another["body-html"] = another["body-html"]+" #{span_gen(ticket.display_id)} "+another["body-html"]
			Helpdesk::Email::Process.new(another).perform
			Helpdesk::Ticket.all.size.should eql @ticket_size+1
			Helpdesk::Note.all.size.should eql @note_size+1
			ticket.notes.size.should eql 1
		end

		it "from same company" do
			email = new_mailgun_email({:email_config => @account.primary_email_config.to_email, :reply => "sample1@#{@comp.domains}"})
			another = new_mailgun_email({:email_config => @account.primary_email_config.to_email, :reply => "sample2@#{@comp.domains}"})
			Helpdesk::Email::Process.new(email).perform
			ticket = Helpdesk::Ticket.last
			another["body-html"] = another["body-html"]+" #{span_gen(ticket.display_id)} "+another["body-html"]
			Helpdesk::Email::Process.new(another).perform
			Helpdesk::Ticket.all.size.should eql @ticket_size+1
			Helpdesk::Note.all.size.should eql @note_size+1
			ticket.notes.size.should eql 1
		end

		it "with quoted text" do
			email_id = Faker::Internet.email
			email = new_mailgun_email({:email_config => @account.primary_email_config.to_email, :include_cc => email_id})
			another = new_mailgun_email({:email_config => @account.primary_email_config.to_email, :reply => email_id})
			Helpdesk::Email::Process.new(email).perform
			ticket = Helpdesk::Ticket.last
			another["body-html"] = another["body-html"]+"----original message----"+another["body-html"]+" #{span_gen(ticket.display_id)} "
			Helpdesk::Email::Process.new(another).perform
			Helpdesk::Ticket.all.size.should eql @ticket_size+1
			Helpdesk::Note.all.size.should eql @note_size+1
			ticket.notes.size.should eql 1
		end

		it "for ticket without CC" do
			email = new_mailgun_email({:email_config => @account.primary_email_config.to_email})
			Helpdesk::Email::Process.new(email).perform
			ticket = @account.tickets.last
			Helpdesk::Ticket.update_all(:cc_email => nil)
			another = new_mailgun_email({:email_config => @account.primary_email_config.to_email, :reply => @account.agents.first.user.email})
			another["subject"] = another["subject"]+" [##{ticket.display_id}]"
			Helpdesk::Email::Process.new(another).perform
			Helpdesk::Ticket.all.size.should eql @ticket_size+1
			Helpdesk::Note.all.size.should eql @note_size+1
			ticket.notes.size.should eql 1
		end

		it "for merged ticket" do 
			email_id = Faker::Internet.email
			email = new_mailgun_email({:email_config => @account.primary_email_config.to_email, :reply => email_id})
			Helpdesk::Email::Process.new(email).perform
			ticket = @account.tickets.last
			n_email = new_mailgun_email({:email_config => @account.primary_email_config.to_email, :reply => email_id})
			Helpdesk::Email::Process.new(n_email).perform
			ticket2 = @account.tickets.last
			ticket.parent = ticket2
			ticket.save!
			another = new_mailgun_email({:email_config => @account.primary_email_config.to_email, :reply => email_id})
			another["subject"] = another["subject"]+" [##{ticket.display_id}]"
			Helpdesk::Email::Process.new(another).perform
			Helpdesk::Ticket.all.size.should eql @ticket_size+2
			Helpdesk::Note.all.size.should eql @note_size+1
			@account.notes.last.notable.id.should eql ticket2.id
		end

		it "as reply with new CC emails" do
			email_id = Faker::Internet.email
			new_to_email = Faker::Internet.email
			email = new_mailgun_email({:email_config => @account.primary_email_config.to_email, :reply => email_id})
			another = new_mailgun_email({:email_config => @account.primary_email_config.to_email, :reply => email_id, :include_cc => new_to_email})
			Helpdesk::Email::Process.new(email).perform
			ticket = Helpdesk::Ticket.last
			another["subject"] = another["subject"]+" [##{ticket.display_id}]"
			Helpdesk::Email::Process.new(another).perform
			Helpdesk::Ticket.all.size.should eql @ticket_size+1
			Helpdesk::Note.all.size.should eql @note_size+1
			Helpdesk::Ticket.last.cc_email_hash[:cc_emails].should include new_to_email
		end

		it "as reply from a CC email" do
			email_id = Faker::Internet.email
			new_to_email = Faker::Internet.email
			email = new_mailgun_email({:email_config => @account.primary_email_config.to_email, :reply => email_id})
			first_reply = new_mailgun_email({:email_config => @account.primary_email_config.to_email, :reply => email_id, :include_cc => new_to_email})
			second_reply = new_mailgun_email({:email_config => @account.primary_email_config.to_email, :reply => new_to_email})
			Helpdesk::Email::Process.new(email).perform
			ticket = Helpdesk::Ticket.last
			first_reply["subject"] = first_reply["subject"]+" [##{ticket.display_id}]"
			second_reply["subject"] = second_reply["subject"]+" [##{ticket.display_id}]"
			Helpdesk::Email::Process.new(first_reply).perform
			Helpdesk::Email::Process.new(second_reply).perform
			Helpdesk::Ticket.all.size.should eql @ticket_size+1
			Helpdesk::Note.all.size.should eql @note_size+2
		end
	end

end