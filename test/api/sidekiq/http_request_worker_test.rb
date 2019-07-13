require_relative '../unit_test_helper'
require 'sidekiq/testing'
require 'faker'

Sidekiq::Testing.fake!

class HttpRequestWorkerTest < ActionView::TestCase

  def setup
    Account.stubs(:current).returns(Account.first)
    HttpRequestProxy.any_instance.stubs(:fetch_using_req_params).returns(true)
  end

  def teardown
    Account.unstub(:current)
    super
  end

  def test_http_request_worker_runs
    args = construct_worker_args
    HttpRequestWorker.new.perform(args)
    assert_equal 0, HttpRequestWorker.jobs.size
  end

  def test_http_request_worker_for_get_request
    args = construct_get_request_args
    HttpRequestWorker.new.perform(args)
    assert_equal 0, HttpRequestWorker.jobs.size
  end

  def test_http_request_worker_invalid_args
    args = construct_invalid_worker_args
    HttpRequestWorker.new.perform(args)
    assert_equal 0, HttpRequestWorker.jobs.size
  end

  def test_http_request_worker_exception
    args = ['abc']
    HttpRequestWorker.new.perform(args)
  rescue Exception => e
    assert_equal 0, HttpRequestWorker.jobs.size
  end

  def construct_worker_args
    {
      'domain': 'testdomain.test.com',
      'route': '/rest/route',
      'request_method': 'post',
      'auth_header': 'Token 12345',
      'data': { 'name': 'abc' }
    }
  end

  def construct_get_request_args
    {
      'domain': 'testdomain.test.com',
      'route': '/rest/route',
      'request_method': 'get',
      'auth_header': 'Token 12345'
    }
  end

  def construct_invalid_worker_args
    {
      'domain': 'testdomain'
    }
  end
end
