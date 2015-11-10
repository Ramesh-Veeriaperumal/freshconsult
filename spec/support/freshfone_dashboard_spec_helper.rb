module FreshfoneDashboardSpecHelper
	
	def create_in_progress_calls
		@freshfone_call = @account.freshfone_calls.create(  :freshfone_number_id => @number.id, 
		                                  :call_status => 8, :call_type => 1, :agent => @agent,
		                                  :params => { :CallSid => "CA2db76c748cb6f081853f80dace462a04" } )
	end

	def create_queued_call
		@freshfone_call = @account.freshfone_calls.create(  :freshfone_number_id => @number.id, 
		                                  :call_status => 6, :call_type => 1, :agent => @agent,
		                                  :params => { :CallSid => "CA2db76c748cb6f081853f80dace462a04" } )
	end
end