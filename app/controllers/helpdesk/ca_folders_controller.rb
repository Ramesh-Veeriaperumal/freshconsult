class Helpdesk::CaFoldersController < ApplicationController
	include HelpdeskAccessMethods

	def show
    @ca_responses = accessible_from_es(Admin::CannedResponses::Response, {:load => Admin::CannedResponses::Response::INCLUDE_ASSOCIATIONS_BY_CLASS, :size => 300}, default_visiblity, "raw_title", params[:id])
    @ca_responses = accessible_elements(current_account.canned_responses, query_hash('Admin::CannedResponses::Response', 'admin_canned_responses', {:folder_id => params[:id]})) if @ca_responses.nil?


		respond_to do |format|
			format.js { render :partial => 'helpdesk/tickets/components/show' }
		end
	end

end