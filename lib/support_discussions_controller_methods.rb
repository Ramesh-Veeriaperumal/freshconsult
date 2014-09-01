module SupportDiscussionsControllerMethods
	
	def toggle_monitor
		current_object = instance_variable_get(%{@#{controller_name.singularize}})
		@monitorship = current_object.monitorships.find_or_initialize_by_user_id(current_user.id)
		if @monitorship.new_record?
			@monitorship.portal_id = current_portal.id
			@monitorship.save
		else
			@monitorship.update_attributes(:active => !@monitorship.active, :portal_id => current_portal.id)
		end
		render :nothing => true
	end
end
