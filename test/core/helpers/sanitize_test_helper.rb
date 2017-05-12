module SanitizeTestHelper
	DEFAULT_UNSANITIZED_FIELDS_BY_OBJECT_TYPE = {"Helpdesk::Ticket" => ["subject"]}

	def assert_object object
		to_be_sanitized_object = object.clone
		sanitize_field_values_for_substitution to_be_sanitized_object   		#turns the unsanitized object to sanitized object.
		sanitized_object = to_be_sanitized_object

		assert_escape_for_text_fields sanitized_object, object
		assert_escape_for_text_fields sanitized_object.company, object.company if object.respond_to? "company"
		assert_escape_for_text_fields sanitized_object.requester, object.requester if object.respond_to? "requester"
	end

	def assert_escape_for_text_fields sanitized_object, unsanitized_object
		fields = fields sanitized_object
		unless fields.blank?
			fields.each do |field|
				assert_equal sanitized_object.send(field), h(unsanitized_object.send(field))
			end
		end
	end
	
	def fields object
		default_fields = DEFAULT_UNSANITIZED_FIELDS_BY_OBJECT_TYPE.fetch(object.class.name, [])
		custom_fields = custom_fields object
		fields = default_fields + custom_fields
	end

	def custom_fields object
		if object.class.name == 'User' && object.agent?
			[]
		else
			object.respond_to?('text_ff_aliases') ? object.text_ff_aliases : []
		end
	end

end