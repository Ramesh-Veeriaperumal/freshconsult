module SupportHelper
	include Portal::PortalFilters
	
	# Ticket specific helpers
	# Construct ticket form UI
	def construct_ticket_element(object_name, field, field_label, dom_type, required, field_value = "", field_name = "", in_portal = false , is_edit = false)
	    dom_type = (field.field_type == "nested_field") ? "nested_field" : dom_type
	    element_class   = " #{ (required) ? 'required' : '' } #{ dom_type }"
	    field_name      = (field_name.blank?) ? field.field_name : field_name
	    object_name     = "#{object_name.to_s}#{ ( !field.is_default_field? ) ? '[custom_field]' : '' }"
	    label = label_tag object_name+"_"+field.field_name, field_label, :class => ((dom_type != "checkbox") ? ("#{required ? 'required': ""} control-label") : "")
	    case dom_type
	      when "requester" then
	      	element = render(:partial => "/support/shared/requester", 
	      		:locals => { :label => label, :object_name => object_name, :field => field })
	      when "email" then
	        element = label + content_tag(:div, text_field(object_name, field_name, :class => element_class, :value => field_value), :class => "controls")
	        element = add_cc_field_tag element ,field if (field.portal_cc_field? && !is_edit && controller_name.singularize != "feedback_widget") #dirty fix
	        element += add_name_field unless is_edit
	      when "text", "number" then
	        element = label + content_tag(:div, text_field(object_name, field_name, :class => element_class + " span12", :value => field_value), :class => "controls")
	      when "paragraph" then
	        element = label + content_tag(:div, text_area(object_name, field_name, :class => element_class + " span12", :value => field_value, :rows => 6), :class => "controls")
	      when "dropdown" then
	        if (field.field_type == "default_status" and in_portal)
	          element = label + content_tag(:div, 
	          		select(object_name, field_name,  
	          			field.field_type == "default_status" ? field.visible_status_choices : field.choices, 
	          			{:selected => field_value}, {:class => element_class}), :class => "controls")
	        end
	      when "dropdown_blank" then
	        element = label + content_tag(:div, 
	        	select(object_name, field_name, field.choices, { :include_blank => "...", :selected => field_value }, {:class => element_class}), :class => "controls")
	      when "nested_field" then
	        element = label + content_tag(:div, nested_field_tag(object_name, field_name, field, {:include_blank => "...", :selected => field_value}, {:class => element_class}, field_value, in_portal), :class => "controls")
	      when "hidden" then
	        element = hidden_field(object_name , field_name , :value => field_value)
	      when "checkbox" then
	        element = content_tag(:div, check_box(object_name, field_name, :class => element_class, :checked => field_value ) + label, :class => "controls")
	      when "html_paragraph" then
	      	_output = []
	      	_output << %( #{ text_area(object_name, field_name, :class => element_class, :value => field_value, :rows => 6) } )
	      	_output << %( #{ render(:partial=>"/support/shared/attachment_form") } )
	        element = label + content_tag(:div, _output.join(" "), :class => "controls")
	    end
	    content_tag :div, element, :class => dom_type+" control-group"
	 end

	def add_cc_field_tag element , field    
		if current_user && current_user.agent? 
		  element  = element + content_tag(:div, render(:partial => "/shared/cc_email_all.html")) 
		elsif current_user && current_user.customer? && field.all_cc_in_portal?
		  element  = element + content_tag(:div, render(:partial => "/shared/cc_email_all.html"))
		else
		   element  = element + content_tag(:div, render(:partial => "/shared/cc_email.html")) if (current_user && field.company_cc_in_portal? && current_user.customer) 
		end
		return element
	end

	def add_requester_field
		content_tag(:div, render(:partial => "/shared/add_requester")) if (current_user && current_user.can_view_all_tickets?)
	end

	def add_name_field
		content_tag(:li, content_tag(:div, render(:partial => "/shared/name_field")),
			:id => "name_field", :class => "hide") unless current_user
	end

	# The field_value(init value) for the nested field should be in the the following format
	# { :category_val => "", :subcategory_val => "", :item_val => "" }
	def nested_field_tag(_name, _fieldname, _field, _opt = {}, _htmlopts = {}, _field_values = {}, in_portal = false)        
		_category = select(_name, _fieldname, _field.choices, _opt, _htmlopts)
		_javascript_opts = {
		  :data_tree => _field.nested_choices,
		  :initValues => _field_values,
		  :disable_children => false
		}.merge!(_opt)

		_field.nested_levels.each do |l|       
		  _javascript_opts[(l[:level] == 2) ? :subcategory_id : :item_id] = (_name +"_"+ l[:name]).gsub('[','_').gsub(']','')
		  _category += content_tag :div, content_tag(:label, l[(!in_portal)? :label : :label_in_portal]) + select(_name, l[:name], [], _opt, _htmlopts), :class => "level_#{l[:level]}"
		end

		_category + javascript_tag("jQuery(document).ready(function(){jQuery('##{(_name +"_"+ _fieldname).gsub('[','_').gsub(']','')}').nested_select_tag(#{_javascript_opts.to_json});})")
	end
end
