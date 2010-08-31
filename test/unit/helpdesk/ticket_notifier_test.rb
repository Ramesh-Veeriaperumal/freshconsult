require 'test_helper'

class Helpdesk::TicketNotifierTest < ActionMailer::TestCase
  tests Helpdesk::TicketNotifier

  include MailFixture

  context "New ticket" do

    setup do 
      Helpdesk::EMAIL[:from] = "helpkit_test@chatspring.com"
      @ticket = Helpdesk::Ticket.new 
      @ticket.expects(:encode_id_token).returns("[xxx]")
      @ticket.expects(:email).returns("test@email.com")
      @ticket.expects(:id_token).at_least_once.returns("abcdefg")
      @ticket.expects(:access_token).returns("access")
    end

    should "send reply" do
      note = mock
      note.expects(:attachments).times(2).returns([])
      note.expects(:body).returns("note body")
      Helpdesk::TicketNotifier.deliver_reply(@ticket, note)
      assert_sent_email do |email|
        (email.body.include? "note body") &&
        (email.subject == Helpdesk::EMAIL[:reply_subject] + " [xxx]") &&
        (email.to.include? "test@email.com")
      end
    end

    should "send autoreply" do
      note = mock
      note.expects(:body).returns("My initial request")
      @ticket.expects(:notes).returns([note])
      Helpdesk::TicketNotifier.deliver_autoreply(@ticket)
      assert_sent_email do |email|
        (email.body.include? "My initial request") &&
        (email.subject == Helpdesk::EMAIL[:reply_subject] + " [xxx]") &&
        (email.to.include? "test@email.com")
      end
    end
  end


  context "incoming email, no ticket id in subject" do
    setup do
      raw = read_fixture('new_ticket.mail')
      Helpdesk::TicketNotifier.receive(raw)
      @email = TMail::Mail.parse(raw)
      @media = MMS2R::Media.new(@email)
      @ticket = Helpdesk::Ticket.last
    end

    should "have correct subject" do
      assert_equal "This is a test", @email.subject
      assert_equal "This is a test", @media.subject
    end

    should_change "Helpdesk::Ticket.count", :by => 1
    should_change "Helpdesk::Note.count", :by => 1

    should "set ticket.description to email subject" do
      assert_equal "This is a test", @ticket.description
    end
  
    should "set ticket.note.body to email body" do
      assert_equal @media.body, @ticket.notes.first.body
    end

    should "set correct note source, incomins and private values" do
      assert @ticket.notes.first.incoming
      assert !@ticket.notes.first.private
      assert_equal 0, @ticket.notes.first.source
    end

    should "send autoreply" do 
      assert_sent_email do |email|
        (email.body.include? @media.body) &&
        (email.subject == Helpdesk::EMAIL[:reply_subject] + " #{@ticket.encode_id_token}") &&
        (email.to.include? @ticket.email)
      end
    end
  end

  context "Existing ticket" do
    setup do
      Helpdesk::EMAIL[:from] = "helpkit_test@chatspring.com"
      @ticket = Helpdesk::Ticket.create(
        :id_token => '9f89e26017eb79b6ed48e68924681cce',
        :access_token => '9f89e26017eb79b6ed48e68924681cce',
        :name => "Starr Horne",
        :email => "snhorne@gmail.com",
        :status => Helpdesk::Ticket::STATUS_KEYS_BY_TOKEN[:solved]
      )
    end

    context "incoming email, valid ticket id in subject" do
      setup do
        raw = read_fixture('reply.mail')
        Helpdesk::TicketNotifier.receive(raw)
        @email = TMail::Mail.parse(raw)
        @media = MMS2R::Media.new(@email)
        @ticket.reload
      end

      should "have correct subject" do
        re = /.*\[#{@ticket.id_token}\]/
        assert_match re, @email.subject 
        assert_match re, @media.subject
      end

      should_not_change "Helpdesk::Ticket.count"

      # 2 notes created. 1) incoming email. 2) "ticket reopened" status note
      should_change "Helpdesk::Note.count", :by => 2
      should_change "@ticket.notes.count", :by => 2

      should_not_change "@ticket.description"

      should "set ticket.note.body to email body" do
        assert_equal @media.body, @ticket.notes.last.body
      end

      should "set correct note source, incomins and private values" do
        assert @ticket.notes.last.incoming
        assert !@ticket.notes.last.private
        assert_equal 0, @ticket.notes.last.source
      end

      should "not send autoreply" do 
        assert_did_not_send_email
      end

      should "set ticket status to open" do 
        assert_equal Helpdesk::Ticket::STATUS_KEYS_BY_TOKEN[:open], @ticket.status
      end

      should "create note indicating that ticket was reopened" do 
        @note = @ticket.notes[-2]
        assert_equal "Ticket was reopened due to customer email.", @note.body
        assert !@note.user
        assert @note.status?
      end

    end

    context "incoming bounced email, valid ticket id in body" do
      setup do
        raw = read_fixture('bounce.mail')
        Helpdesk::TicketNotifier.receive(raw)
        @email = TMail::Mail.parse(raw)
        @media = MMS2R::Media.new(@email)
        @ticket.reload
      end

      should "have correct subject" do
        re = /.*\[#{@ticket.id_token}\]/
        assert_no_match re, @email.subject 
        assert_no_match re, @media.subject
      end

      should_not_change "Helpdesk::Ticket.count"

      # 2 notes created. 1) incoming email. 2) "ticket reopened" status note
      should_change "Helpdesk::Note.count", :by => 2
      should_change "@ticket.notes.count", :by => 2

      should_not_change "@ticket.description"

      should "set ticket.note.body to email body" do
        assert_equal @media.body, @ticket.notes.last.body
      end

      should "set correct note source, incomins and private values" do
        assert @ticket.notes.last.incoming
        assert !@ticket.notes.last.private
        assert_equal 0, @ticket.notes.last.source
      end

      should "not send autoreply" do 
        assert_did_not_send_email
      end

      should "set ticket status to open" do 
        assert_equal Helpdesk::Ticket::STATUS_KEYS_BY_TOKEN[:open], @ticket.status
      end

      should "create note indicating that ticket was reopened" do 
        @note = @ticket.notes[-2]
        assert_equal "Ticket was reopened due to customer email.", @note.body
        assert !@note.user
        assert @note.status?
      end
    end
  end


  context "incoming email, invalid ticket id in subject" do
    setup do
      raw = read_fixture('reply.mail')
      Helpdesk::TicketNotifier.receive(raw)
      @email = TMail::Mail.parse(raw)
      @media = MMS2R::Media.new(@email)
      @ticket = Helpdesk::Ticket.last
    end

    should_change "Helpdesk::Ticket.count", :by => 1
    should_change "Helpdesk::Note.count", :by => 1

    should "set ticket.description to email subject" do
      assert_equal @email.subject, @ticket.description
    end
  
    should "set ticket.note.body to email body" do
      assert_equal @media.body, @ticket.notes.first.body
    end

    should "set correct note source, incomins and private values" do
      assert @ticket.notes.first.incoming
      assert !@ticket.notes.first.private
      assert_equal 0, @ticket.notes.first.source
    end

    should "send autoreply" do 
      assert_sent_email do |email|
        (email.body.include? @media.body) &&
        (email.subject == Helpdesk::EMAIL[:reply_subject] + " #{@ticket.encode_id_token}") &&
        (email.to.include? @ticket.email)
      end
    end
  end


  context "incoming bounced email, invalid ticket id in body" do
    setup do
      raw = read_fixture('bounce.mail')
      Helpdesk::TicketNotifier.receive(raw)
      @email = TMail::Mail.parse(raw)
      @media = MMS2R::Media.new(@email)
      @ticket = Helpdesk::Ticket.last
    end

    should_change "Helpdesk::Ticket.count", :by => 1
    should_change "Helpdesk::Note.count", :by => 1

    should "set ticket.description to email subject" do
      assert_equal @email.subject, @ticket.description
    end
  
    should "set ticket.note.body to email body" do
      assert_equal @media.body, @ticket.notes.first.body
    end

    should "set correct note source, incomins and private values" do
      assert @ticket.notes.first.incoming
      assert !@ticket.notes.first.private
      assert_equal 0, @ticket.notes.first.source
    end

    should "send autoreply" do 
      assert_sent_email do |email|
        (email.body.include? @media.body) &&
        (email.subject == Helpdesk::EMAIL[:reply_subject] + " #{@ticket.encode_id_token}") &&
        (email.to.include? @ticket.email)
      end
    end
  end


end
