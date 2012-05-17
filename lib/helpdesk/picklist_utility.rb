module Helpdesk::PicklistUtility

	def category_choices
		picklist_id = params[:id]
		ticket_field_id = params[:ticket_field_id]
    
    	picklist_value = current_account.ticket_fields.find(ticket_field_id).picklist_values.find(params[:id])
    	@picklist_choices = picklist_value.sub_picklist_values
    
    	render :partial => "/shared/picklist_choices"
	end
	
	def sub_category_choices
		picklist_id = params[:id]
    	ticket_field_id = params[:ticket_field_id]
    	category_picklist_id = params[:category_picklist_id]
    
    	picklist_value = current_account.ticket_fields.find(ticket_field_id).picklist_values.find(category_picklist_id)
    	sub_picklist = picklist_value.sub_picklist_values.find(params[:id])
    	@picklist_choices = sub_picklist.sub_picklist_values

	    render :partial => "/shared/picklist_choices"
	end

end