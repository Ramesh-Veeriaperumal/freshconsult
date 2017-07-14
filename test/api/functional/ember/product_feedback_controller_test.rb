require_relative '../../test_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!

class Ember::ProductFeedbackControllerTest < ActionController::TestCase
  include TicketConstants

  # various params
  def params_hash_with_correct_feedback
    params_hash = { description: Faker::Lorem.paragraph }
  end

  def params_hash_with_empty_description
    params_hash = { something: Faker::Lorem.paragraph, description: '' }
  end

  # test cases
  # def test_create_global_feedback_with_given_description
  #   post :create, construct_params(params_hash_with_correct_feedback)
  #   assert_response 204
  # end
  # commenting for now. Will be fixed in next release. Need to stub constants.

  def test_create_global_feedback_with_empty_description
    post :create, construct_params(params_hash_with_empty_description)
    assert_response 400
  end
  # end of test cases
end
