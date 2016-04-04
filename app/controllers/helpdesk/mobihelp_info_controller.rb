class Helpdesk::MobihelpInfoController < ApplicationController

  before_filter :load_ticket, :only => [:index]

  def index
    respond_to do |format|
      format.html {
        if @debug_data
          @json_data_str = AwsWrapper::S3Object.read(@debug_data.content.path(:original),@debug_data.content.bucket_name)
        end
        render :index, :layout => false
      }
      format.json {
        json_data = {
          :app_name => @extra_info.app_name,
          :app_version => @extra_info.app_version,
          :os => @extra_info.os,
          :os_version => @extra_info.os_version,
          :device_make => @extra_info.device_make,
          :device_model => @extra_info.device_model,
          :sdk_version => @extra_info.sdk_version,
          :debug_data_url => AwsWrapper::S3Object.url_for(@debug_data.content.path(:original),@debug_data.content.bucket_name, :expires => 300.seconds, :secure => true, :response_content_type => @debug_data.content_content_type)
        }
        render :json => json_data
      }
    end
  end

  private
    def load_ticket
      @ticket = current_account.tickets.find_by_display_id(params[:ticket_id])
      unless @ticket.nil?
        @extra_info = @ticket.mobihelp_ticket_info
        @debug_data = @extra_info.debug_data unless @extra_info.nil?
      end
    end
end
