class Helpdesk::CaFoldersController < ApplicationController

	def show
		@ca_responses = current_account.canned_responses.accessible_for(current_user).find(:all, 
			:conditions => { :folder_id => params[:id] })
		respond_to do |format|
			format.js { render :partial => 'helpdesk/tickets/components/show' }
		end
	end

end