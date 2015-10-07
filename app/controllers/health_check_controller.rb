class HealthCheckController < ApplicationController

  skip_before_filter :check_privilege, :only => [:verify_domain]

  def verify_credential
    generate_resp
  end

  def verify_domain
    generate_resp 
  end

  private

  def generate_resp
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