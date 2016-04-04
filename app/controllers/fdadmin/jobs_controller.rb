class Fdadmin::JobsController < Fdadmin::DevopsMainController

	around_filter :run_on_slave , :only => [:index,:show]
  before_filter :process_params, :only => [:index,:show]
  before_filter :set_job_type

  JOB_TYPES = {:failed => "failed",:to_be_run => "to_be_run" ,:scheduled_later => "scheduled_later"}
  DJ_JOBS_TABLES = {:delayed_jobs => "Delayed::Job" ,:mailbox_jobs => "Mailbox::Job", :free_account_jobs => "Free::Job", :trial_account_jobs => "Trial::Job", :active_account_jobs => "Active::Job", :premium_account_jobs => "Premium::Job" }
  LIMIT = 10

	def index
		respond_to do |format|
			format.json	do
				render :json => delayed_jobs_count
			end
		end
	end

	def show
    offset = params[:page] ? params[:page].to_i * LIMIT : 0
    order = (params[:type] == JOB_TYPES[:failed]) ? "updated_at" : "run_at"
    jobs = current_job_type.find(:all, :conditions => @condition, :order => order ,:offset => offset, :limit => LIMIT)
    render :json => jobs  
	end 

  def destroy_job
    job = current_job_type.find_by_id(params[:job_id])
    result = (job && job.destroy) ? {:status => "success"} : {:status => "error"  , :message => "job not destroyed" }
    render :json => result
  end

  def requeue
    job = current_job_type.find_by_id(params[:job_id])
    result = (job && job.update_attributes({:attempts => 0, :last_error => nil, :run_at => Time.now.utc}) ) ? {:status => "success"} : {:status => "error"  , :message => "job not retried" }
    render :json => result
  end

  def requeue_selected
    count  = current_job_type.where(id: params[:job_id]).update_all({:attempts => 0, :last_error => nil, :run_at => Time.now.utc})
    result = {:message => "Out of #{params[:job_id].length} selected job(s) , #{count} job(s) has been retried" }  
    render :json => result
  end


  def remove_selected
    records = current_job_type.where(id: params[:job_id]).destroy_all
    result  = {:message => "Out of #{params[:job_id].length} selected job(s) , #{records.length} job(s) has been removed" }
    render :json => result
  end

	private
     
    def set_job_type
      render :json => {:status => "error"}  unless DJ_JOBS_TABLES.has_key?(params[:job_name].to_sym)
      @current_job_type = DJ_JOBS_TABLES[params[:job_name].to_sym] 
    end

    def current_job_type
      @current_job_type.constantize
    end

    def process_params
      prefix = params[:prefix]
      case params[:type]
        when JOB_TYPES[:failed]
          @condition = (prefix == "ALL") ? ["last_error is not NULL"] : ["last_error LIKE ?","#{prefix}%"]
        when JOB_TYPES[:to_be_run]
          @condition = ["run_at < ? and last_error is NULL", Time.now.utc]
        when JOB_TYPES[:scheduled_later]
          @condition = ["run_at > ? and last_error is NULL", Time.now.utc]
      end
    end

		def delayed_jobs_count
			result = {}
			result[:jobs_count] = current_job_type.find(:all, :conditions => @condition).count
      result[:total_count] = (params[:type] == JOB_TYPES[:failed]) ? current_job_type.count : nil
      result
		end

	  def run_on_slave(&block)
      Sharding.run_on_slave(&block)
    end 
end

