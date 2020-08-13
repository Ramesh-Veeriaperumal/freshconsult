# frozen_string_literal: true

require_relative '../../unit_test_helper'
require 'sidekiq/testing'
require 'faker'

Sidekiq::Testing.fake!

require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')

class CentralResyncWorkerTest < ActionView::TestCase
  include ::AccountTestHelper
  include CentralLib::CentralResyncHelper

  def setup
    super
    @account = Account.first || create_new_account
    Account.any_instance.stubs(:current).returns(@account)
    @account.make_current
  end

  def resync_args
    {
      model_name: 'Helpdesk::Ticket',
      source: Faker::Lorem.word,
      meta_info: { id: rand(1_000) },
      job_id: rand(1_000_000_000)
    }
  end

  def test_missing_params_for_sync_entity
    assert_raises(NoMethodError) do
      sync_entity(resync_args.except(:model_name))
    end
  end

  def test_number_of_jobs_pushed
    CentralPublisher::CentralReSyncWorker.clear
    ['Helpdesk::Ticket', 'Helpdesk::TicketField', 'Helpdesk::Note'].each do |model|
      args = resync_args
      args[:model_name] = model
      sync_entity(args)
      relation_with_account = model.constantize.new.relationship_with_account.to_sym
      assert_equal CentralPublisher::CentralReSyncWorker.jobs.size, @account.safe_send(relation_with_account).count
      CentralPublisher::CentralReSyncWorker.clear
    end
  end

  def test_verify_jobs_count_with_conditions
    model_with_conditions = {
      'Helpdesk::Ticket' => ["status = #{rand(1..5)}"],
      'Helpdesk::Note' => ["user_id = #{rand(1..5)}"]
    }
    CentralPublisher::CentralReSyncWorker.clear
    model_with_conditions.each do |model, condition|
      args = resync_args.merge(conditions: condition)
      args[:model_name] = model
      sync_entity(args)
      relation_with_account = model.constantize.new.relationship_with_account.to_sym
      assert_equal CentralPublisher::CentralReSyncWorker.jobs.size, @account.safe_send(relation_with_account).where(condition).count
      CentralPublisher::CentralReSyncWorker.clear
    end
  end

  def test_execute_worker_and_observe_errors
    CentralPublish::ResyncWorker.clear
    Sidekiq::Testing.inline! do
      CentralPublish::ResyncWorker.perform_async(resync_args)
    end
    assert_equal CentralPublish::ResyncWorker.jobs.size, 0
  end

  def test_worker_limit_on_changing_redis_key
    source = Faker::Lorem.word
    key = format(CENTRAL_RESYNC_RATE_LIMIT, source: source)
    set_others_redis_key(CENTRAL_RESYNC_MAX_ALLOWED_WORKERS, 2)
    set_others_redis_key(key, 1)

    assert_equal resync_worker_limit_reached?(source), false
    set_others_redis_key(key, 3)
    assert resync_worker_limit_reached?(source)
  ensure
    remove_others_redis_key(key)
  end

  def test_worker_limit_on_without_redis_key
    source = Faker::Lorem.word
    key = format(CENTRAL_RESYNC_RATE_LIMIT, source: source)
    remove_others_redis_key(CENTRAL_RESYNC_MAX_ALLOWED_WORKERS)
    set_others_redis_key(key, (RESYNC_WORKER_LIMIT - 1))

    assert_equal resync_worker_limit_reached?(source), false
    set_others_redis_key(key, (RESYNC_WORKER_LIMIT + 1))
    assert resync_worker_limit_reached?(source)
  ensure
    remove_others_redis_key(key)
  end

  def test_current_worker_count_without_source_registered
    source = Faker::Lorem.word
    key = format(CENTRAL_RESYNC_RATE_LIMIT, source: source)
    remove_others_redis_key(key)

    assert_equal resync_worker_limit_reached?(source), false
    set_others_redis_key(CENTRAL_RESYNC_MAX_ALLOWED_WORKERS, 0)
    assert resync_worker_limit_reached?(source)
  ensure
    remove_others_redis_key(CENTRAL_RESYNC_MAX_ALLOWED_WORKERS)
  end

  def test_max_allowed_records_on_setting_redis_key
    set_others_redis_key(CENTRAL_RESYNC_MAX_ALLOWED_RECORDS, 1_000)

    assert_equal max_allowed_records, 1_000
  ensure
    remove_others_redis_key(CENTRAL_RESYNC_MAX_ALLOWED_RECORDS)
  end

  def test_default_max_records_without_redis_key
    remove_others_redis_key(CENTRAL_RESYNC_MAX_ALLOWED_RECORDS)
    ratelimit_options = resync_ratelimit_options(resync_args)

    assert_equal max_allowed_records, RESYNC_MAX_ALLOWED_RECORDS
  end

  def test_configure_redis_and_execute
    source = Faker::Lorem.word
    key = resync_rate_limiter_key(source)
    key_count = get_others_redis_key(key).to_i
    assert_equal key_count, 0

    configure_redis_and_execute(source) do
      CentralPublish::ResyncWorker.perform_async(resync_args.merge(source: source))
      key_count = get_others_redis_key(key).to_i
    end

    assert_equal key_count, 1
  ensure
    CentralPublish::ResyncWorker.clear
    remove_others_redis_key(key)
  end

  def test_reset_key_on_configure_redis_and_execute
    source = Faker::Lorem.word
    key = resync_rate_limiter_key(source)
    key_count = get_others_redis_key(key).to_i

    configure_redis_and_execute(source) do
      CentralPublish::ResyncWorker.perform_async(resync_args)
    end

    assert_equal get_others_redis_key(key).to_i, key_count
  ensure
    CentralPublish::ResyncWorker.clear
    remove_others_redis_key(key)
  end

  def test_check_status_is_started_on_scheduled_state
    args = resync_args
    key = resync_rate_limiter_key(args[:source])
    persist_job_info_and_start_entity_publish(args[:source], args[:job_id], args[:model_name], args[:meta_info])

    job_info = fetch_resync_job_information(args[:source], args[:job_id])

    assert_equal job_info[:status], RESYNC_JOB_STATUSES[:started]
  ensure
    CentralPublish::ResyncWorker.clear
    remove_others_redis_key(key)
  end

  def test_check_status_is_complated_on_executed_state
    args = resync_args
    key = resync_rate_limiter_key(args[:source])
    push_resync_job_information(args[:source], args[:job_id], args[:model_name])
    Account.first.make_current
    sync_entity(model_name: args[:model_name], job_id: args[:job_id], source: args[:source], meta_info: args[:meta_info])
    job_info = fetch_resync_job_information(args[:source], args[:job_id])

    assert_equal job_info[:status], RESYNC_JOB_STATUSES[:completed]
  ensure
    CentralPublish::ResyncWorker.clear
    remove_others_redis_key(key)
  end

  def test_check_status_is_failed_on_excaption_state
    args = resync_args
    key = resync_rate_limiter_key(args[:source])
    key_count = get_others_redis_key(key).to_i
    push_resync_job_information(args[:source], args[:job_id], args[:model_name])
    Sidekiq::Testing.inline! do
      CentralPublish::ResyncWorker.perform_async(job_id: args[:job_id], source: args[:source], meta_info: args[:meta_info])
    end
    job_info = fetch_resync_job_information(args[:source], args[:job_id])

    assert_equal job_info[:status], RESYNC_JOB_STATUSES[:failed]
    assert_equal get_others_redis_key(key).to_i, key_count
  ensure
    CentralPublish::ResyncWorker.clear
    remove_others_redis_key(key)
  end

  def test_resync_job_info_key_expiration
    args = resync_args
    key = resync_job_status_key(args[:source], args[:job_id])
    push_resync_job_information(args[:source], args[:job_id], args[:model_name])
    assert get_others_redis_expiry(key) <= RESYNC_JOB_EXPIRY_TIME
  ensure
    remove_others_redis_key(key)
  end
end
