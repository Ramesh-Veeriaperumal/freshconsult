require_relative '../../api/test_helper'
class SupportControllerTest < ActionController::TestCase
  def test_sitemap_without_feature
    stub_sitemap do
      Account.any_instance.stubs(:sitemap_enabled?).returns(false)
      get :sitemap, format: 'xml'
      assert_response 404
    end
  ensure
    Account.any_instance.unstub(:sitemap_enabled?)
  end

  def test_sitemap_without_generating
    get :sitemap, format: 'xml'
    assert_response 404
  ensure
    AwsWrapper::S3Object.unstub(:reads)
  end

  def test_sitemap
    stub_sitemap do
      get :sitemap, format: 'xml'
      assert_response 200
    end
  ensure
    AwsWrapper::S3Object.unstub(:reads)
  end

  private

    def stub_sitemap
      xml_file = Community::Sitemap.new(@account.main_portal).build
      Portal.any_instance.stubs(:fetch_sitemap).returns(xml_file)
      yield
    ensure
      Portal.any_instance.unstub(:fetch_sitemap)
    end
end
