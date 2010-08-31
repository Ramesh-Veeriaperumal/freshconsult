require 'test_helper'

class Helpdesk::IssueTest < ActiveSupport::TestCase
  should_belong_to :user, :owner
  should_have_many :notes, :ticket_issues
  should_have_many :tickets, :through => :ticket_issues
  should_have_named_scope :visible

  should_have_class_methods :filter, :search
  should_have_instance_methods :freshness, :status=, :status_name, :source=, :source_name, :nickname
  should_validate_presence_of :title, :description, :status
  should_validate_numericality_of :status, :user_id

  should "Have required contants" do
    assert Helpdesk::Issue::STATUSES
    assert Helpdesk::Issue::STATUS_OPTIONS
    assert Helpdesk::Issue::STATUS_NAMES_BY_KEY
    assert Helpdesk::Issue::STATUS_KEYS_BY_TOKEN
    assert Helpdesk::Issue::SEARCH_FIELDS
    assert Helpdesk::Issue::SEARCH_FIELD_OPTIONS
    assert Helpdesk::Issue::SORT_FIELDS
    assert Helpdesk::Issue::SORT_FIELD_OPTIONS
    assert Helpdesk::Issue::SORT_SQL_BY_KEY
  end

  context "given an existing record" do 
    setup do 
      @issue = Helpdesk::Issue.new 
      @statuses = Helpdesk::Issue::STATUS_KEYS_BY_TOKEN
      @sample_id_token = "x" * 32
    end

    should "allow status to be set by symbol" do
      @statuses.each do |s, n|
        @issue.status = s
        assert_equal @issue.status, n
      end
    end

    should "allow status to be set by numeric value" do
      @statuses.each do |s, n|
        @issue.status = n
        assert_equal @issue.status, n
      end
    end

    should "return status name when issue.status_name called" do
      @statuses.each do |s, n|
        @issue.status = n
        assert_equal @issue.status_name, Helpdesk::Issue::STATUS_NAMES_BY_KEY[n]
      end
    end

    should "return issue.title issue.nickname called" do
      assert_equal @issue.title, @issue.nickname
    end

    should "Return Issue.all if Issue.filter passed invalid filter name" do
      assert_equal Helpdesk::Issue.filter([:not_a_filter]), Helpdesk::Issue.all
    end

    should "Ignore invalid filters when a valid filter name is passed in to Issue.filter" do
      assert_equal(
        Helpdesk::Issue.filter([:open, :not_a_filter]), 
        Helpdesk::Issue.filter([:open]) 
      )

      assert_equal(
        Helpdesk::Issue.filter([:not_a_filter, :open]), 
        Helpdesk::Issue.filter([:open]) 
      )
    end

    should "Return appropriate issues when Issue.filter called" do
      {
        [:all]                => "",
        [:open]               => "status > 0",
        [:unassigned]         => {:owner_id => nil, :deleted => false},
        [:deleted]            => {:deleted => true},
        [:visible]            => {:deleted => false},
        [:all, :visible]      => {:deleted => false},
        [:all, :open]         => "status > 0",
        [:open, :unassigned]  => ["status > 0 AND owner_id IS NULL AND deleted = ?", false]
      }.each do |f, c|
        assert_equal(
          Helpdesk::Issue.filter(f), 
          Helpdesk::Issue.find(:all, :conditions => c)
        )
      end
    end

    should "return issues responded to by a particular user " do
      user = User.new
      user.expects(:id).returns(1)
      assert_equal(
        Helpdesk::Issue.filter([:responded_by], user),
        Helpdesk::Issue.find(:all, :conditions => {:owner_id => 1, :deleted => false})
      )
    end

    should "return freshness = :new if the issue is unassigned" do
      @issue.expects(:owner).returns(nil)
      assert_equal @issue.freshness, :new
    end

    should "return freshness = :closed if the status is <= 0" do
      0.downto(-10) do |i| 
        @issue.expects(:owner).returns(true)
        @issue.expects(:status).returns(i)
        assert_equal @issue.freshness, :closed
      end
    end

  end

  context "create a status note with user" do
    setup do
      @issue = Helpdesk::Issue.first
      @note = @issue.create_status_note("some message", @user)
      @issue.reload
    end

    should_change "Helpdesk::Note.count", :by => 1

    should "have saved note" do
      assert @note.id
      assert_equal @issue.id, @note.notable_id
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
      @issue = Helpdesk::Issue.first
      @note = @issue.create_status_note("some message")
      @issue.reload
    end

    should_change "Helpdesk::Note.count", :by => 1

    should "have saved note" do
      assert @note.id
      assert_equal @issue.id, @note.notable_id
    end

    should "Set note source to 'status'" do
      assert @note.status?
    end

    should "Set user" do
      assert !@note.user
    end

  end
end
