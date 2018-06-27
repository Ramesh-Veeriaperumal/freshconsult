module Ember
  class CustomerImportsController < ApiApplicationController
    include ImportCsvUtil
    include CustomerImportConstants
    include HelperConcern
    include Redis::RedisKeys
    include Redis::OthersRedis

    def index
      head import_exists? ? 204 : 404
    end

    def create
      return render_request_error(:existing_import_inprogress, 409) if import_exists?
      store_file import_type
      current_account.safe_send(:"create_#{import_type}_import", IMPORT_STARTED)
      IMPORT_WORKERS[import_type].perform_async import_data
      head 204
    rescue Exception => e
      Rails.logger.error "Exception while parsing csv file for contact/company
                        import, message: #{e.message}, exception: #{e.backtrace}"
      render_errors INVALID_CSV_FILE_ERROR
    end

    def destroy
      calculate_status
      key = Object.const_get("STOP_#{import_type.upcase}_IMPORT") % { :account_id => 
                                                                      Account.current.id }
      set_others_redis_key(key, true)
      completed_imports = @completed_rows + IMPORT_BATCH_SIZE
      completed_imports = completed_imports > @total_rows ? @total_rows : completed_imports
      @status = {
        total_rows: @total_rows,
        completed_rows: completed_imports
      }
      @import.destroy
    end

    def status
      return render_request_error(:no_import_running, 409) unless import_exists?
      calculate_status
      @status = {
        total_rows: @total_rows,
        completed_rows: @completed_rows,
        percentage: @percentage,
        time_remaining: @time_remaining
      }
    end

    def self.wrap_params
      WRAP_PARAMS
    end

    private

    def scoper
      current_account.safe_send(:"#{import_type}_import")
    end

    def load_object
      @import = scoper
      log_and_render_404 unless @import
    end

    def import_data
      @item[:customers][:file_location] = file_location
      @item[:customers][:file_name] = file_name
      @item[:type] = import_type
      @item
    end

    def import_exists?
      @import = scoper
      @import.present?
    end

    def import_type
      @import_type ||= request.path.include?("contact") ? "contact" : "company"
    end

    def build_object
      @item = {
        account_id: current_account.id,
        email: current_user.email,
        customers: {
          fields: params[:fields]
        }
      }
    rescue Exception => e
      log_and_render_404
    end

    def valid_content_type?
      allowed_content_types = ALLOWED_CONTENT_TYPE_FOR_ACTION[action_name.to_sym] || [:json]
      allowed_content_types.include?(request.content_mime_type.ref)
    end

    def constants_class
      :CustomerImportConstants.to_s.freeze
    end

    def validate_params
      validate_body_params
    end

    def calculate_status
      key = Object.const_get("#{import_type.upcase}_IMPORT_TOTAL_RECORDS") % {:account_id => 
                                                                      Account.current.id}
      @total_rows = get_others_redis_key(key).to_i
      key = Object.const_get("#{import_type.upcase}_IMPORT_FINISHED_RECORDS") % {:account_id => 
                                                                          Account.current.id}
      @completed_rows = get_others_redis_key(key).to_i

      return if @completed_rows == 0
      
      @percentage = (@completed_rows*100) / (@total_rows)

      @time_taken = (Time.now.utc - @import.created_at.utc) / 60
      time_remaining = ((@total_rows-@completed_rows)*@time_taken) / (@completed_rows)*60
      @time_remaining = [time_remaining / 3600, time_remaining / 60 % 60, 
        time_remaining % 60].map { |t| t.to_i.to_s.rjust(2,'0') }.join(':')
    end

    wrap_parameters(*wrap_params)
  end
end
