require 'spec_helper'
RSpec.configure do |c|
  c.include EmailHelper
end

RSpec.describe Helpdesk::ProcessEmail do
	before(:all) do
		before_all_call
	end

	before(:each) do
		@account.reload		
		@account.make_current
		@ticket_size = @account.tickets.size
		@note_size = @account.notes.size
		@article_size = @account.solution_articles.size
		stub_s3_writes
	end

	after(:each) do
		@account.reload
		@account.make_current
		@ticket_size = @account.tickets.size
		@note_size = @account.notes.size
		@article_size = @account.solution_articles.size
	end

	after(:all) do
		restore_default_feature("reply_to_based_tickets")
	end

	#All exception handling has been left out except attachment

	#All attachment related tests have been commented out.
	#In order to test spec on attachments please place a test file in spec/fixtures/files
	#Then change the attachment name in the test clause and then run the tests.
	#When checking for attachments please check for those above 15MB too.
	#Also check S3.yml and change the test credentials to that in staging.

	describe "Create ticket" do
		it "Reply-To Based requester" do
			email_id = Faker::Internet.email
			email = new_email({:email_config => @account.primary_email_config.to_email, :reply => email_id})
			Helpdesk::ProcessEmail.new(email).perform
			ticket_incremented?(@ticket_size)
			@account.tickets.last.requester.email.downcase.should eql email_id.downcase
  	end

  	it "From Based requester" do
			email = new_email({:email_config => @account.primary_email_config.to_email, :reply => ""})
			Helpdesk::ProcessEmail.new(email).perform
			ticket = @account.tickets.last
			ticket_incremented?(@ticket_size)
			@account.tickets.last.requester.email.downcase.should eql email[:from].downcase
  	end

  	it "with multiple reply_to emails" do
			a = []
			5.times do
				a << Faker::Internet.email
			end
			email = new_email({:email_config => @account.primary_email_config.to_email, :reply => a.join(", ")})
			Helpdesk::ProcessEmail.new(email).perform
			ticket = @account.tickets.last
			ticket_incremented?(@ticket_size)
			@account.tickets.last.requester.email.downcase.should eql a.first
			ticket.cc_email_hash[:cc_emails].should include(*a[1..-1])
  	end

  	it "with multiple reply_to emails and repeating cc emails" do
			a = []
			5.times do
				a << Faker::Internet.email
			end
			cc = a.last
			email = new_email({:email_config => @account.primary_email_config.to_email, :reply => a.join(", "), :include_cc => cc})
			Helpdesk::ProcessEmail.new(email).perform
			ticket = @account.tickets.last
			ticket_incremented?(@ticket_size)
			@account.tickets.last.requester.email.downcase.should eql a.first
			ticket.cc_email_hash[:cc_emails].should include(*a[1..-1])
			ticket.cc_email_hash[:cc_emails].should include(cc)
			(ticket.cc_email_hash[:cc_emails].length - ticket.cc_email_hash[:cc_emails].uniq.length).should eql 0
  	end

  	it "with multiple reply_to emails and cc emails without repetition" do
			a = []
			5.times do
				a << Faker::Internet.email
			end
			cc = Faker::Internet.email
			email = new_email({:email_config => @account.primary_email_config.to_email, :reply => a.join(", "), :include_cc => cc})
			Helpdesk::ProcessEmail.new(email).perform
			ticket = @account.tickets.last
			ticket_incremented?(@ticket_size)
			@account.tickets.last.requester.email.downcase.should eql a.first
			ticket.cc_email_hash[:cc_emails].should include(*a[1..-1])
			ticket.cc_email_hash[:cc_emails].should include(cc)
			(ticket.cc_email_hash[:cc_emails].length - ticket.cc_email_hash[:cc_emails].uniq.length).should eql 0
  	end

  	it "with multiple reply_to emails without the feature" do
  		@account.features.reply_to_based_tickets.destroy
			a = []
			5.times do
				a << Faker::Internet.email
			end
			email = new_email({:email_config => @account.primary_email_config.to_email, :reply => a.join(", ")})
			Helpdesk::ProcessEmail.new(email).perform
			ticket = @account.tickets.last
			ticket_incremented?(@ticket_size)
			@account.tickets.last.requester.email.downcase.should eql email[:from]
			ticket.cc_email_hash[:cc_emails].should_not include(*a[1..-1])
  		@account.features.reply_to_based_tickets.create
  	end

  	it "non Reply_to based" do
  		email = new_email({:email_config => @account.primary_email_config.to_email})
  		@account.features.reply_to_based_tickets.destroy
			Helpdesk::ProcessEmail.new(email).perform
			ticket = @account.tickets.last
			ticket_incremented?(@ticket_size)
  		@account.tickets.last.requester.email.downcase.should eql email[:from].downcase
			@account.features.reply_to_based_tickets.create
			@account.reload
		end

		it "with kbase in cc by requester" do
			email = new_email({:email_config => @account.primary_email_config.to_email, :include_cc => @account.kbase_email})
			Helpdesk::ProcessEmail.new(email).perform
			ticket = @account.tickets.last
			ticket_incremented?(@ticket_size)
			@account.solution_articles.size.should eql @article_size
		end

		it "by agent with kbase in cc", :focus => true do
			email = new_email({:email_config => @account.primary_email_config.to_email, :include_cc => @account.kbase_email, :reply => @agent.user.email})
			Helpdesk::ProcessEmail.new(email).perform
			ticket = @account.tickets.last
			@account.reload
      ticket_incremented?(@ticket_size)
			@account.solution_articles.size.should eql @article_size+1
		end

		it "with attachments" do
			email = new_email({:email_config => @account.primary_email_config.to_email, :attachments => 1})
			Helpdesk::ProcessEmail.new(email).perform
			ticket = @account.tickets.last
			ticket_incremented?(@ticket_size)
			ticket.attachments.size.should eql 1
		end

		it "with inline attachments" do
			email = new_email({:email_config => @account.primary_email_config.to_email, :attachments => 1, :inline => 1})
			email[:html] = email[:html] + "<img src=\"#{content_id}\" alt=\"Inline image 1\"><br>"
			Helpdesk::ProcessEmail.new(email).perform
			ticket = @account.tickets.last
			ticket_incremented?(@ticket_size)
			ticket.attachments.size.should eql 1
		end

		it "with attachments above 15 mb" do
			email = new_email({:email_config => @account.primary_email_config.to_email, :attachments => 1, :large => 1})
			Helpdesk::ProcessEmail.new(email).perform
			ticket = @account.tickets.last
			ticket_incremented?(@ticket_size)
			ticket.attachments.size.should eql 0
		end

		it "forwarded from agent" do
			email = new_email({:email_config => @account.primary_email_config.to_email, :reply => @agent.user.email})
			email[:text] = add_forward_content+email[:text]
			email[:html] = add_forward_content+email[:html]
			Helpdesk::ProcessEmail.new(email).perform
			ticket = @account.tickets.last
			ticket_incremented?(@ticket_size)
			ticket.requester.email.should_not eql @agent.user.email
		end

		it "with plain text" do
			email = new_email({:email_config => @account.primary_email_config.to_email})
			email[:html] = ""
			Helpdesk::ProcessEmail.new(email).perform
			ticket = @account.tickets.last
			ticket_incremented?(@ticket_size)
		end

		it "with only html" do
			email = new_email({:email_config => @account.primary_email_config.to_email})
			email.delete(:text)
			Helpdesk::ProcessEmail.new(email).perform
			ticket = @account.tickets.last
			ticket_incremented?(@ticket_size)
		end

		it "with charset" do
			email = new_email({:email_config => @account.primary_email_config.to_email})
			email[:charsets] = charset_hash
			Helpdesk::ProcessEmail.new(email).perform
			ticket = @account.tickets.last
			ticket_incremented?(@ticket_size)
		end

		it "with different charset" do
			email = new_email({:email_config => @account.primary_email_config.to_email})
			email[:charsets] = charset_hash(1)
			Helpdesk::ProcessEmail.new(email).perform
			ticket = @account.tickets.last
			ticket_incremented?(@ticket_size)
		end

		it "from snapengage for chat" do
			email_id = "sampleticket@snapengage.com"
			email = new_email({:email_config => @account.primary_email_config.to_email, :reply => email_id})
			Helpdesk::ProcessEmail.new(email).perform
			ticket = @account.tickets.last
			ticket_incremented?(@ticket_size)
			ticket.source.should eql 7
		end

		it "from blocked user" do
			user1 = add_new_user(@account, {:blocked => true})
			email = new_email({:email_config => @account.primary_email_config.to_email, :reply => user1.email})
			Helpdesk::ProcessEmail.new(email).perform
			ticket = @account.tickets.last
			@account.tickets.size.should eql @ticket_size
		end

		it "from deleted user" do
			user1 = add_new_user(@account, {:deleted => true})
			email = new_email({:email_config => @account.primary_email_config.to_email, :reply => user1.email})
			Helpdesk::ProcessEmail.new(email).perform
			ticket = @account.tickets.last
			ticket_incremented?(@ticket_size)
			ticket.spam.should eql true
		end

		it "with email commands" do
			email = new_email({:email_config => @account.primary_email_config.to_email, :reply => @agent.user.email})
			email[:from] = @agent.user.email
			email[:text] = %(\n#{@account.email_cmds_delimeter} "priority":"medium" #{@account.email_cmds_delimeter} \n)+email[:text]
			email[:html] = %(\n#{@account.email_cmds_delimeter} "priority":"medium" #{@account.email_cmds_delimeter} \n)+email[:html]
			Helpdesk::ProcessEmail.new(email).perform
			ticket = @account.tickets.last
			ticket_incremented?(@ticket_size)
			ticket.priority.should eql 2
		end

		it "with unknown email_config" do
			email = new_email({:email_config => "abcde234fg@localhost.freshpo.com"})
			Helpdesk::ProcessEmail.new(email).perform
			ticket_incremented?(@ticket_size)
		end

		it "with unknown and actual email_config" do
			email = new_email({:email_config => "abcde234fg@localhost.freshpo.com", :another_config => @account.primary_email_config.to_email})
			Helpdesk::ProcessEmail.new(email).perform
			ticket_incremented?(@ticket_size)
		end

		it "with an additional TO email" do
			new_to_email = Faker::Internet.email
			email = new_email({:email_config => @account.primary_email_config.to_email, :include_to => new_to_email})
			Helpdesk::ProcessEmail.new(email).perform
			ticket_incremented?(@ticket_size)
			@account.tickets.last.to_emails.select{|email_id| email_id.include?(new_to_email.downcase) }.should_not be_empty
		end

		it "with no envelope" do
			email = new_email({:email_config => @account.primary_email_config.to_email})
			email.delete(:envelope)
			email[:to] = "support <#{@account.primary_email_config.to_email}>"
			Helpdesk::ProcessEmail.new(email).perform
			ticket_incremented?(@ticket_size)
		end

		it "from auto responders" do
			email = new_email({:email_config => @account.primary_email_config.to_email, :auto => true})
			Helpdesk::ProcessEmail.new(email).perform
			ticket_incremented?(@ticket_size)
			recent_ticket = @account.tickets.last
			recent_ticket.skip_notification.should eql true
		end

		it "with cc email" do
			cc_email = Faker::Internet.email
			email = new_email({:email_config => @account.primary_email_config.to_email, :include_cc => cc_email})
			Helpdesk::ProcessEmail.new(email).perform
			ticket_incremented?(@ticket_size)
			recent_ticket = @account.tickets.last
			recent_ticket.cc_email_hash[:reply_cc].should eql recent_ticket.cc_email_hash[:cc_emails]
		end

		it "from email_config to kbase" do
			email = new_email({:email_config => @account.kbase_email, :reply => @account.primary_email_config.reply_email, :include_cc => @account.kbase_email})
			Helpdesk::ProcessEmail.new(email).perform
			solutions_incremented?(@article_size)
		end
    
	    after(:all) do
	      restore_default_feature("reply_to_based_tickets")
	    end
	end

	describe "Create article" do
    
    before(:all) do
      before_all_call
    end
  
		it "once by email" do
			email = new_email({:email_config => @account.kbase_email, :reply => @agent.user.email})
			email[:from] = @agent.user.email
			Helpdesk::ProcessEmail.new(email).perform
			solutions_incremented?(@article_size)
		end

		it "article failure - non agent" do
			email = new_email({:email_config => @account.kbase_email})
			Helpdesk::ProcessEmail.new(email).perform
			@account.reload
			@account.solution_articles.size.should eql @article_size
		end

		it "with inline attachments" do
			email = new_email({:email_config => @account.kbase_email, :reply => @agent.user.email, :attachments => 1, :inline => 1})
			email[:html] = email[:html] + "<img src=\"#{content_id}\" alt=\"Inline image 1\"><br>"
			email[:from] = @agent.user.email
			Helpdesk::ProcessEmail.new(email).perform
			solution = Solution::Article.last
			solutions_incremented?(@article_size)
			solution.attachments.size.should eql 1
		end
    
    after(:all) do
      restore_default_feature("reply_to_based_tickets")
    end
	end

	describe "Create Note" do
    
    before(:all) do
      before_all_call
    end
    
		it "by ticket id" do
			email_id = Faker::Internet.email
			email = new_email({:email_config => @account.primary_email_config.to_email, :reply => email_id})
			another = new_email({:email_config => @account.primary_email_config.to_email, :reply => email_id})
			Helpdesk::ProcessEmail.new(email).perform
			ticket = @account.tickets.last
			another[:subject] = another[:subject]+" [##{ticket.display_id}]"
			Helpdesk::ProcessEmail.new(another).perform
			ticket_incremented?(@ticket_size)
			@account.notes.last.notable.id.should eql ticket.id
		end

		it "with attachments above 15 mb ticket id" do
			email_id = Faker::Internet.email
			email = new_email({:email_config => @account.primary_email_config.to_email, :reply => email_id})
			another = new_email({:email_config => @account.primary_email_config.to_email, :attachments => 1, :large => 1, :reply => email_id})
			Helpdesk::ProcessEmail.new(email).perform
			ticket = @account.tickets.last
			another[:subject] = another[:subject]+" [##{ticket.display_id}]"
			Helpdesk::ProcessEmail.new(another).perform
			ticket_incremented?(@ticket_size)
			@account.notes.last.notable.id.should eql ticket.id
			@account.notes.last.attachments.size.should eql 0
		end

		it "by blocked user" do
			user1 = add_new_user(@account)
			email = new_email({:email_config => @account.primary_email_config.to_email, :reply => user1.email})
			another = new_email({:email_config => @account.primary_email_config.to_email, :reply => user1.email})
			Helpdesk::ProcessEmail.new(email).perform
			ticket = @account.tickets.last
			user1.blocked = true
			user1.save
			another[:subject] = another[:subject]+" [##{ticket.display_id}]"
			Helpdesk::ProcessEmail.new(another).perform
			ticket_incremented?(@ticket_size)
		end

		it "with email_commands" do
			email = new_email({:email_config => @account.primary_email_config.to_email})
			Helpdesk::ProcessEmail.new(email).perform
			ticket = @account.tickets.last
			another = new_email({:email_config => @account.primary_email_config.to_email, :reply => @agent.user.email})
			another[:subject] = another[:subject]+" [##{ticket.display_id}]"
			another[:from] = @agent.user.email
			another[:text] = %(\n#{@account.email_cmds_delimeter} "priority":"medium" #{@account.email_cmds_delimeter} \n)+email[:text]
			another[:html] = %(\n#{@account.email_cmds_delimeter} "priority":"medium" #{@account.email_cmds_delimeter} \n)+email[:html]
			Helpdesk::ProcessEmail.new(another).perform
			ticket = @account.tickets.last
			ticket_incremented?(@ticket_size)
			@account.notes.size.should eql @note_size+1
			ticket.priority.should eql 2
		end

		it "by span" do
			email_id = Faker::Internet.email
			email = new_email({:email_config => @account.primary_email_config.to_email, :reply => email_id})
			another = new_email({:email_config => @account.primary_email_config.to_email, :reply => email_id})
			Helpdesk::ProcessEmail.new(email).perform
			ticket = @account.tickets.last
			another[:html] = another[:html]+" #{span_gen(ticket.display_id)} "+another[:html]
			Helpdesk::ProcessEmail.new(another).perform
			ticket_incremented?(@ticket_size)
			@account.notes.size.should eql @note_size+1
			ticket.notes.size.should eql 1
		end 

		it "by style span" do
			email_id = Faker::Internet.email
			email = new_email({:email_config => @account.primary_email_config.to_email, :reply => email_id})
			another = new_email({:email_config => @account.primary_email_config.to_email, :reply => email_id})
			Helpdesk::ProcessEmail.new(email).perform
			ticket = @account.tickets.last
			another[:html] = another[:html]+" #{style_span_gen(ticket.display_id)} "+another[:html]
			Helpdesk::ProcessEmail.new(another).perform
			ticket_incremented?(@ticket_size)
			@account.notes.size.should eql @note_size+1
			ticket.notes.size.should eql 1
		end

		it "by header" do
			email_id = Faker::Internet.email
			email = new_email({:email_config => @account.primary_email_config.to_email, :reply => email_id})
			another = new_email({:email_config => @account.primary_email_config.to_email, :m_id => get_m_id(email[:headers]), :reply => email_id})
			Helpdesk::ProcessEmail.new(email).perform
			ticket = @account.tickets.last
			Helpdesk::ProcessEmail.new(another).perform
			ticket_incremented?(@ticket_size)
			@account.notes.size.should eql @note_size+1
			ticket.notes.size.should eql 1
		end

		it "from cc" do
			email_id = Faker::Internet.email
			email = new_email({:email_config => @account.primary_email_config.to_email, :include_cc => email_id})
			another = new_email({:email_config => @account.primary_email_config.to_email, :reply => email_id})
			Helpdesk::ProcessEmail.new(email).perform
			ticket = @account.tickets.last
			another[:html] = another[:html]+" #{span_gen(ticket.display_id)} "+another[:html]
			Helpdesk::ProcessEmail.new(another).perform
			ticket_incremented?(@ticket_size)
			@account.notes.size.should eql @note_size+1
			ticket.notes.size.should eql 1
		end

		it "from same company" do
			email = new_email({:email_config => @account.primary_email_config.to_email, :reply => "sample1@#{@comp.domains}"})
			another = new_email({:email_config => @account.primary_email_config.to_email, :reply => "sample2@#{@comp.domains}"})
			Helpdesk::ProcessEmail.new(email).perform
			ticket = @account.tickets.last
			another[:html] = another[:html]+" #{span_gen(ticket.display_id)} "+another[:html]
			Helpdesk::ProcessEmail.new(another).perform
			ticket_incremented?(@ticket_size)
			@account.notes.size.should eql @note_size+1
			ticket.notes.size.should eql 1
		end

		it "from to" do
			email_id = Faker::Internet.email
			email = new_email({:email_config => @account.primary_email_config.to_email, :include_to => email_id})
			another = new_email({:email_config => @account.primary_email_config.to_email, :reply => email_id})
			Helpdesk::ProcessEmail.new(email).perform
			ticket = @account.tickets.last
			another[:html] = another[:html]+" #{span_gen(ticket.display_id)} "+another[:html]
			Helpdesk::ProcessEmail.new(another).perform
			ticket_incremented?(@ticket_size)
			@account.notes.size.should eql @note_size+1
			ticket.notes.size.should eql 1
		end

		it "by agent" do
			email_id = @agent.user.email
			email = new_email({:email_config => @account.primary_email_config.to_email, :include_cc => email_id})
			another = new_email({:email_config => @account.primary_email_config.to_email, :reply => email_id})
			Helpdesk::ProcessEmail.new(email).perform
			ticket = @account.tickets.last
			another[:html] = another[:html]+" #{span_gen(ticket.display_id)} "+another[:html]
			Helpdesk::ProcessEmail.new(another).perform
			ticket_incremented?(@ticket_size)
			@account.notes.size.should eql @note_size+1
			ticket.notes.size.should eql 1
		end

		it "with quoted text" do
			email_id = Faker::Internet.email
			email = new_email({:email_config => @account.primary_email_config.to_email, :include_cc => email_id})
			another = new_email({:email_config => @account.primary_email_config.to_email, :reply => email_id})
			Helpdesk::ProcessEmail.new(email).perform
			ticket = @account.tickets.last
			another[:html] = another[:html]+"----original message----"+another[:html]+" #{span_gen(ticket.display_id)} "
			Helpdesk::ProcessEmail.new(another).perform
			ticket_incremented?(@ticket_size)
			@account.notes.size.should eql @note_size+1
			ticket.notes.size.should eql 1
		end

		it "for ticket without CC" do
			email = new_email({:email_config => @account.primary_email_config.to_email})
			Helpdesk::ProcessEmail.new(email).perform
			ticket = @account.tickets.first
			notes_count = ticket.notes.count
			@account.tickets.update_all(:cc_email => nil)
			another = new_email({:email_config => @account.primary_email_config.to_email, :reply => @agent.user.email})
			another[:subject] = another[:subject]+" [##{ticket.display_id}]"
			Helpdesk::ProcessEmail.new(another).perform
			ticket_incremented?(@ticket_size)
			@account.notes.size.should eql @note_size+1
			ticket.notes.count.should eql notes_count+1
		end

		it "as reply with new CC emails" do
			email_id = Faker::Internet.email
			new_to_email = Faker::Internet.email
			email = new_email({:email_config => @account.primary_email_config.to_email, :include_cc => email_id})
			first_reply = new_email({:email_config => @account.primary_email_config.to_email, :reply => email_id, :include_cc => new_to_email})
			Helpdesk::ProcessEmail.new(email).perform
			ticket = @account.tickets.last
			first_reply[:subject] = first_reply[:subject]+" [##{ticket.display_id}]"
			Helpdesk::ProcessEmail.new(first_reply).perform
			ticket_incremented?(@ticket_size)
			@account.tickets.last.cc_email_hash[:cc_emails].should include (new_to_email)
			@account.tickets.last.cc_email_hash[:reply_cc].should include (new_to_email)
		end

		it "as reply from a CC email" do
			email_id = Faker::Internet.email
			new_to_email = Faker::Internet.email
			email = new_email({:email_config => @account.primary_email_config.to_email, :include_cc => email_id})
			first_reply = new_email({:email_config => @account.primary_email_config.to_email, :reply => email_id, :include_cc => new_to_email})
			second_reply = new_email({:email_config => @account.primary_email_config.to_email, :reply => new_to_email})
			Helpdesk::ProcessEmail.new(email).perform
			ticket = @account.tickets.last
			first_reply[:subject] = first_reply[:subject]+" [##{ticket.display_id}]"
			second_reply[:subject] = second_reply[:subject]+" [##{ticket.display_id}]"
			Helpdesk::ProcessEmail.new(first_reply).perform
			Helpdesk::ProcessEmail.new(second_reply).perform
			ticket_incremented?(@ticket_size)
			@account.notes.size.should eql @note_size+2
			ticket.notes.size.should eql 2
		end

		it "by secondary email" do
			@key_state = mue_key_state(@account)
    		enable_mue_key(@account)
    		@account.features.multiple_user_emails.create
    		@account.features.contact_merge_ui.create
    		@account.reload
    		@account.features.reload
    		@user1 = add_user_with_multiple_emails(@account, 2)
			email_id = @user1.email
			email = new_email({:email_config => @account.primary_email_config.to_email, :reply => email_id})
			another = new_email({:email_config => @account.primary_email_config.to_email, :reply => @user1.user_emails.last.email})
			Helpdesk::ProcessEmail.new(email).perform
			ticket = @account.tickets.last
			another[:html] = another[:html]+" #{span_gen(ticket.display_id)} "+another[:html]
			Helpdesk::ProcessEmail.new(another).perform
			ticket_incremented?(@ticket_size)
			@account.notes.size.should eql @note_size+1
			ticket.notes.size.should eql 1
			@account.features.contact_merge_ui.destroy
			@account.features.multiple_user_emails.destroy
			disable_mue_key(@account) unless @key_state
		end

		it "with cc removed from reply" do
			email_id = Faker::Internet.email
			cc_email = Faker::Internet.email
			new_cc_email = Faker::Internet.email
			email = new_email({:email_config => @account.primary_email_config.to_email, :reply => email_id})
			first_reply = new_email({:email_config => @account.primary_email_config.to_email, :reply => email_id, :include_cc => cc_email})
			second_reply = new_email({:email_config => @account.primary_email_config.to_email, :reply => email_id, :include_cc => new_cc_email})
			Helpdesk::ProcessEmail.new(email).perform
			ticket = @account.tickets.last
			first_reply[:subject] = first_reply[:subject]+" [##{ticket.display_id}]"
			second_reply[:subject] = second_reply[:subject]+" [##{ticket.display_id}]"
			Helpdesk::ProcessEmail.new(first_reply).perform
			Helpdesk::ProcessEmail.new(second_reply).perform
			ticket_incremented?(@ticket_size)
			latest_ticket = @account.tickets.last
			latest_ticket.cc_email_hash[:reply_cc].should include new_cc_email
			latest_ticket.cc_email_hash[:reply_cc].should_not include cc_email
		end

		it "with Ticket cc present in reply cc when he replies" do
			email_id = Faker::Internet.email
			cc_email = Faker::Internet.email
			new_cc_email = Faker::Internet.email
			email = new_email({:email_config => @account.primary_email_config.to_email, :reply => email_id})
			first_reply = new_email({:email_config => @account.primary_email_config.to_email, :reply => email_id, :include_cc => cc_email})
			second_reply = new_email({:email_config => @account.primary_email_config.to_email, :reply => cc_email, :include_cc => new_cc_email})
			Helpdesk::ProcessEmail.new(email).perform
			ticket = @account.tickets.last
			first_reply[:subject] = first_reply[:subject]+" [##{ticket.display_id}]"
			second_reply[:subject] = second_reply[:subject]+" [##{ticket.display_id}]"
			Helpdesk::ProcessEmail.new(first_reply).perform
			Helpdesk::ProcessEmail.new(second_reply).perform
			ticket_incremented?(@ticket_size)
			latest_ticket = @account.tickets.last
			latest_ticket.cc_email_hash[:reply_cc].should include new_cc_email
			latest_ticket.cc_email_hash[:reply_cc].should include cc_email
		end
	end
  
  
  def before_all_call
    @agent = add_agent_to_account(@account, {:name => "Harry Potter", :email => Faker::Internet.email, :active => true})
		clear_email_config
		@comp = create_company
		restore_default_feature("reply_to_based_tickets")
  end

end