require_relative '../../test_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!

class Ember::ProductFeedbackControllerTest < ActionController::TestCase
  include TicketConstants

  # test cases
  def test_create_global_feedback_with_given_description
    params_hash = { description: Faker::Lorem.paragraph }
    post :create, construct_params(params_hash)
    assert_response 204
  end

  def test_create_global_feedback_with_empty_description
    params_hash = { something: Faker::Lorem.paragraph, description: '' }
    post :create, construct_params(params_hash)
    assert_response 400
  end

  def test_create_global_feedback_with_desc_and_attachments
    attachments = []
    rand(2..10).times do
      attachments << rand(1_000_000)
    end
    params_hash = { description: Faker::Lorem.paragraph, attachment_ids: attachments }
    post :create, construct_params(params_hash)
    assert_response 204
  end

  def test_create_global_feedback_with_desc_and_invalid_attachments
    attachments = []
    rand(2..10).times do
      attachments << rand(1_000_000)
    end
    attachments << Faker::Lorem.word
    params_hash = { description: Faker::Lorem.paragraph, attachment_ids: attachments }
    post :create, construct_params(params_hash)
    assert_response 400
  end

  def test_create_global_feedback_with_subject
    attachments = []
    rand(2..10).times do
      attachments << rand(1_000_000)
    end
    params_hash = { description: Faker::Lorem.paragraph, attachment_ids: attachments, subject: Faker::Lorem.paragraph }
    post :create, construct_params(params_hash)
    assert_response 204
  end

  def test_create_global_feedback_with_invalid_subject
    attachments = []
    rand(2..10).times do
      attachments << rand(1_000_000)
    end
    params_hash = { description: Faker::Lorem.paragraph, attachment_ids: attachments, subject: rand(1_000_000) }
    post :create, construct_params(params_hash)
    assert_response 400
  end

  def test_create_global_feedback_with_tags
    attachments = []
    rand(2..10).times do
      attachments << rand(1_000_000)
    end
    tags = []
    rand(2..10).times do
      tags << Faker::Lorem.word
    end
    params_hash = { description: Faker::Lorem.paragraph, attachment_ids: attachments, subject: Faker::Lorem.paragraph, tags: tags }
    post :create, construct_params(params_hash)
    assert_response 204
  end

  def test_create_global_feedback_with_invalid_tags
    attachments = []
    rand(2..10).times do
      attachments << rand(1_000_000)
    end
    tags = []
    rand(2..10).times do
      tags << Faker::Lorem.word
    end
    tags << rand(1_000_000)
    params_hash = { description: Faker::Lorem.paragraph, attachment_ids: attachments, subject: Faker::Lorem.paragraph, tags: tags }
    post :create, construct_params(params_hash)
    assert_response 400
  end

  def test_create_global_feedback_pushes_job_to_sidekiq
    ProductFeedbackWorker.clear
    assert_equal 0, ProductFeedbackWorker.jobs.size
    params_hash = { description: Faker::Lorem.paragraph }
    n = rand(1..10)
    n.times do
      ProductFeedbackWorker.perform_async(params_hash)
    end
    assert_equal n, ProductFeedbackWorker.jobs.size
    ProductFeedbackWorker.clear
    assert_equal 0, ProductFeedbackWorker.jobs.size
  end
  # end of test cases
end
