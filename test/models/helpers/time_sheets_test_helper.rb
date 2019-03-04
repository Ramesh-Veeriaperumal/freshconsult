['users_test_helper.rb'].each { |file| require Rails.root.join("test/core/helpers/#{file}") }

module TimeSheetsTestHelper
  include UsersTestHelper

  DATETIME_FIELDS     = [:start_time, :executed_at, :created_at, :updated_at].freeze

  CONSTANT_ATTRIBUTES = [:id, :account_id, :billable, :time_spent, :timer_running, :note, :user_id].freeze

  def time_sheet_params_hash(params = {})
    {}.tap do |h|
      h[:billable]      = params[:billable] || generate_random_boolean
      h[:time_spent]    = Faker::Number.number(4)
      h[:timer_running] = generate_random_boolean
      h[:note]          = Faker::Lorem.words(10).join(' ')
      h[:user_id]       = params[:user_id] || add_agent(@account)
      h[:executed_at]   = params[:executed_at] || Time.current
    end
  end

  def cp_time_sheet_model_properties(time_sheet)
    time_sheet_params = time_sheet.attributes.symbolize_keys.slice(*CONSTANT_ATTRIBUTES)
    DATETIME_FIELDS.each do |key|
      time_sheet_params[key] = time_sheet.safe_send(key).try(:utc).try(:iso8601)
    end
    time_sheet_params
  end

  def workable_hash(time_sheet)
    {
      id: time_sheet.workable_id,
      display_id: time_sheet.workable.display_id,
      _model: time_sheet.workable_type
    }
  end

  def cp_assoc_time_sheet_pattern(time_sheet)
    {
      user: (time_sheet.user ? Hash : nil),
      workable: workable_hash(time_sheet)
    }
  end

  def cp_time_sheet_destroy_pattern(time_sheet)
    {}.tap do |h|
      h[:id]         = time_sheet.id
      h[:account_id] = time_sheet.account_id
      h[:workable] = workable_hash(time_sheet)
    end
  end

  def generate_random_boolean
    Random.rand(0..1)
  end
end
