require_relative '../test_helper'
require 'securerandom'

class RedlockTest < ActionView::TestCase
  include Redis::Redlock

  def setup
    Redis::Redlock.load_unlock_lua_script_to_redis
  end

  def test_acquire_and_release
    lock_key = SecureRandom.uuid
    seed = acquire_lock(lock_key, 100_000)
    assert seed.present?
    assert release_lock(lock_key, seed)
  end

  def test_acquire_same_key
    lock_key = SecureRandom.uuid
    assert acquire_lock(lock_key, 100_000).present?
    assert acquire_lock(lock_key, 100_000).nil?
  end

  def test_acquire_release_acquire
    lock_key = SecureRandom.uuid
    seed = acquire_lock(lock_key, 100_000)
    assert seed.present?
    assert release_lock(lock_key, seed)
    assert acquire_lock(lock_key, 100_000).present?
  end

  def test_acquire_lock_and_run
    lock_key = SecureRandom.uuid
    called = false
    assert acquire_lock_and_run(key: lock_key, ttl: 100_000) {
      called = true
    }
    assert called
  end

  def test_acquire_lock_and_run_already_locked
    lock_key = SecureRandom.uuid
    acquire_lock(lock_key, 100_000)
    called = false
    assert !acquire_lock_and_run(key: lock_key, ttl: 100_000) {
      called = true
    }
    assert !called
  end

  def test_acquire_lock_and_run_releases_key
    lock_key = SecureRandom.uuid
    called = false
    assert acquire_lock_and_run(key: lock_key, ttl: 100_000) {
      called = true
    }
    assert called
    called = false
    assert acquire_lock_and_run(key: lock_key, ttl: 100_000) {
      called = true
    }
    assert called
    assert acquire_lock(lock_key, 100_000).present?
  end

  def test_acquire_lock_and_run_with_exception
    lock_key = SecureRandom.uuid
    assert_raises StandardError do
      acquire_lock_and_run(key: lock_key, ttl: 100_000) do
        raise StandardError
      end
    end
    assert acquire_lock(lock_key, 100_000).present?
  end
end
