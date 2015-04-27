class Segment::GroupController < ApplicationController

   include CompaniesHelperMethods
   include APIHelperMethods

   before_filter :verify_segment_api_type, :strip_params, :company_exists, :set_required_fields, :set_validatable_custom_fields, :only => [:create]

   def create
      if @company.new_record?
         create_company   
      else 
         update_company
      end
   end

   private

   def create_company
    respond_to do |format|
      if @company.save
        format.json { render :json => @company, :status => :ok }
        format.any { head 404 }
      else
        format.json { render :json => @company.errors, :status => :bad_request }
        format.any { head 404 }
      end
    end
   end

   def update_company
    respond_to do |format|
      if @company.update_attributes(params[:company])
        format.json { head 200 }
        format.any { head 404 }
      else
        format.json { render :json => @company.errors, :status => :bad_request }
        format.any { head 404 }
      end
    end
   end

    def verify_segment_api_type
      api_error_responder({:message => t('contacts.segment_api.invalid_type')}, 501) unless params[:type] == 'group'
    end

    def strip_params
      params[:company] = params[:traits] ? params.delete(:traits) : params[:company] || {}
    end

    def company_exists
      @company = current_account.companies.find_by_name(params[:company][:name])
      build_item unless @company
    end

    def scoper
      current_account.companies
    end

    def build_item
      @company = scoper.new
      @company.attributes = params[:company]
    end
 
end