require 'spec_helper'

describe Admin::GamificationController do
	setup :activate_authlogic
	self.use_transactional_fixtures = false

	before(:all) do
		@now = (Time.now.to_f*1000).to_i
	end

	before(:each) do
		login_admin
	end

	it "should display arcade index page with gamification_enabled" do
		@account.features.gamification_enable.create
		get :index
		response.body.should =~ /Arcade Settings/
		response.body.should =~ /Award points/
		response.body.should =~ /Professional/
		response.should be_success
	end

	it "should update the Gamification" do
		scr = [20,5,-10,5,25,-15]
		pts = [500,3550,10000,30000,55000,110000]
		put :update_game, {
			:scoreboard_ratings=>{  "0"=>{:score=>scr[0], :resolution_speed=>"1", :id=>"1"}, 
									"1"=>{:score=>scr[1], :resolution_speed=>"2", :id=>"2"}, 
									"2"=>{:score=>scr[2], :resolution_speed=>"3", :id=>"3"}, 
									"3"=>{:score=>scr[3], :resolution_speed=>"101", :id=>"4"}, 
									"4"=>{:score=>scr[4], :resolution_speed=>"102", :id=>"5"}, 
									"5"=>{:score=>scr[5], :resolution_speed=>"103", :id=>"6"}
									}, 
			:scoreboard_levels=> {  "0"=>{:points=>pts[0], :id=>"1"}, 
									"1"=>{:points=>pts[1], :id=>"2"},
									"2"=>{:points=>pts[2], :id=>"3"}, 
									"3"=>{:points=>pts[3], :id=>"4"}, 
									"4"=>{:points=>pts[4], :id=>"5"}, 
									"5"=>{:points=>pts[5], :id=>"6"}
									}
		}
		session[:flash][:notice].should eql "Gamification settings has been successfully updated."
		for i in 1..6 do
			@account.scoreboard_ratings.find(i).score.should eql scr[i-1]
			@account.scoreboard_levels.find(i).points.should eql pts[i-1]
		end
		response.should redirect_to("/admin/gamification")
	end

	it "should inactivate the Gamification" do
		post :toggle
		@account.features.reload
		@account.features.find_by_type("GamificationEnableFeature").should be_nil
	end

	it "should display arcade page with gamification_disabled" do
		@account.features.gamification_enable.destroy
		get :index
		response.body.should =~ /What is Freshdesk Arcade?/
		response.body.should =~ /Enable freshdesk arcade/
		response.body.should =~ /winning awesome satisfaction ratings from customers./
		response.should be_success
	end

	it "should activate the Gamification" do
		post :toggle
		@account.features.reload
		@account.features.find_by_type("GamificationEnableFeature").should_not be_nil
	end
end