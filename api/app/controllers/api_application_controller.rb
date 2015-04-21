class ApiApplicationController < ApplicationController

  include ErrorHelper 	
  respond_to :json
  after_filter :latest_version

  rescue_from ActionController::UnpermittedParameters, :with => :invalid_field_handler
  rescue_from ActionController::ParameterMissing, :with => :missing_field_handler


  def latest_version
    response.headers["Latest-Version"] = "2"
  end

  def invalid_field_handler(exception)
    invalid_fields = Hash[exception.params.collect { |v| [v, "invalid_field"] }]
    render_400 missing_fields
  end

  def missing_field_handler(exception)
    missing_fields = { exception.param => "missing_field" }
    render_400 missing_fields
  end

  def render_400 errors
    format_error(errors)
    render :template => '/bad_request_error.json.jbuilder', :status => 400
  end
end