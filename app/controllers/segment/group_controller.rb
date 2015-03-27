class Segment::GroupController < ApplicationController

   include CompaniesHelperMethods

   before_filter :strip_params, :company_exists, :set_required_fields, :set_validatable_custom_fields, :only => [:create]

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
        format.json { render :json => @company, :status => :created }
        format.any { head 404 }
      else
        format.json { render :json => @company.errors, :status => :unprocessable_entity }
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
        format.json { render :json => @company.errors, :status => :unprocessable_entity }
        format.any { head 404 }
      end
    end
   end

   def strip_params
      params[:company] = params.delete :traits || {}
   end

   def company_exists
      @company = current_account.companies.find_by_name(params[:company][:name])
      build_item unless @company
   end
 
end