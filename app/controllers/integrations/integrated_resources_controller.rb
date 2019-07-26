class Integrations::IntegratedResourcesController < ApplicationController

  before_filter :add_account_id

  def add_account_id
    params[:integrated_resource][:account] = current_account
  end

  def create
    begin
      newIntegratedResource = Integrations::IntegratedResource.createResource(params)
      if newIntegratedResource.blank?
        render :json => {:status=>:error}
      else
        render :json => newIntegratedResource
      end
    rescue Exception => msg
      Rails.logger.error "Something went wrong while creating an integrated resource ( #{msg})"
      render :json => {:status=>:error}
    end
  end

  def update #possible dead code
    begin
      newIntegratedResource = Integrations::IntegratedResource.updateResource(params)
      if newIntegratedResource.blank?
        render :json => {:status=>:error}
      else
        render :json => newIntegratedResource
      end
    rescue Exception => msg
      Rails.logger.error "Something went wrong while updating an integrated resource ( #{msg})"
      render :json => {:status=>:error}
    end
  end

  def delete
    begin
      status = Integrations::IntegratedResource.deleteResource(params)
      if status
        render :json => {:status=>status}
      else
        render :json => {:status=>:error}
      end
    rescue Exception => msg
      Rails.logger.error "Something went wrong while deleting an integrated resource ( #{msg})"
      render :json => {:status=>:error}
    end
  end
end
