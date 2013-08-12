class Reports::ReportFiltersController < ApplicationController
  
  include ReadsToSlave

  before_filter { |c| c.requires_feature :advanced_reporting }
  before_filter :set_data_map, :only => [:create]
  before_filter :load_report_filter , :only => [:destroy]

  def create
    @report_filter = current_user.report_filters.build(
      :report_type => @report_type,
      :filter_name => @filter_name,
      :data_hash => @data_map
    )
    @report_filter.save
    
    render :json => {:text=> "success", 
                     :status=> "ok",
                     :id => @report_filter.id,
                     :filter_name=> @filter_name,
                     :data=> @data_map }.to_json
  end

  def destroy
    @report_filter.destroy 
    render :json => {:test=> "success", :status=> "ok"}
  end
  
  private
    def load_report_filter
      @report_filter = current_account.report_filters.find(params[:id].to_i)
    end

    def set_data_map
      @data_map,data_arr = {},[]
      unless params[:data_hash].blank? 
        data_arr = params[:data_hash]
        data_arr = ActiveSupport::JSON.decode data_arr unless data_arr.kind_of?(Array)
      end
      @data_map[:data_hash] = data_arr
      @report_type, @filter_name = params[:report_type].to_i, params[:filter_name]

      @data_map[:reports_by] = params[:reports] unless params[:reports].blank?
      @data_map[:comparison_selected] = (params[:comparison_selected]) unless params[:comparison_selected].blank?
      @data_map[:metric_selected] = (params[:metric_selected]) unless params[:metric_selected].blank?
    end
end