require_relative '../test_helper'
class ExportControllerTest < ActionController::TestCase

  def test_get_export_file_url_for_valid_params
    Account.current.launch :activity_export
    date = Faker::Date.between(20.days.ago, Date.today)
    thrift = $activities_export_thrift_transport
    $activities_export_thrift_transport = StubbedThriftBufferedTransport.new
    StubbedActivityExportResponse.any_instance.stubs(:date).returns(date)
    @controller.stubs(:thrift_client).returns(StubbedTicketActivityExportClient.new)
    get :ticket_activities, controller_params(created_at: date)
    assert_response 200
    response = parse_response @response.body
    assert response["export"].is_a? Array
  ensure
    @controller.unstub(:thrift_client)
    $activities_export_thrift_transport = thrift
    StubbedActivityExportResponse.any_instance.unstub(:date)
  end

  def test_get_export_file_url_for_nil_param
    Account.current.launch :activity_export
    date = Faker::Date.between(20.days.ago, Date.today)
    thrift = $activities_export_thrift_transport
    $activities_export_thrift_transport = StubbedThriftBufferedTransport.new
    StubbedActivityExportResponse.any_instance.stubs(:date).returns(date)
    @controller.stubs(:thrift_client).returns(StubbedTicketActivityExportClient.new)
    get :ticket_activities, controller_params()
    assert_response 200
    response = parse_response @response.body
    assert response["export"].is_a? Array
  ensure
    @controller.unstub(:thrift_client)
    $activities_export_thrift_transport = thrift
    StubbedActivityExportResponse.any_instance.unstub(:date)
  end

  def test_export_with_file_not_found
    Account.current.launch :activity_export
    date = Faker::Date.between(20.days.ago, Time.zone.today)
    thrift = $activities_export_thrift_transport
    $activities_export_thrift_transport = StubbedThriftBufferedTransport.new
    StubbedActivityExportResponse.any_instance.stubs(:date).returns(date)
    StubbedActivityExportResponse.any_instance.stubs(:error_message).returns('File not found')
    StubbedActivityExportResponse.any_instance.stubs(:file_url).returns(nil)
    @controller.stubs(:thrift_client).returns(StubbedTicketActivityExportClient.new)
    get :ticket_activities, controller_params
    assert_response 404
  ensure
    @controller.unstub(:thrift_client)
    $activities_export_thrift_transport = thrift
    StubbedActivityExportResponse.any_instance.unstub(:date)
    StubbedActivityExportResponse.any_instance.unstub(:error_message)
    StubbedActivityExportResponse.any_instance.unstub(:file_url)
  end

  def test_export_with_file_not_found_without_error_message
    Account.current.launch :activity_export
    date = Faker::Date.between(20.days.ago, Time.zone.today)
    thrift = $activities_export_thrift_transport
    $activities_export_thrift_transport = StubbedThriftBufferedTransport.new
    StubbedActivityExportResponse.any_instance.stubs(:date).returns(date)
    StubbedActivityExportResponse.any_instance.stubs(:error_message).returns(nil)
    StubbedActivityExportResponse.any_instance.stubs(:file_url).returns(nil)
    @controller.stubs(:thrift_client).returns(StubbedTicketActivityExportClient.new)
    get :ticket_activities, controller_params
    assert_response 400
  ensure
    @controller.unstub(:thrift_client)
    $activities_export_thrift_transport = thrift
    StubbedActivityExportResponse.any_instance.unstub(:date)
    StubbedActivityExportResponse.any_instance.unstub(:error_message)
    StubbedActivityExportResponse.any_instance.unstub(:file_url)
  end

  def test_get_export_file_url_for_invalid_params
    Account.current.launch :activity_export
    get :ticket_activities, controller_params(created_at: 'adsasd')
    assert_response 400
  end

  class StubbedActivityExportResponse

    attr_accessor :date, :file_url, :error_message

    def file_url
      return @file_url if defined?(@file_url)
      @file_url = Faker::Internet.url
    end

    def date
      return @file_url if defined?(@file_url)
      @date = Faker::Date.between(20.days.ago, Date.today)
    end

  end

  class StubbedTicketActivityExportClient

    def get_activities_export_file(params)
      [StubbedActivityExportResponse.new]
    end
  end

  class StubbedThriftBufferedTransport
    def open
    end

    def close
    end
  end
end
