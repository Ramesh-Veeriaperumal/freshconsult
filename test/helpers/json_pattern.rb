module JsonPattern
  def forum_category_pattern name="test", desc="test desc"
    {
    	id: Fixnum,
      name: name,
      description: desc,
      position: Fixnum,
      created_at:/^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$/,
      updated_at:/^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$/
    }
  end

  def bad_request_error_pattern field, value
    {
      field: "#{field}", 
      message: I18n.t("api.error_messages.#{value}"), 
      code: ApiError::BaseError::API_ERROR_CODES_BY_VALUE[value]
    }
  end

end