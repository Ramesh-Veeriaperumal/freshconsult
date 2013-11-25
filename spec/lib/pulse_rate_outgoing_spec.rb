require 'spec_helper'

describe "CreditInfo" do
	before :each do
		@call = Factory.build(:freshfone_call)
		@call.freshfone_number = Factory.build(:freshfone_number)
		account = Factory.build(:account)
		account.freshfone_account = Factory.build(:freshfone_account)
		@call.account = account
		@call.agent = Factory.build(:user)
	end

	describe "Checking Outgoing cost" do
		before :each do
			@call.call_type = Freshfone::Call::CALL_TYPE_HASH[:outgoing]
		end
		context "to Indian Number" do
			before :each do
				@call.customer_data = ({ :country => 'IN' })
			end
			it "should have cost as 0.038" do
				@call.customer_number = "+91469123456" # random number don't try calling
				pulse_rate = Freshfone::PulseRate.new(@call, false)
				pulse_rate.pulse_charge.should eql(0.038)
			end
		end
		describe "to US Number" do
			before :each do
				@call.customer_data = ({ :country => 'US' })
			end
			context "starting with 1907" do
				it "should have cost as 0.275" do
					@call.customer_number = "+19073181277"
					pulse_rate = Freshfone::PulseRate.new(@call, false)
					pulse_rate.pulse_charge.should eql(0.275)
				end
			end
			context "starting with 1" do
				it "should have cost as 0.025" do
					@call.customer_number = "+17274780266"
					pulse_rate = Freshfone::PulseRate.new(@call, false)
					pulse_rate.pulse_charge.should eql(0.025)
				end
			end
		end
		
		describe "to Russian Number" do
			before :each do
				@call.customer_data = ({ :country => 'RU' })
			end
			context "for number starting with 732690" do
				# Freshfone::PulseRate::FRESHFONE_CHARGES['RU'][:numbers][0][:outgoing]
				it "should have call cost as 0.279" do
					@call.customer_number = "+73269012334"
					pulse_rate = Freshfone::PulseRate.new(@call, true)
					pulse_rate.pulse_charge.should eql(0.279)
				end
			end
		
			context "for number starting with 7812" do
				# Freshfone::PulseRate::FRESHFONE_CHARGES['RU'][:numbers][1][:outgoing]
				it "should have call cost as 0.045" do
					@call.customer_number = "+78121234561"
					pulse_rate = Freshfone::PulseRate.new(@call, true)
					pulse_rate.pulse_charge.should eql(0.045)
				end
			end

			context "for number starting with 73952" do
				# Freshfone::PulseRate::FRESHFONE_CHARGES['RU'][:numbers][2][:outgoing]
				it "should have call cost as 0.246" do
					@call.customer_number = "+73952123453"
					pulse_rate = Freshfone::PulseRate.new(@call, true)
					pulse_rate.pulse_charge.should eql(0.246)
				end
			end
	
			context "for number starting with 772139" do
				# Freshfone::PulseRate::FRESHFONE_CHARGES['RU'][:numbers][3][:outgoing]
				it "should have call cost as 0.273" do
					@call.customer_number = "+77213987654"
					pulse_rate = Freshfone::PulseRate.new(@call, true)
					pulse_rate.pulse_charge.should eql(0.273)
				end
			end
		end
	end

end