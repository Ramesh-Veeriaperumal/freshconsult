require_relative '../../test_helper'
class CronWebhook::WebHooksControllerTest < ActionController::TestCase
  include CronWebhooks::Constants
  include CronWebhooks::CronHelper
  include Redis::Semaphore

  def setup
    super
  end

  def wrap_cname(params)
    { web_hook: params }
  end

  def test_web_hooks_controller_with_invalid_task_name
    task_hash = { task_name: 'scheduler_sla_invalid', mode: 'webhook' }
    post :trigger, construct_params({ version: 'cron' }.merge(task_hash), task_hash)
    assert_response 400
    match_json([bad_request_error_pattern('task_name', :not_included, list: CronWebhooks::Constants::TASKS.join(','), code: :invalid_value)])
  end

  def test_sup_cron_api_with_invalid_task_name
    task_hash = { account_type: 'scheduler_supervisor_invalid', name: 'supervisor_invalid' }
    post :trigger_cron_api, construct_params({ version: 'cron' }.merge(task_hash), task_hash)
    assert_response 400
  end

  def test_sla_escl_cron_api_with_valid_task_name
    task_hash = { account_type: 'trial', name: 'sla_escalation' }
    post :trigger_cron_api, construct_params({ version: 'cron' }.merge(task_hash), task_hash)
    assert_response 200
  end

  def test_sla_rem_cron_api_with_valid_task_name
    task_hash = { account_type: 'trial', name: 'sla_reminder' }
    post :trigger_cron_api, construct_params({ version: 'cron' }.merge(task_hash), task_hash)
    assert_response 200
  end

  def test_web_hooks_controller_cron_api_with_valid_task_name
    task_hash = { account_type: 'trial', name: 'supervisor' }
    post :trigger_cron_api, construct_params({ version: 'cron' }.merge(task_hash), task_hash)
    assert_response 200
  end

  def test_web_hooks_controller_with_invalid_type
    task_hash = { task_name: 'scheduler_sla', type: 'invalid', mode: 'webhook' }
    post :trigger, construct_params({ version: 'cron' }.merge(task_hash), task_hash)
    assert_response 400
    match_json([bad_request_error_pattern('type', :not_included, list: CronWebhooks::Constants::TYPES.join(','), code: :invalid_value)])
  end

  def test_web_hooks_controller_with_invalid_queue_name
    task_hash = { task_name: 'sqs_monitor', queue_name: 'invalid', mode: 'webhook' }
    post :trigger, construct_params({ version: 'cron' }.merge(task_hash), task_hash)
    assert_response 400
    match_json([bad_request_error_pattern('queue_name', :not_included, list: CronWebhooks::Constants::MONITORED_QUEUES.join(','), code: :invalid_value)])
  end

  def test_web_hooks_controller_with_type_for_type_unexpected_tasks
    task_hash = { task_name: 'google_contacts_sync', type: 'free', mode: 'webhook' }
    post :trigger, construct_params({ version: 'cron' }.merge(task_hash), task_hash)
    assert_response 400
    match_json([bad_request_error_pattern('type', :type_not_expected, code: :invalid_value)])
  end

  def test_web_hooks_controller_without_type_for_type_expected_tasks
    task_hash = { task_name: 'scheduler_sla', mode: 'webhook' }
    post :trigger, construct_params({ version: 'cron' }.merge(task_hash), task_hash)
    assert_response 400
    match_json([bad_request_error_pattern('type', :type_expected, code: :invalid_value)])
  end

  def test_web_hooks_controller_with_queue_for_queue_unexpected_tasks
    task_hash = { task_name: 'google_contacts_sync', queue_name: 'facebook_realtime_queue', mode: 'webhook' }
    post :trigger, construct_params({ version: 'cron' }.merge(task_hash), task_hash)
    assert_response 400
    match_json([bad_request_error_pattern('queue_name', :queue_name_not_expected, code: :invalid_value)])
  end

  def test_web_hooks_controller_without_queue_for_queue_expected_tasks
    task_hash = { task_name: 'sqs_monitor', mode: 'webhook' }
    post :trigger, construct_params({ version: 'cron' }.merge(task_hash), task_hash)
    assert_response 400
    match_json([bad_request_error_pattern('queue_name', :queue_name_expected, code: :invalid_value)])
  end

  def test_web_hooks_controller_semaphore_lock
    task_hash = { task_name: 'scheduler_sla', type: 'free', mode: 'webhook' }
    set_semaphore('CRON_JOB_SEMAPHORE:scheduler_sla:free:web_hooks_controller', value = 1)
    post :trigger, construct_params({ version: 'cron' }.merge(task_hash), task_hash)
    del_semaphore('CRON_JOB_SEMAPHORE:scheduler_sla:free:web_hooks_controller')
    assert_response 409
  end

  TASKS.each do |task|
    define_method "test_web_hooks_controller_#{task}" do
      TASK_MAPPING[task.to_sym][:class_name].constantize.jobs.clear
      task_hash = { task_name: task, mode: 'webhook' }
      task_hash[:type] = TYPES.first if TASKS_REQUIRING_TYPES.include? task
      task_hash[:queue_name] = MONITORED_QUEUES.first if TASKS_REQUIRING_QUEUE_NAME.include? task
      post :trigger, construct_params({ version: 'cron' }.merge(task_hash), task_hash)
      assert_response 200
      assert TASK_MAPPING[task.to_sym][:class_name].constantize.jobs.count == 1
    end
  end
end
