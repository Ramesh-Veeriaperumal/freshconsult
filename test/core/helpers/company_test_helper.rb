['company_fields_test_helper.rb'].each { |file| require "#{Rails.root}/test/core/helpers/#{file}" }
module CompanyTestHelper
	include CompanyFieldsTestHelper

  XSS_SCRIPT_TEXT = "<script> alert('hi'); </script>"
  CUSTOM_FIELDS_TYPES = %w(text paragraph checkbox  number)
  CUSTOM_FIELDS_CONTENT_BY_TYPE = { 'text' => XSS_SCRIPT_TEXT, 'paragraph' =>  XSS_SCRIPT_TEXT,
          'checkbox' => true, 'number' => 1 }  

  def create_company options = {}
    comp = FactoryGirl.build(:company)
    comp.custom_field = options[:custom_fields] if options.key?(:custom_fields)
    comp.save
    comp.reload
  end

  def create_company_with_xss other_object_params = {}
    params  = create_company_params_with_xss other_object_params
    company = create_company params
  end

  def create_company_params_with_xss other_object_params
    params = {}
    params[:custom_fields] = {}
    CUSTOM_FIELDS_TYPES.each do |field_type|
      cf_params = company_params({ type: field_type, field_type: "custom_#{field_type}", label: "test_custom_#{field_type}" })
      custom_field = create_custom_company_field(cf_params)
      params[:custom_fields][:"#{custom_field.name}"] = CUSTOM_FIELDS_CONTENT_BY_TYPE[field_type]
    end
    Account.current.reload
    params.merge(other_object_params)
  end

end