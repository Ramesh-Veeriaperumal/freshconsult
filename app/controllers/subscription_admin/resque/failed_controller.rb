class SubscriptionAdmin::Resque::FailedController < ApplicationController
	include AdminControllerMethods
	include SubscriptionAdmin::Resque::FailedHelper

	layout "resque_admin"
	
	def index
	end

	def destroy_all
		Resque::Failure.remove_queue(params[:name])
		redirect_to :back
	end	

	def destroy
		Resque::Failure.remove(params[:id])
		redirect_to :back
	end

	def requeue		
		Resque::Failure.requeue(params[:id])
		redirect_to :back
	end	

	def show
		@failed_in_given_queue = Array.new
		count = 0
		if !params[:queue_name].nil?
			@@queue_name = params[:queue_name]
		end
		job_count = params[:job_count].to_i
		@name = @@queue_name 
		failed_hash = load_failed_array(job_count, @@queue_name, @failed_in_given_queue, count)
        @failed_in_given_queue = failed_hash[:array]
        @job_count = failed_hash[:job_parsed] 
        if request.xhr?
      		render :partial => "jobs", :object => @failed_in_given_queue
      	end
	end 
end	

