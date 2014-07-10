module SupportDiscussionsControllerMethods
	
	def toggle_monitor
		current_object = instance_variable_get(%{@#{controller_name.singularize}})
		@monitorship = current_object.monitorships.find_or_initialize_by_user_id(current_user.id)
		if @monitorship.new_record?
			@monitorship.save
		else
			@monitorship.update_attribute(:active, !@monitorship.active)
		end
		render :nothing => true
	end
end
