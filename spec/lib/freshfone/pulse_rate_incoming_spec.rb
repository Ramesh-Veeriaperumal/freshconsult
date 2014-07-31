require 'spec_helper'

describe "CreditInfo" do
	before :each do
		@call = FactoryGirl.build(:freshfone_call)
		@call.freshfone_number = FactoryGirl.build(:freshfone_number)
		account = FactoryGirl.build(:account)
		account.freshfone_account = FactoryGirl.build(:freshfone_account)
		@call.account = account
		@call.agent = FactoryGirl.build(:user)
	end

	describe "Checking Incoming cost" do
		before :each do
			@call.call_type = Freshfone::Call::CALL_TYPE_HASH[:incoming]
		end
		context "from Local number" do
			it "should have call cost as 0.015" do
				@pulse_rate = Freshfone::PulseRate.new(@call, false)
				@pulse_rate.pulse_charge.should eql(0.015)
			end
		end
		describe "from toll_free number" do
			before :each do
				@call.freshfone_number.number_type = Freshfone::Number::TYPE_HASH[:toll_free]
			end
			context "from US" do
				it "should have call cost as 0.04" do
					@pulse_rate = Freshfone::PulseRate.new(@call, false)
					@pulse_rate.pulse_charge.should eql(0.04)
				end
			end
			context "from Canada" do
				it "should have call cost as 0.04" do
					@pulse_rate = Freshfone::PulseRate.new(@call, false)
					@pulse_rate.pulse_charge.should eql(0.04)
				end
			end
			context "from UK" do
				it "should have call cost as 0.078" do
					@call.freshfone_number.country = "GB"
					@pulse_rate = Freshfone::PulseRate.new(@call, false)
					@pulse_rate.pulse_charge.should eql(0.078)
				end
			end
			
			
		end
	end

	describe "Checking Incoming Forwarded cost" do
		before :each do
			@call.call_type = Freshfone::Call::CALL_TYPE_HASH[:incoming]
		end
		describe "from Local number" do
			describe "for US number" do
				context "for number starting with 1907" do
					# Freshfone::PulseRate::FRESHFONE_CHARGES['US'][:numbers][0][:standard]
					it "should have call cost as 0.288" do
						@call.agent.phone = "+19073181277"
						pulse_rate = Freshfone::PulseRate.new(@call, true)
						pulse_rate.pulse_charge.should eql(0.288)
					end
				end

				context "for number starting with 1" do
					# Freshfone::PulseRate::FRESHFONE_CHARGES['US'][:numbers][1][:standard]
					it "should have call cost as 0.038" do
						@call.agent.phone = "+17274780266"
						pulse_rate = Freshfone::PulseRate.new(@call, true)
						pulse_rate.pulse_charge.should eql(0.038)
					end
				end
			end

			describe "for Russian number" do
				context "for number starting with 732690" do
					# Freshfone::PulseRate::FRESHFONE_CHARGES['RU'][:numbers][0][:standard]
					it "should have call cost as 0.291" do
						@call.agent.phone = "+73269012334"
						pulse_rate = Freshfone::PulseRate.new(@call, true)
						pulse_rate.pulse_charge.should eql(0.291)
					end
				end
			
				context "for number starting with 7812" do
					# Freshfone::PulseRate::FRESHFONE_CHARGES['RU'][:numbers][1][:standard]
					it "should have call cost as 0.058" do
						@call.agent.phone = "+78121234561"
						pulse_rate = Freshfone::PulseRate.new(@call, true)
						pulse_rate.pulse_charge.should eql(0.058)
					end
				end

				context "for number starting with 73952" do
					# Freshfone::PulseRate::FRESHFONE_CHARGES['RU'][:numbers][2][:standard]
					it "should have call cost as 0.259" do
						@call.agent.phone = "+73952123453"
						pulse_rate = Freshfone::PulseRate.new(@call, true)
						pulse_rate.pulse_charge.should eql(0.259)
					end
				end
		
				context "for number starting with 772139" do
					# Freshfone::PulseRate::FRESHFONE_CHARGES['RU'][:numbers][3][:standard]
					it "should have call cost as 0.285" do
						@call.agent.phone = "+77213987654"
						pulse_rate = Freshfone::PulseRate.new(@call, true)
						pulse_rate.pulse_charge.should eql(0.285)
					end
				end
			end
		end

		describe "from toll_free number" do
			before :each do
				@call.freshfone_number.number_type = Freshfone::Number::TYPE_HASH[:toll_free]
			end
			describe "from US" do
				describe "to US number" do
					context "for number starting with 1907" do
						# Freshfone::PulseRate::FRESHFONE_CHARGES['US'][:numbers][0][:usca_tollfree]
						it "should have call cost as 0.313" do
							@call.agent.phone = "+19073181277"
							pulse_rate = Freshfone::PulseRate.new(@call, true)
							pulse_rate.pulse_charge.should eql(0.313)
						end
					end
				
					context "for number starting with 1" do
						# Freshfone::PulseRate::FRESHFONE_CHARGES['US'][:numbers][1][:usca_tollfree]
						it "should have call cost as 0.063" do
							@call.agent.phone = "+17274780266"
							pulse_rate = Freshfone::PulseRate.new(@call, true)
							pulse_rate.pulse_charge.should eql(0.063)
						end
					end

				end
			
				describe "to Russian number" do
					context "for number starting with 732690" do
						# Freshfone::PulseRate::FRESHFONE_CHARGES['RU'][:numbers][0][:usca_tollfree]
						it "should have call cost as 0.316" do
							@call.agent.phone = "+73269012334"
							pulse_rate = Freshfone::PulseRate.new(@call, true)
							pulse_rate.pulse_charge.should eql(0.316)
						end
					end
			
					context "for number starting with 7812" do
						# Freshfone::PulseRate::FRESHFONE_CHARGES['RU'][:numbers][1][:usca_tollfree]
						it "should have call cost as 0.083" do
							@call.agent.phone = "+78121234561"
							pulse_rate = Freshfone::PulseRate.new(@call, true)
							pulse_rate.pulse_charge.should eql(0.083)
						end
					end

					context "for number starting with 73952" do
						# Freshfone::PulseRate::FRESHFONE_CHARGES['RU'][:numbers][2][:usca_tollfree]
						it "should have call cost as 0.284" do
							@call.agent.phone = "+73952123453"
							pulse_rate = Freshfone::PulseRate.new(@call, true)
							pulse_rate.pulse_charge.should eql(0.284)
						end
					end
		
					context "for number starting with 772139" do
						# Freshfone::PulseRate::FRESHFONE_CHARGES['RU'][:numbers][3][:usca_tollfree]
						it "should have call cost as 0.31" do
							@call.agent.phone = "+77213987654"
							pulse_rate = Freshfone::PulseRate.new(@call, true)
							pulse_rate.pulse_charge.should eql(0.31)
						end
					end
				end
			end
		
			describe "from Canada" do
				before :each do
					@call.freshfone_number.country = "CA"
				end
				describe "to US number" do
					context "for number starting with 1907" do
						# Freshfone::PulseRate::FRESHFONE_CHARGES['US'][:numbers][0][:usca_tollfree]
						it "should have call cost as 0.313" do
							@call.agent.phone = "+19073181277"
							pulse_rate = Freshfone::PulseRate.new(@call, true)
							pulse_rate.pulse_charge.should eql(0.313)
						end
					end
				
					context "for number starting with 1" do
						# Freshfone::PulseRate::FRESHFONE_CHARGES['US'][:numbers][1][:usca_tollfree]
						it "should have call cost as 0.063" do
							@call.agent.phone = "+17274780266"
							pulse_rate = Freshfone::PulseRate.new(@call, true)
							pulse_rate.pulse_charge.should eql(0.063)
						end
					end

				end
			
				describe "to Russian number" do
					context "for number starting with 732690" do
						# Freshfone::PulseRate::FRESHFONE_CHARGES['RU'][:numbers][0][:usca_tollfree]
						it "should have call cost as 0.316" do
							@call.agent.phone = "+73269012334"
							pulse_rate = Freshfone::PulseRate.new(@call, true)
							pulse_rate.pulse_charge.should eql(0.316)
						end
					end
			
					context "for number starting with 7812" do
						# Freshfone::PulseRate::FRESHFONE_CHARGES['RU'][:numbers][1][:usca_tollfree]
						it "should have call cost as 0.083" do
							@call.agent.phone = "+78121234561"
							pulse_rate = Freshfone::PulseRate.new(@call, true)
							pulse_rate.pulse_charge.should eql(0.083)
						end
					end

					context "for number starting with 73952" do
						# Freshfone::PulseRate::FRESHFONE_CHARGES['RU'][:numbers][2][:usca_tollfree]
						it "should have call cost as 0.284" do
							@call.agent.phone = "+73952123453"
							pulse_rate = Freshfone::PulseRate.new(@call, true)
							pulse_rate.pulse_charge.should eql(0.284)
						end
					end
		
					context "for number starting with 772139" do
						# Freshfone::PulseRate::FRESHFONE_CHARGES['RU'][:numbers][3][:usca_tollfree]
						it "should have call cost as 0.31" do
							@call.agent.phone = "+77213987654"
							pulse_rate = Freshfone::PulseRate.new(@call, true)
							pulse_rate.pulse_charge.should eql(0.31)
						end
					end
				end
			end
		
			describe "from UK" do
				before :each do
					@call.freshfone_number.country = "GB"
				end
				describe "to US number" do
					context "for number starting with 1907" do
						# Freshfone::PulseRate::FRESHFONE_CHARGES['US'][:numbers][0][:uk_tollfree]
						it "should have call cost as 0.35" do
							@call.agent.phone = "+19073181277"
							pulse_rate = Freshfone::PulseRate.new(@call, true)
							pulse_rate.pulse_charge.should eql(0.35)
						end
					end
				
					context "for number starting with 1" do
						# Freshfone::PulseRate::FRESHFONE_CHARGES['US'][:numbers][1][:uk_tollfree]
						it "should have call cost as 0.1" do
							@call.agent.phone = "+17274780266"
							pulse_rate = Freshfone::PulseRate.new(@call, true)
							pulse_rate.pulse_charge.should eql(0.1)
						end
					end

				end
			
				describe "to Russian number" do
					context "for number starting with 732690" do
						# Freshfone::PulseRate::FRESHFONE_CHARGES['RU'][:numbers][0][:uk_tollfree]
						it "should have call cost as 0.354" do
							@call.agent.phone = "+73269012334"
							pulse_rate = Freshfone::PulseRate.new(@call, true)
							pulse_rate.pulse_charge.should eql(0.354)
						end
					end
			
					context "for number starting with 7812" do
						# Freshfone::PulseRate::FRESHFONE_CHARGES['RU'][:numbers][1][:uk_tollfree]
						it "should have call cost as 0.12" do
							@call.agent.phone = "+78121234561"
							pulse_rate = Freshfone::PulseRate.new(@call, true)
							pulse_rate.pulse_charge.should eql(0.12)
						end
					end

					context "for number starting with 73952" do
						# Freshfone::PulseRate::FRESHFONE_CHARGES['RU'][:numbers][2][:uk_tollfree]
						it "should have call cost as 0.321" do
							@call.agent.phone = "+73952123453"
							pulse_rate = Freshfone::PulseRate.new(@call, true)
							pulse_rate.pulse_charge.should eql(0.321)
						end
					end
		
					context "for number starting with 772139" do
						# Freshfone::PulseRate::FRESHFONE_CHARGES['RU'][:numbers][3][:uk_tollfree]
						it "should have call cost as 0.348" do
							@call.agent.phone = "+77213987654"
							pulse_rate = Freshfone::PulseRate.new(@call, true)
							pulse_rate.pulse_charge.should eql(0.348)
						end
					end
				end
			end

		end
	end

end