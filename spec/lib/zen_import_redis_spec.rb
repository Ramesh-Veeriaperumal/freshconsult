require 'spec_helper'

TEST_REDIS_KEY = "TEST_KEY:1"
TEST_HASH_KEY = Faker::Lorem.words.first
TEST_HASH_VALUE = rand(1..1000)
TEST_INCR_VALUE = rand(1..100)

RSpec.configure do |c|
  c.include Redis::RedisKeys
  c.include Redis::ZenImportRedis
end

RSpec.describe Redis::ZenImportRedis do

  before(:each) do
    $redis_others.del TEST_REDIS_KEY
  end

  it "should remove entire redis key" do
    $redis_others.hset TEST_REDIS_KEY, TEST_HASH_KEY, TEST_HASH_VALUE
    remove_zen_import_redis_key TEST_REDIS_KEY
    $redis_others.get(TEST_REDIS_KEY).should be_nil
  end

  it "should get value of the key" do
    $redis_others.hset TEST_REDIS_KEY, TEST_HASH_KEY, TEST_HASH_VALUE
    get_zen_import_hash_value(TEST_REDIS_KEY, TEST_HASH_KEY).to_i.should be_eql(TEST_HASH_VALUE)
  end

  it "should add key, value to the hash" do
    add_to_zen_import_hash(TEST_REDIS_KEY, TEST_HASH_KEY, TEST_HASH_VALUE)
    $redis_others.hget(TEST_REDIS_KEY, TEST_HASH_KEY).to_i.should be_eql(TEST_HASH_VALUE)
  end

  it "should increment value of a hash key" do
    $redis_others.hset TEST_REDIS_KEY, TEST_HASH_KEY, TEST_HASH_VALUE
    incr_queue_count_hash TEST_REDIS_KEY, TEST_HASH_KEY, TEST_INCR_VALUE
    $redis_others.hget(TEST_REDIS_KEY, TEST_HASH_KEY).to_i.should be_eql(TEST_HASH_VALUE + TEST_INCR_VALUE)
  end

  it "should get entire hash" do
    $redis_others.hset TEST_REDIS_KEY, TEST_HASH_KEY, TEST_HASH_VALUE
    get_full_hash(TEST_REDIS_KEY).should be_eql({TEST_HASH_KEY => TEST_HASH_VALUE.to_s})
  end

end