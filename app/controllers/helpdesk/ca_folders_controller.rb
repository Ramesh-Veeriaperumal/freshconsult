class Helpdesk::CaFoldersController < ApplicationController
	include HelpdeskAccessMethods

	def show
    @ca_responses = accessible_elements(current_account.canned_responses, query_hash('Admin::CannedResponses::Response', 'admin_canned_responses', {:folder_id => params[:id]}))

		respond_to do |format|
			format.js { render :partial => 'helpdesk/tickets/components/show' }
		end
	end

end