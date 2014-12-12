class HealthStatusController < ApplicationController

  def index
    respond_to do |format|
      format.xml do
        render :xml => { :success => true }
      end
      format.json do
        render :json => { :success => true }
      end
    end
  end
  
end