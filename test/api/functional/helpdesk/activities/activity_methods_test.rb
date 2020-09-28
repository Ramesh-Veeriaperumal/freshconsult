require_relative '../../../unit_test_helper'
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
['ticket_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
['users_test_helper.rb' ,'attachments_test_helper.rb'].each { |file| require "#{Rails.root}/test/api/helpers/#{file}" }

class ActivityMethodsTest < ActionView::TestCase
  include Helpdesk::Activities::ActivityMethods
  include AccountTestHelper
  include LoadInitializer
  include TicketHelper
  include UsersTestHelper

  
  def setup
    Rails.env.stubs(:test?).returns(false)
    load 'helpdesk/initializers/thrift.rb'
    super
    before_all
  end

  def before_all
    Account.stubs(:current).returns(StubAccount.new)
    @ticket = StubTicket.new
    @item = EmailDetailStub.new
    Rails.env.stubs(:test?).returns(false)
  end

  def teardown
    Account.unstub(:current)
    User.reset_current_user
    Rails.env.unstub(:test?)
  end

  def sample_activity
    []
  end

  def current_account # done
    StubAccount.new
  end

  def current_user
    @user
  end
  
  def params
    { "status_id":12313, "user_id": 123123, "ticket_id": 123123, "rule_id": 123123, "drop_email" =>'email'}
  end

  def params_fetch_activity_since
    {'since_id':'28/01/2019','limit':'20'}
  end

  def params_fetch_activity_before
    {'before_id':'29/01/2019','limit':'20'}
  end

  def head(params)
    'head'
  end

  def render_errors(error)
    error
  end

  class StubbedThriftBufferedTransport
    def open
    end

    def close
    end
  end

#for stubbing new activities
  class StubbedResponseResult
    def initialize(response,error_message=[])
      @resp = response
      @error_message = error_message
    end
    def ticket_data
      @resp
    end

    def members
      '{ "status_ids": 12313, "user_ids": 123123, "ticket_ids": 123123, "rule_ids": 123123, "note_ids": 12312}'
    end

    def error_message
      @error_message
    end
  end

#for stubbing fetch activities
  class StubbedWrongResponseResult
    def initialize(response)
      @resp = response
    end
    def ticket_data
      @resp
    end
    def each
      'act'
    end
    def kind
      3
    end
  end

  #errored_email_detail stub
  class EmailDetailStub
    def display_id
      1
    end

    def to_cc_emails
      'email'
    end

    def dynamodb_range_key
      1
    end
  end

  class StubSelect
    def select(params)
      return []
    end

    def preload(params)
      return StubSelect.new
    end

    def where(params)
      {}
    end
  end

  class StubAccount
    def technicians(tech_select=[])
      StubSelect.new
    end

    def falcon_ui_enabled(enabled)
      enabled
    end

    def launched?(params)

    end

    def id(id=1)
      id
    end

    def users
      []
    end

    def tickets
      StubTicket.new
    end

    def smtp_mailboxes
      false
    end

    def ticket_status_values_from_cache
      []
    end

    def account_va_rules
      StubTicket.new
    end

    def all_users
      StubSelect.new
    end

    def spam_email?
      'sdfs'
    end

    def new_survey_enabled?
      false
    end

    def premium_email?
      false
    end

    def disable_emails_enabled?
     true
    end
  end

  class StubTicket
    def display_id(t_id=1)
      t_id
    end

    def id(t_id=1)
      t_id
    end

    def facebook?
      false
    end

    def twitter?
      false
    end

    def select(params=nil)
      StubSelect.new
    end

    def notes
      StubSelect.new
    end
  end

  def test_suppression_list_alert
    Helpdesk::TicketNotifier.any_instance.stubs(:suppression_list_alert).returns('job')
    ActionView::Renderer.any_instance.stubs(:render).returns('')
    suppression_list_alert
    assert_equal response.status,200
  ensure
    ActionView::Renderer.any_instance.unstub(:render)
    Helpdesk::TicketNotifier.any_instance.unstub(:send_later)
  end

  def test_new_activities_outer_exception
    $activities_thrift_transport = StubbedThriftBufferedTransport.new
    stubbedResponse = StubbedResponseResult.new(sample_activity)
    ::HelpdeskActivities::TicketActivities::Client.any_instance.stubs(:get_activities).returns(stubbedResponse)
    response = new_activities(params_fetch_activity_since.slice(:since_id,:before_id,:tkt_activity), @ticket,:tkt_activity)
    assert_equal response, {:activity_list=>[]}
  ensure
    ::HelpdeskActivities::TicketActivities::Client.any_instance.unstub(:get_activities)
  end

  def test_fetch_activities_wrong
    $activities_thrift_transport = StubbedThriftBufferedTransport.new
    stubbedResponse = StubbedWrongResponseResult.new(sample_activity)
    ::HelpdeskActivities::TicketActivities::Client.any_instance.stubs(:get_activities).returns(stubbedResponse)
    response = fetch_activities(params_fetch_activity_since.slice(:since_id,:before_id,:limit), @ticket)
    assert_equal response, false
  ensure  
    ::HelpdeskActivities::TicketActivities::Client.any_instance.unstub(:get_activities)
  end

  def test_fetch_errored_email_wrong
    $activities_thrift_transport = StubbedThriftBufferedTransport.new
    stubbedResponse = StubbedResponseResult.new('')
    ::HelpdeskActivities::TicketActivities::Client.any_instance.stubs(:get_activities).returns(stubbedResponse)
    ActionView::Renderer.any_instance.stubs(:render).returns('')
    response = fetch_errored_email_details 
    ActionView::Renderer.any_instance.unstub(:render)
    assert_equal response[:error_code], "400"
  ensure 
    ::HelpdeskActivities::TicketActivities::Client.any_instance.unstub(:get_activities)
  end

  def test_new_activities_inner_exception
    Helpdesk::Activities::ActivityMethods.stubs(:filter_ticket_data).returns('act1')
    $activities_thrift_transport = StubbedThriftBufferedTransport.new
    stubbedResponse = StubbedResponseResult.new([StubbedWrongResponseResult.new('resp')])
    HelpdeskActivities::TicketActivities::Client.any_instance.stubs(:get_activities).returns(stubbedResponse)
    response = new_activities(params_fetch_activity_since.slice(:since_id,:before_id,:tkt_activity), @ticket,:tkt_activity,true)
    assert_equal response[:error_code], "400"
  ensure 
    Helpdesk::Activities::ActivityMethods.unstub
    HelpdeskActivities::TicketActivities::Client.any_instance.unstub(:get_activities)
  end

  def test_error_messages
    $activities_thrift_transport = StubbedThriftBufferedTransport.new
    stubbedResponse = StubbedResponseResult.new(sample_activity,'error')
    ::HelpdeskActivities::TicketActivities::Client.any_instance.stubs(:get_activities).returns(stubbedResponse)
    response = new_activities(params_fetch_activity_before.slice(:since_id,:before_id,:tkt_activity), @ticket,:tkt_activity)
    ActionView::Renderer.any_instance.stubs(:render).returns('')
    assert_equal response[:error_code], "400"
    response = fetch_errored_email_details 
    assert_equal response[:error_code], "400"
    response = fetch_activities(params_fetch_activity_before.slice(:since_id,:before_id,:limit), @ticket)
    assert_equal response,false
  ensure
    ::HelpdeskActivities::TicketActivities::Client.any_instance.unstub(:get_activities)
    ActionView::Renderer.any_instance.unstub(:render)
  end
end
