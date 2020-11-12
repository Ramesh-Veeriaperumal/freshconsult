class BulkApiJobsController < ApiApplicationController
  include BulkApiJobsHelper

  def show
    response = pick_job(params[:id].to_s)
    return head(404) if response.blank?

    response['payload'] = decimal_to_int(response['payload'])
    response['status'] = BULK_API_JOB_STATUS_CODE_MAPPING[response['status_id'].to_i]
    @job = response
    return render('bulk_api_jobs/show_intermediate') if INTERMEDIATE_STATES.include? response['status']
  end

  def load_object
    # need to keep this empty since we get data from dynamo
    # can't add in LOAD_OBJECT_EXCEPT since this is a show method
  end
end
