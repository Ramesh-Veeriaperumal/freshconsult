class Fdadmin::UsersController < Fdadmin::DevopsMainController

	around_filter :select_slave_shard , :only => :get_user
	before_filter :set_current_account, :only => :get_user
	before_filter :load_user_record , :only => :get_user

	def get_user
		result = {  
			:email => @user.email, 
			:second_email => @user.second_email, 
			:name => @user.name, 
			:account_id => @user.account_id ,
			:language => @user.language,
			:time_zone => @user.time_zone,
			:phone => @user.phone,
			:mobile => @user.mobile,
			:twitter_id => @user.twitter_id,
			:fb_profile_id => @user.fb_profile_id,
			:avatar_url => @user.avatar_url
		}
		respond_to do |format|
			format.json do 
				render :json => result
			end
		end
	end

	def load_user_record
		if params[:user_id] && params[:account_id]
			@user = User.find_by_id_and_account_id(params[:user_id],params[:account_id])
		end
		render :josn => nil, :status => 404 and return if @user.nil?
	end

	def set_current_account
 		if params[:account_id]
			account= Account.find(params[:account_id])
			account.make_current if account
		end
		render :josn => nil, :status => 404 and return if Account.current.nil?
	end

end
