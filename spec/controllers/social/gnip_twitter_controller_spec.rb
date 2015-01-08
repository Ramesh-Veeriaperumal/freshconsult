require 'spec_helper'
include Social::Twitter::Constants

RSpec.describe Social::GnipTwitterController do
  self.use_transactional_fixtures = false

  describe "POST #reconnect" do

    it "should update reconnect timestamp in redis" do
      now = Time.now
      time = (now + 5.minutes).iso8601
      epoch = now.to_i / TIME[:reconnect_timeout]

      data    = "#{time}#{epoch}"
      digest  = OpenSSL::Digest.new('sha512')
      hash    = OpenSSL::HMAC.hexdigest(digest, GnipConfig::GNIP_SECRET_KEY, data)

      post :reconnect, {:reconnect_time => time, :hash => hash}

      json = JSON.parse(response.body)
      json['success'].should be_truthy
    end

    it "should render success as false if reconnect_time or hash parameter is not present" do
      post :reconnect, {:reconnect_time => (Time.now + 5.minutes).iso8601 }
      json = JSON.parse(response.body)
      json['success'].should be_falsey
    end

    it "should render success as false if an expired reconnect_time is sent" do
      post :reconnect, {:reconnect_time => (Time.now + 15.minutes).iso8601 }
      json = JSON.parse(response.body)
      json['success'].should be_falsey
    end

    it "should not update in redis when request comes from malicious user" do
      post :reconnect, {:reconnect_time => Time.now.iso8601, :hash => Faker::Lorem.characters(100) }
      json = JSON.parse(response.body)
      json['success'].should be_falsey
    end

  end
end
