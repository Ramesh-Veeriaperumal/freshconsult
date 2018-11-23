
class ApiCustomerImportsController < ApiApplicationController
  include ImportCsvUtil
  include CustomerImportConstants
  include HelperConcern
  include Redis::RedisKeys
  include Redis::OthersRedis

  def index
    super
    @import_items = []
    @imports.each do |import|
      @import_items << fetch_import_details(import)
    end
  end

  def create
    return render_request_error(:existing_import_inprogress, 429) if import_exists?
    @import = scoper.create!(IMPORT_STARTED)
    store_import_file
    IMPORT_WORKERS[import_type].perform_async import_data
    fetch_import_details(@import)
  rescue Exception => e
    Rails.logger.error "Exception while parsing csv file for contact/company
                      import, message: #{e.message}, exception: #{e.backtrace}"
    render_errors INVALID_CSV_FILE_ERROR
    @import.failure!(e.message + "\n" + e.backtrace.join("\n")) if @import
  end

  def cancel
    return head 404 unless in_progress_values.include?(@import.import_status)
    key = format(Object.const_get("STOP_#{import_type.upcase}_IMPORT"), account_id: Account.current.id)
    set_others_redis_key(key, true)
    @import.cancelled!
    fetch_import_details(@import)
    return unless @import_item[:completed_records]
    completed_imports = @import_item[:completed_records] + IMPORT_BATCH_SIZE
    @import_item[:completed_records] = if completed_imports > @import_item[:total_records]
                                         @import_item[:total_records]
                                       else
                                         completed_imports
                                       end
  end

  def show
    fetch_import_details(@import)
  end

  def self.wrap_params
    WRAP_PARAMS
  end

  private

    def scoper
      current_account.safe_send(:"#{import_type}_imports")
    end

    def load_object
      @import = scoper.find_by_id(params[:id])
      log_and_render_404 unless @import
    end

    def import_data
      @item[:customers][:file_location] = file_location
      @item[:customers][:file_name] = file_name
      @item[:type] = import_type
      @item[:data_import] = @import.id
      @item
    end

    def import_exists?
      @import = scoper.safe_send(:"running_#{import_type}_imports").first
      @import.present?
    end

    def import_type
      @import_type ||= request.path.include?('contact') ? 'contact' : 'company'
    end

    def build_object
      @item = {
        account_id: current_account.id,
        email: current_user.email,
        customers: {
          fields: params[:fields]
        }
      }
    rescue
      log_and_render_404
    end

    def store_import_file
      store_file import_type
      file_info
      set_counts import_type
    end

    def load_objects
      conditions = params[:status] ? filter_conditions : {}
      @imports = scoper.find(:all, conditions: conditions, order: 'created_at DESC', limit: 5)
    end

    def filter_conditions
      import_status = []
      status = params[:status].split(',').map!(&:strip)
      import_status << in_progress_values if status.include?('in_progress')
      import_status << Admin::DataImport::IMPORT_STATUS.values_at(*status.map(&:to_sym))
      { import_status: import_status.flatten.compact }
    end

    def validate_filter_params
      @validation_klass = 'CustomerImportFilterValidation'
      validate_query_params
    end

    def valid_content_type?
      allowed_content_types = ALLOWED_CONTENT_TYPE_FOR_ACTION[action_name.to_sym] || [:json]
      allowed_content_types.include?(request.content_mime_type.ref)
    end

    def constants_class
      :CustomerImportConstants.to_s.freeze
    end

    def validate_params
      params_hash = params[cname].merge(import_type: import_type)
      return false unless validate_body_params(nil, params_hash)
    end

    wrap_parameters(*wrap_params)
end
