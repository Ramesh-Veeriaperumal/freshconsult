class Freshfone::CallHistoryController < ApplicationController
	before_filter :load_calls, :only => [:index, :custom_search]
	before_filter :load_children, :only => [:children]
	before_filter :fetch_recent_calls, :only => [:recent_calls]

	def index
		@all_freshfone_numbers = current_account.all_freshfone_numbers.all(:order => "deleted ASC")
	end
	
	def custom_search
		respond_to do |format|
			format.js {}
		end
	end

	def children
		respond_to do |format|
			format.js {}
		end
	end
	
	def recent_calls
		respond_to do |format|
			format.js {}
		end
	end

	private
		def load_calls
			params[:wf_per_page] = 30
			@calls = current_number.freshfone_calls.roots.filter(:params => params, :filter => "Freshfone::Filters::CallFilter")
		end

		def current_number
			@current_number ||= params[:number_id].present? ? current_account.all_freshfone_numbers.find_by_id(params[:number_id])
													: current_account.freshfone_numbers.first
		end
	
		def load_children
			#  remove include of number and use current_number instead
			@parent_call = current_number.freshfone_calls.find(params[:id])
			@calls = @parent_call.descendants.reverse unless @parent_call.blank?
		end

		def fetch_recent_calls
			@calls = current_user.freshfone_calls.roots.newest(5).include_customer if current_user.agent?
		end

end