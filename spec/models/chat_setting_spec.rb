require 'spec_helper'

RSpec.describe ChatSetting do

	it "should create chatSettings" do# failing in master
	chat=ChatSetting.new
	chat.save
	test_display_id=Digest::MD5.hexdigest("#{ChatConfig['secret_key']}::#{chat.id}")
	test_visitor_session=Digest::SHA512.hexdigest("#{ChatConfig['secret_key']}::#{test_display_id}")

	test_display_id.should eql chat.display_id
	test_visitor_session.should eql chat.visitor_session
	end
end
