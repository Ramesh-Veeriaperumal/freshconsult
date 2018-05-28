class Dashboard::Custom::Csat < Dashboards
  CONFIG_FIELDS = [:group_ids, :time_range].freeze
  CACHE_EXPIRY = 3600
  CSAT_RESPONSE_FIELDS = { positive: { label: 'positive', value: 0 }, neutral: { label: 'neutral', value: 0 }, negative: { label: 'negative', value: 0 } }.freeze
  ALL_GROUPS = 0

  attr_accessor :options

  class << self
    include Dashboard::Custom::WidgetConfigValidationMethods

    def valid_config?(options)
      return { feature: 'survey' } unless Account.current.new_survey_enabled?
      error_options = []
      CONFIG_FIELDS.each do |field|
        error_options << field.to_s unless safe_send("validate_#{field}", options[field])
      end
      error_options.empty? ? true : { fields: error_options }
    end
  end

  def initialize(dashboard, options = {})
    @dashboard = dashboard
    @options = options
    @result = []
  end

  def result
    fetch_result
    @result
  end

  def preview
    @options[:group_ids] = nil if @options[:group_ids].present? && @options[:group_ids].include?(ALL_GROUPS.to_s)
    preview_result = Dashboard::SurveyWidget.new.filtered_records(@options)
    preview_result[:results] = format_result(preview_result)
    preview_result
  end

  private

    def fetch_result
      @dashboard.csat_widgets_from_cache.each do |widget|
        options = widget.config_data.slice(:group_ids, :time_range)
        options[:group_ids] = nil if options[:group_ids].present? && options[:group_ids].include?(ALL_GROUPS)
        survey_data = Dashboard::SurveyWidget.new.filtered_records(options)
        survey_data[:results] = format_result(survey_data)
        @result << { id: widget.id, widget_data: survey_data }
      end
    end

    def format_result(survey_data)
      response_structure = CSAT_RESPONSE_FIELDS.deep_dup
      survey_data[:results].each do |key, val|
        response_structure[key.downcase.to_sym][:value] = val
      end
      response_structure.values
    end
end
