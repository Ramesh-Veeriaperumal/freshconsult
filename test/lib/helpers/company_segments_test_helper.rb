['segments_helper.rb', 'company_helper.rb'].each { |file| require Rails.root.join("test/lib/helpers/#{file}") }

module CompanySegmentsTestHelper
  include SegmentsHelper
  include ApiCompanyHelper

  def all_fields
    field_scoper.company_fields_from_cache
  end

  def allowed_default_fields
    Segments::FilterDataConstants::ALLOWED_COMPANY_DEFAULT_FIELDS
  end

  def field_scoper
    account.company_form
  end

  def segment_scoper
    account.company_filters
  end
end
