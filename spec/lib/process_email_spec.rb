require 'spec_helper'

describe Helpdesk::Email::Process do
	before(:all) do
		@account = create_test_account
		@account.make_current
		ShardMapping.find_by_account_id(@account.id).update_attribute(:status,200)
		add_agent_to_account(@account, {:name => "Harry Potter", :email => "stupidscar@hogwarts.in", :active => true})
	end

	after(:each) do
		Helpdesk::Ticket.destroy_all
		Solution::Article.destroy_all
	end

	after(:all)	do
		User.destroy_all
		Helpdesk::Note.destroy_all
	end

	#All attachment related tests have been commented out.
	#In order to test spec on attachments please place a test file in spec/fixtures/files
	#Then change the attachment name in the test clause and then run the tests.
	#When checking for attachments please check for those above 15MB too.
	#Also check S3.yml and change the test credentials to that in staging.

	describe "Create ticket" do
		it "Reply-To Based requester" do
			email = new_email({:email_config => @account.primary_email_config.to_email})
			reply_to = email["Reply-To"]
			Helpdesk::Email::Process.new(email).perform
			ticket = Helpdesk::Ticket.first
			Helpdesk::Ticket.all.size.should eql 1
			@account.tickets.first.requester.email.downcase.should eql reply_to.downcase
  	end

  	it "From Based requester" do
			email = new_email({:email_config => @account.primary_email_config.to_email})
			email["Reply-To"] = nil
			Helpdesk::Email::Process.new(email).perform
			ticket = Helpdesk::Ticket.first
			Helpdesk::Ticket.all.size.should eql 1
			@account.tickets.first.requester.email.downcase.should eql email[:from].downcase
  	end

  	it "non Reply_to based" do
  		email = new_email({:email_config => @account.primary_email_config.to_email})
  		@account.features.reply_to_based_tickets.destroy
			Helpdesk::Email::Process.new(email).perform
			ticket = Helpdesk::Ticket.first
			Helpdesk::Ticket.all.size.should eql 1
  		@account.tickets.first.requester.email.downcase.should eql email[:from].downcase
		end

		it "with kbase in cc by requester" do
			email = new_email({:email_config => @account.primary_email_config.to_email, :include_cc => @account.kbase_email})
			Helpdesk::Email::Process.new(email).perform
			ticket = Helpdesk::Ticket.first
			Helpdesk::Ticket.all.size.should eql 1
			Solution::Article.all.size.should eql 0
		end

		it "by agent with kbase in cc", :focus => true do
			email = new_email({:email_config => @account.primary_email_config.to_email, :include_cc => @account.kbase_email, :reply => @account.agents.first.user.email})
			Helpdesk::Email::Process.new(email).perform
			ticket = Helpdesk::Ticket.first
			Helpdesk::Ticket.all.size.should eql 1
			Solution::Article.all.size.should eql 1
		end

		# it "with attachments" do
		# 	email = new_email({:email_config => @account.primary_email_config.to_email, :attachments => 1})
		# 	Helpdesk::Email::Process.new(email).perform
		# 	ticket = Helpdesk::Ticket.first
		# 	Helpdesk::Ticket.all.size.should eql 1
		# 	ticket.attachments.size.should eql 1
		# end

		# it "with inline attachments" do
		# 	email = new_email({:email_config => @account.primary_email_config.to_email, :attachments => 1, :inline => 1})
		# 	email[:html] = email[:html] + "<img src=\"#{content_id}\" alt=\"Inline image 1\"><br>"
		# 	Helpdesk::Email::Process.new(email).perform
		# 	ticket = Helpdesk::Ticket.first
		# 	Helpdesk::Ticket.all.size.should eql 1
		# 	ticket.attachments.size.should eql 1
		# end

		it "forwarded from agent" do
			email = new_email({:email_config => @account.primary_email_config.to_email, :reply => @account.agents.first.user.email})
			email["body-plain"] = add_forward_content+email["body-plain"]
			email["body-html"] = add_forward_content+email["body-html"]
			Helpdesk::Email::Process.new(email).perform
			ticket = Helpdesk::Ticket.first
			Helpdesk::Ticket.all.size.should eql 1
			ticket.requester.email.should_not eql @account.primary_email_config.to_email
		end

		it "with plain text" do
			email = new_email({:email_config => @account.primary_email_config.to_email})
			email["body-html"] = ""
			Helpdesk::Email::Process.new(email).perform
			ticket = Helpdesk::Ticket.first
			Helpdesk::Ticket.all.size.should eql 1
		end

		it "to other account with no domain mapping" do
			email = new_email({:email_config => "support@localhost2.freshdesk-dev.com"})
			Helpdesk::Email::Process.new(email).perform
			ticket = Helpdesk::Ticket.first
			Helpdesk::Ticket.all.size.should eql 0
		end

		it "with only html" do
			email = new_email({:email_config => @account.primary_email_config.to_email})
			email.delete(:text)
			Helpdesk::Email::Process.new(email).perform
			ticket = Helpdesk::Ticket.first
			Helpdesk::Ticket.all.size.should eql 1
		end

		it "with charset" do
			email = new_email({:email_config => @account.primary_email_config.to_email})
			email[:charsets] = charset_hash
			Helpdesk::Email::Process.new(email).perform
			ticket = Helpdesk::Ticket.first
			Helpdesk::Ticket.all.size.should eql 1
		end

		it "from snapengage" do
			email_id = "sampleticket@snapengage.com"
			email = new_email({:email_config => @account.primary_email_config.to_email, :reply => email_id})
			Helpdesk::Email::Process.new(email).perform
			ticket = Helpdesk::Ticket.first
			Helpdesk::Ticket.all.size.should eql 1
		end

		it "from blocked user" do
			user1 = Factory.build(:user, :account => @account,
                    :name => "sampletwo", :email => "sampletwo@shdjsjdsd.ccc", :blocked => true,
                    :time_zone => "Chennai", :active => 0, :delta => 1, :language => "en")
			user1.save(false)
			email = new_email({:email_config => @account.primary_email_config.to_email, :reply => user1.email})
			Helpdesk::Email::Process.new(email).perform
			ticket = Helpdesk::Ticket.first
			Helpdesk::Ticket.all.size.should eql 0
		end

		it "from deleted user" do
			user1 = Factory.build(:user, :account => @account,
                    :name => "sampleone", :email => "sampleone@shdjsjdsd.ccc", :deleted => true,
                    :time_zone => "Chennai", :active => 0, :delta => 1, :language => "en")
			user1.save(false)
			email = new_email({:email_config => @account.primary_email_config.to_email, :reply => user1.email})
			Helpdesk::Email::Process.new(email).perform
			ticket = Helpdesk::Ticket.first
			Helpdesk::Ticket.all.size.should eql 1
			ticket.spam.should eql true
		end

		it "with email commands" do
			email = new_email({:email_config => @account.primary_email_config.to_email, :reply => @account.agents.first.user.email})
			email[:from] = @account.agents.first.user.email
			email["body-plain"] = %(\n#{@account.email_cmds_delimeter} "priority":"medium" #{@account.email_cmds_delimeter} \n)+email["body-plain"]
			email["body-html"] = %(\n#{@account.email_cmds_delimeter} "priority":"medium" #{@account.email_cmds_delimeter} \n)+email["body-html"]
			Helpdesk::Email::Process.new(email).perform
			ticket = Helpdesk::Ticket.first
			Helpdesk::Ticket.all.size.should eql 1
			ticket.priority.should eql 2
		end

		it "with unknown email_config" do
			email = new_email({:email_config => "abcde234fg@localhost.freshdesk-dev.com"})
			Helpdesk::Email::Process.new(email).perform
			Helpdesk::Ticket.all.size.should eql 1
		end

		it "with unknown and actual email_config" do
			email = new_email({:email_config => "abcde234fg@localhost.freshdesk-dev.com", :another_config => @account.primary_email_config.to_email})
			Helpdesk::Email::Process.new(email).perform
			Helpdesk::Ticket.all.size.should eql 1
		end
	end

	describe "Create article" do
		it "once by email" do
			email = new_email({:email_config => @account.kbase_email, :reply => @account.agents.first.user.email})
			email[:from] = @account.agents.first.user.email
			Helpdesk::Email::Process.new(email).perform
			Solution::Article.all.size.should eql 1
		end

		it "article failure - non agent" do
			email = new_email({:email_config => @account.kbase_email})
			Helpdesk::Email::Process.new(email).perform
			Solution::Article.all.size.should eql 0
		end

		# it "with inline attachments" do
		# 	email = new_email({:email_config => @account.kbase_email, :reply => @account.agents.first.user.email, :attachments => 1, :inline => 1})
		# 	email[:html] = email[:html] + "<img src=\"#{content_id}\" alt=\"Inline image 1\"><br>"
		# 	email[:from] = @account.agents.first.user.email
		# 	Helpdesk::Email::Process.new(email).perform
		# 	solution = Solution::Article.first
		# 	Solution::Article.all.size.should eql 1
		# 	solution.attachments.size.should eql 1
		# end
	end

	describe "Create Note" do
		it "by ticket id" do
			email_id = "samplenote@frfeerferferf.cc"
			email = new_email({:email_config => @account.primary_email_config.to_email, :reply => email_id})
			another = new_email({:email_config => @account.primary_email_config.to_email, :reply => email_id})
			Helpdesk::Email::Process.new(email).perform
			ticket = Helpdesk::Ticket.first
			another[:subject] = another[:subject]+" [##{ticket.display_id}]"
			Helpdesk::Email::Process.new(another).perform
			Helpdesk::Ticket.all.size.should eql 1
			Helpdesk::Note.all.size.should eql 1
			@account.notes.first.notable.id.should eql ticket.id
		end

		it "by blocked user" do
			user1 = Factory.build(:user, :account => @account,
                    :name => "samplethree", :email => "samplethree@shdjsjdsd.ccc",
                    :time_zone => "Chennai", :active => 0, :delta => 1, :language => "en")
			user1.save(false)
			email = new_email({:email_config => @account.primary_email_config.to_email, :reply => user1.email})
			another = new_email({:email_config => @account.primary_email_config.to_email, :reply => user1.email})
			Helpdesk::Email::Process.new(email).perform
			ticket = Helpdesk::Ticket.first
			user1.blocked = true
			user1.save(false)
			another[:subject] = another[:subject]+" [##{ticket.display_id}]"
			Helpdesk::Email::Process.new(another).perform
			Helpdesk::Ticket.all.size.should eql 1
			Helpdesk::Note.all.size.should eql 0
		end

		it "with email_commands" do
			email = new_email({:email_config => @account.primary_email_config.to_email})
			Helpdesk::Email::Process.new(email).perform
			ticket = Helpdesk::Ticket.first
			another = new_email({:email_config => @account.primary_email_config.to_email, :reply => @account.agents.first.user.email})
			another[:subject] = another[:subject]+" [##{ticket.display_id}]"
			another[:from] = @account.agents.first.user.email
			another["body-plain"] = %(\n#{@account.email_cmds_delimeter} "priority":"medium" #{@account.email_cmds_delimeter} \n)+email["body-plain"]
			another["body-html"] = %(\n#{@account.email_cmds_delimeter} "priority":"medium" #{@account.email_cmds_delimeter} \n)+email["body-html"]
			Helpdesk::Email::Process.new(another).perform
			ticket = Helpdesk::Ticket.first
			Helpdesk::Ticket.all.size.should eql 1
			Helpdesk::Note.all.size.should eql 1
			ticket.priority.should eql 2
		end

		it "by span" do
			email_id = "samplenote@frfeerferferf.cc"
			email = new_email({:email_config => @account.primary_email_config.to_email, :reply => email_id})
			another = new_email({:email_config => @account.primary_email_config.to_email, :reply => email_id})
			Helpdesk::Email::Process.new(email).perform
			ticket = Helpdesk::Ticket.first
			another["body-html"] = another["body-html"]+" #{span_gen(ticket.display_id)} "+another["body-html"]
			Helpdesk::Email::Process.new(another).perform
			Helpdesk::Ticket.all.size.should eql 1
			Helpdesk::Note.all.size.should eql 1
			@account.notes.first.notable.id.should eql ticket.id
		end 

		it "by header" do
			email_id = "samplenotethere@asasdasdasdas.ccc"
			email = new_email({:email_config => @account.primary_email_config.to_email, :reply => email_id})
			another = new_email({:email_config => @account.primary_email_config.to_email, :m_id => email["Message-Id"], :reply => email_id})
			Helpdesk::Email::Process.new(email).perform
			ticket = Helpdesk::Ticket.first
			Helpdesk::Email::Process.new(another).perform
			Helpdesk::Ticket.all.size.should eql 1
			Helpdesk::Note.all.size.should eql 1
			@account.notes.first.notable.id.should eql ticket.id
		end

		it "from cc" do
			email_id = "samplecc@sdsdsdsd.cc"
			email = new_email({:email_config => @account.primary_email_config.to_email, :include_cc => email_id})
			another = new_email({:email_config => @account.primary_email_config.to_email, :reply => email_id})
			Helpdesk::Email::Process.new(email).perform
			ticket = Helpdesk::Ticket.first
			another["body-html"] = another["body-html"]+" #{span_gen(ticket.display_id)} "+another["body-html"]
			Helpdesk::Email::Process.new(another).perform
			Helpdesk::Ticket.all.size.should eql 1
			Helpdesk::Note.all.size.should eql 1
			@account.notes.first.notable.id.should eql ticket.id
		end

		it "from to" do
			email_id = "samplecc@sdsdsdsd.cc"
			email = new_email({:email_config => @account.primary_email_config.to_email, :include_to => email_id})
			another = new_email({:email_config => @account.primary_email_config.to_email, :reply => email_id})
			Helpdesk::Email::Process.new(email).perform
			ticket = Helpdesk::Ticket.first
			another["body-html"] = another["body-html"]+" #{span_gen(ticket.display_id)} "+another["body-html"]
			Helpdesk::Email::Process.new(another).perform
			Helpdesk::Ticket.all.size.should eql 1
			Helpdesk::Note.all.size.should eql 1
			@account.notes.first.notable.id.should eql ticket.id
		end

		it "by agent" do
			email_id = @account.agents.first.user.email
			email = new_email({:email_config => @account.primary_email_config.to_email, :include_cc => email_id})
			another = new_email({:email_config => @account.primary_email_config.to_email, :reply => email_id})
			Helpdesk::Email::Process.new(email).perform
			ticket = Helpdesk::Ticket.first
			another["body-html"] = another["body-html"]+" #{span_gen(ticket.display_id)} "+another["body-html"]
			Helpdesk::Email::Process.new(another).perform
			Helpdesk::Ticket.all.size.should eql 1
			Helpdesk::Note.all.size.should eql 1
			@account.notes.first.notable.id.should eql ticket.id
		end

		it "with quoted text" do
			email_id = "samplecc@sdsdsdsd.cc"
			email = new_email({:email_config => @account.primary_email_config.to_email, :include_cc => email_id})
			another = new_email({:email_config => @account.primary_email_config.to_email, :reply => email_id})
			Helpdesk::Email::Process.new(email).perform
			ticket = Helpdesk::Ticket.first
			another["body-html"] = another["body-html"]+"----original message----"+another["body-html"]+" #{span_gen(ticket.display_id)} "
			Helpdesk::Email::Process.new(another).perform
			Helpdesk::Ticket.all.size.should eql 1
			Helpdesk::Note.all.size.should eql 1
			@account.notes.first.notable.id.should eql ticket.id
		end

		it "for ticket without CC" do
			email = new_email({:email_config => @account.primary_email_config.to_email})
			Helpdesk::Email::Process.new(email).perform
			ticket = @account.tickets.first
			Helpdesk::Ticket.update_all(:cc_email => nil)
			another = new_email({:email_config => @account.primary_email_config.to_email, :reply => @account.agents.first.user.email})
			another[:subject] = another[:subject]+" [##{ticket.display_id}]"
			Helpdesk::Email::Process.new(another).perform
			Helpdesk::Ticket.all.size.should eql 1
			Helpdesk::Note.all.size.should eql 1
			@account.notes.first.notable.id.should eql ticket.id
		end
	end

end