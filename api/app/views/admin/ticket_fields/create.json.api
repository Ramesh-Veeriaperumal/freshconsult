if @item.nested_field?
  JSON.generate(@item.as_api_response(:nested_field_api))
elsif @item.custom_dropdown_field?
  JSON.generate(@item.as_api_response(:custom_dropdown_field_api))
else
  JSON.generate(@item.as_api_response(:common_field_api))
end
