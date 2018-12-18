class HelpdeskReports::Export::SatisfactionSurvey < HelpdeskReports::Export::Report
  include HelpdeskReports::Export::FieldsHelper
  include HelpdeskReports::Constants::Export
  include Reports::CustomSurveyReport

  def initialize(args)
    args.symbolize_keys!
    survey_report_params(args)
    super
  end

  def build_export
    csv_string = generate_survey_data
    @survey_data_exists ? build_file(csv_string , file_format, report_type, PDF_EXPORT_TYPE) : nil
  end

  def survey_report_params args
    args[:data_hash].symbolize_keys!

    args.merge!({
      :agent_id    => args[:data_hash][:agent_id],
      :group_id    => args[:data_hash][:group_id],
      :survey_id   => args[:data_hash][:survey_id],
      :filter_name => args[:data_hash][:filter_name],
      :select_hash => args[:data_hash][:select_hash],
      :date_range  => args[:data_hash][:date]['date_range']
    })
  end

  private
  
    def generate_file
      build_file(file_string, file_format, report_type, PDF_EXPORT_TYPE)
    end

end
