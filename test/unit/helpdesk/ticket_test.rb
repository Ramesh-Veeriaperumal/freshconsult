require 'test_helper'

class Helpdesk::TicketTest < ActiveSupport::TestCase
  should_belong_to :responder, :requester
  should_have_many :notes, :reminders, :subscriptions, :tag_uses
  should_have_many :tags, :through => :tag_uses
  should_have_named_scope :visible
  should_have_class_methods :find_by_param, :filter, :search, :extract_id_token
  should_have_instance_methods :freshness, :status=, :status_name, :source=, :source_name, :nickname, :encode_id_token, :train, :classifier
  should_have_index :requester_id, :responder_id, :id_token
  should_validate_presence_of :name, :source, :status
  should_ensure_length_in_range :email, (5..320) 
  should_validate_numericality_of :status, :source, :requester_id, :responder_id
  should_ensure_value_in_range :source, (0..Helpdesk::Ticket::SOURCES.size - 1) 
  should_ensure_value_in_range :status, (Helpdesk::Ticket::STATUS_KEYS_BY_TOKEN.values.min..Helpdesk::Ticket::STATUS_KEYS_BY_TOKEN.values.max)
  should_allow_values_for :email, "bob@email.com", "joe.joe@joe.com", "rolf@aldun.nl", "a@r.se", "james@one.two.three.com"
  should_not_allow_values_for :email, "bob@notld", "bob jones@bill.com", "billy@jo ey.com", "name@com"

  should "Have required contants" do
    assert Helpdesk::Ticket::STATUSES
    assert Helpdesk::Ticket::STATUS_OPTIONS
    assert Helpdesk::Ticket::STATUS_NAMES_BY_KEY
    assert Helpdesk::Ticket::STATUS_KEYS_BY_TOKEN
    assert Helpdesk::Ticket::SOURCES
    assert Helpdesk::Ticket::SOURCE_OPTIONS
    assert Helpdesk::Ticket::SOURCE_NAMES_BY_KEY
    assert Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN
    assert Helpdesk::Ticket::SEARCH_FIELDS
    assert Helpdesk::Ticket::SEARCH_FIELD_OPTIONS
    assert Helpdesk::Ticket::SORT_FIELDS
    assert Helpdesk::Ticket::SORT_FIELD_OPTIONS
    assert Helpdesk::Ticket::SORT_SQL_BY_KEY
  end

  context "given an existing record" do 
    setup do 
      @ticket = Helpdesk::Ticket.new 
      @sources = Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN
      @statuses = Helpdesk::Ticket::STATUS_KEYS_BY_TOKEN
      @sample_id_token = "x" * 32
    end

    should "return id_token as to_param" do
      @ticket.expects(:id_token).returns(:some_token)
      assert_equal :some_token, @ticket.to_param
    end

    should "allow source to be set by symbol" do
      @sources.each do |s, n|
        @ticket.source = s
        assert_equal @ticket.source, n
      end
    end

    should "allow source to be set by numeric value" do
      @sources.each do |s, n|
        @ticket.source = n
        assert_equal @ticket.source, n
      end
    end

    should "return source name when ticket.source_name called" do
      @sources.each do |s, n|
        @ticket.source = n
        assert_equal @ticket.source_name, Helpdesk::Ticket::SOURCE_NAMES_BY_KEY[n]
      end
    end

    should "allow status to be set by symbol" do
      @statuses.each do |s, n|
        @ticket.status = s
        assert_equal @ticket.status, n
      end
    end

    should "allow status to be set by numeric value" do
      @statuses.each do |s, n|
        @ticket.status = n
        assert_equal @ticket.status, n
      end
    end

    should "return status name when ticket.status_name called" do
      @statuses.each do |s, n|
        @ticket.status = n
        assert_equal @ticket.status_name, Helpdesk::Ticket::STATUS_NAMES_BY_KEY[n]
      end
    end


    should "return ticket.name ticket.nickname called" do
      assert_equal @ticket.name, @ticket.nickname
    end

    should "return the ticket's id_token, encoded for use in email subject" do
      @ticket.id_token = @sample_id_token
      assert_equal @ticket.encode_id_token, "[#{@sample_id_token}]"
    end

    should "Extract an id_token from an email subject" do
      [
        "Re: Support request [#{@sample_id_token}]",
        "Re: Support request[#{@sample_id_token}]",
        "Re: [fakeout] request[#{@sample_id_token}]",
        "[#{@sample_id_token}] Try it in front",
        "[#{@sample_id_token}][#{@sample_id_token}][#{@sample_id_token}]"
      ].each { |s| assert_equal(Helpdesk::Ticket.extract_id_token(s), @sample_id_token) }
    end

    should "Return spam classifier when ticket.classifier called" do
      Helpdesk::Classifier.expects(:find_by_name).with('spam').returns(:spamfilter)
      assert_equal @ticket.classifier, :spamfilter
    end

    should "Return Ticket.all if Ticket.filter passed invalid filter name" do
      assert_equal Helpdesk::Ticket.filter([:not_a_filter]), Helpdesk::Ticket.all
    end

    should "Ignore invalid filters when a valid filter name is passed in to Ticket.filter" do
      assert_equal(
        Helpdesk::Ticket.filter([:open, :not_a_filter]), 
        Helpdesk::Ticket.filter([:open]) 
      )

      assert_equal(
        Helpdesk::Ticket.filter([:not_a_filter, :open]), 
        Helpdesk::Ticket.filter([:open]) 
      )
    end

    should "Return appropriate tickets when Ticket.filter called" do

      {
        [:all]                => "",
        [:open]               => "status > 0",
        [:unassigned]         => {:responder_id => nil, :deleted => false, :spam => false},
        [:spam]               => {:spam => true},
        [:deleted]            => {:deleted => true},
        [:visible]            => {:deleted => false, :spam => false},
        [:all, :visible]      => {:deleted => false, :spam => false},
        [:all, :open]         => "status > 0",
        [:spam, :deleted]     => {:deleted => true, :spam => true},
        [:open, :unassigned]  => ["status > 0 AND responder_id IS NULL AND deleted = ? AND spam = ?", false, false]

      }.each do |f, c|
        assert_equal(
          Helpdesk::Ticket.filter(f), 
          Helpdesk::Ticket.find(:all, :conditions => c)
        )
      end

    end

    should "return tickets responded to by a particular user " do
      user = User.new
      user.expects(:id).returns(1)
      assert_equal(
        Helpdesk::Ticket.filter([:responded_by], user),
        Helpdesk::Ticket.find(:all, :conditions => {:responder_id => 1, :deleted => false, :spam => false})
      )
    end

    should "return tickets monitored by a particular user " do
      user = User.new
      user.expects(:id).returns(1)
      user.expects(:subscribed_tickets).returns(Helpdesk::Ticket)

      assert_equal(
        Helpdesk::Ticket.filter([:monitored_by], user),
        Helpdesk::Ticket.find(:all, :conditions => {:deleted => false, :spam => false})
      )
    end

    should "perform search on all loose match felds" do
      [:name, :phone, :email, :description].each do |f|
        Helpdesk::Ticket.expects(:scoped).with(:conditions => ["#{f} like ?", "%x%"]).returns(f)
        assert_equal Helpdesk::Ticket.search(Helpdesk::Ticket, f, 'x'), f
      end
    end


    should "perform search on all exact match felds" do
      [:status, :source].each do |f|
        Helpdesk::Ticket.expects(:scoped).with(:conditions => {f => 1}).returns(f)
        assert_equal Helpdesk::Ticket.search(Helpdesk::Ticket, f, 1), f
      end
    end


    should "return description as spam_text" do
      @ticket.expects(:notes).returns([])
      @ticket.expects(:description).returns("xxx")
      assert_equal @ticket.spam_text, "xxx"
    end

    should "return first note's body as spam_text" do
      note = Helpdesk::Note.new
      note.expects(:body).returns("yyy")
      notes = mock
      notes.expects(:find).with(:first).returns(note)
      notes.expects(:empty?).returns(false)
      @ticket.stubs(:notes).returns(notes)
      assert_equal @ticket.spam_text, "yyy"
    end

    should "return 32 bit alphanumeric token" do
      20.times { assert_match /[0-9a-z]{32}/, @ticket.make_token('') }
    end

    should "set id and access tokens" do
      @ticket.id_token = nil
      @ticket.access_token = nil
      @ticket.set_tokens
      assert_match /[0-9a-z]{32}/, @ticket.id_token
      assert_match /[0-9a-z]{32}/, @ticket.access_token
    end

    context "classifier mocked for retraining spam filter" do
      setup do
        @classifier = mock
        @classifier.expects(:save)
        @ticket.stubs(:trained).returns(true)
        @ticket.stubs(:classifier).returns(@classifier)
        @ticket.stubs(:spam_text).returns("text")
      end

      should "untrain spam if train(:ham) called when @ticket.trained = true and @ticket.spam = true" do
        @classifier.expects(:untrain).with(:spam, "text")
        @classifier.expects(:train).with(:ham, "text")
        @ticket.expects(:spam).returns(true)
        @ticket.train(:ham)
      end


      should "untrain ham if train(:spam) called when @ticket.trained = true and @ticket.spam = false" do
        @classifier.expects(:untrain).with(:ham, "text")
        @classifier.expects(:train).with(:spam, "text")
        @ticket.expects(:spam).returns(false)
        @ticket.train(:spam)
      end
    end

    context "classifier mocked for initial training of spam filter" do
      setup do
        @classifier = mock
        @classifier.expects(:untrain).never
        @classifier.expects(:save)
        @ticket.stubs(:trained).returns(false)
        @ticket.stubs(:classifier).returns(@classifier)
        @ticket.stubs(:spam_text).returns("text")
        @ticket.expects(:spam).never
      end

      should "train spam if train(:spam) called when @ticket.trained = false" do
        @classifier.expects(:train).with(:spam, "text")
        @ticket.train(:spam)
      end


      should "train ham if train(:ham) called when @ticket.trained = false" do
        @classifier.expects(:train).with(:ham, "text")
        @ticket.train(:ham)
      end
    end


    should "return freshness = :new if the ticket is unassigned" do
      @ticket.expects(:responder).returns(nil)
      assert_equal @ticket.freshness, :new
    end

    should "return freshness = :closed if the status is <= 0" do
      0.downto(-10) do |i| 
        @ticket.expects(:responder).returns(true)
        @ticket.expects(:status).returns(i)
        assert_equal @ticket.freshness, :closed
      end
    end

    context "@ticket.notes mocked for @ticket.freshness method call" do 
      setup do
        @note = mock
        notes = mock
        notes.expects(:find_by_private).with(false, :order => 'created_at DESC').returns(@note)
        @ticket.expects(:notes).returns(notes)
        @ticket.expects(:responder).returns(true)
        @ticket.expects(:status).returns(1)
      end

      should "return freshness = :reply if the last public note was from the customer" do
        @note.expects(:incoming).returns(true)
        assert_equal :reply, @ticket.freshness
      end

      should "return freshness = :waiting if the last public note was from the staff" do
        @note.expects(:incoming).returns(false)
        assert_equal :waiting, @ticket.freshness
      end
    end
  end


  context "create a status note with user" do
    setup do
      @ticket = Helpdesk::Ticket.first
      @note = @ticket.create_status_note("some message", @user)
      @ticket.reload
    end

    should_change "Helpdesk::Note.count", :by => 1

    should "have saved note" do
      assert @note.id
      assert_equal @ticket.id, @note.notable_id
    end

    should "Set note source to 'status'" do
      assert @note.status?
    end

    should "Set user" do
      assert_equal @user, @note.user
    end

  end

  context "create a status note without user" do
    setup do
      @ticket = Helpdesk::Ticket.first
      @note = @ticket.create_status_note("some message")
      @ticket.reload
    end

    should_change "Helpdesk::Note.count", :by => 1

    should "have saved note" do
      assert @note.id
      assert_equal @ticket.id, @note.notable_id
    end

    should "Set note source to 'status'" do
      assert @note.status?
    end

    should "Set user" do
      assert !@note.user
    end

  end

end
