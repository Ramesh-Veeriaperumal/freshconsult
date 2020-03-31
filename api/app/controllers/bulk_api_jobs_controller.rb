class BulkApiJobsController < ApiApplicationController
  include BulkApiJobsHelper

  def show
    response = pick_job(params[:id].to_s)
    response['payload'] = decimal_to_int(response['payload'])
    head(404) if response.blank?
    @job = response
  end

  def load_object
    # need to keep this empty since we get data from dynamo
    # can't add in LOAD_OBJECT_EXCEPT since this is a show method
  end
end
