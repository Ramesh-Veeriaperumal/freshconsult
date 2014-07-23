class Integrations::IntegratedResourcesController < ApplicationController

  before_filter :add_account_id

  def add_account_id
    params[:integrated_resource][:account] = current_account
  end

  def create
    Rails.logger.debug "Creating new integrated resource "+params.inspect
    begin
      newIntegratedResource = Integrations::IntegratedResource.createResource(params)
      if newIntegratedResource.blank?
        render :json => {:status=>:error}
      else
        render :json => newIntegratedResource
      end
    rescue Exception => msg
      puts "Something went wrong while creating an integrated resource ( #{msg})"
      render :json => {:status=>:error}
    end
  end

  def update #possible dead code
    Rails.logger.debug "Editing integrated resource "+params.inspect
    begin
      newIntegratedResource = Integrations::IntegratedResource.updateResource(params)
      if newIntegratedResource.blank?
        render :json => {:status=>:error}
      else
        render :json => newIntegratedResource
      end
    rescue Exception => msg
      puts "Something went wrong while updating an integrated resource ( #{msg})"
      render :json => {:status=>:error}
    end
  end

  def delete
    Rails.logger.debug "Deleting integrated resource "+params.inspect
    begin
      status = Integrations::IntegratedResource.deleteResource(params)
      if status
        render :json => {:status=>status}
      else
        render :json => {:status=>:error}
      end
    rescue Exception => msg
      puts "Something went wrong while deleting an integrated resource ( #{msg})"
      render :json => {:status=>:error}
    end
  end
end
