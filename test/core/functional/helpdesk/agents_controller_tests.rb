require_relative '../../test_helper'

class AgentsControllerTest < ActionController::TestCase
  include CoreUsersTestHelper
  include ControllerTestHelper

  def setup
    super
    login_admin
  end

  def test_email_trigger_valid
    count_of_delayed_jobs_before = Delayed::Job.count
    agent = add_test_agent
    agent.update_attributes(:email => Faker::Internet.email)
    assert_equal count_of_delayed_jobs_before+3, Delayed::Job.count

  end
  def test_email_trigger_same_email
    count_of_delayed_jobs_before = Delayed::Job.count
    agent = add_test_agent
    agent.update_attributes(:email => agent.email)
    assert_equal count_of_delayed_jobs_before, Delayed::Job.count
  end
  def test_email_trigger_capscase
    count_of_delayed_jobs_before = Delayed::Job.count
    agent = add_test_agent
    agent.update_attributes(:email => agent.email.capitalize)
    assert_equal count_of_delayed_jobs_before+1, Delayed::Job.count
  end 

end