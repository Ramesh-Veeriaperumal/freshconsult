class TimeSheetsController < ApiApplicationController
  before_filter :validate_filter_params, only: [:index]

  def index
    load_objects(time_sheet_filter.includes(:workable))
  end

  private

    def scoper
      current_account.time_sheets
    end

    def time_sheet_filter
      time_sheet_filter_params = params.slice(*ApiConstants::INDEX_TIMESHEET_FIELDS)
      scoper.filter(time_sheet_filter_params)
    end

    def validate_filter_params
      params.permit(*ApiConstants::INDEX_TIMESHEET_FIELDS, *ApiConstants::DEFAULT_PARAMS, *ApiConstants::DEFAULT_INDEX_FIELDS)
      timesheet_filter = TimeSheetFilterValidation.new(params, nil)
      render_error timesheet_filter.errors unless timesheet_filter.valid?
    end
end
