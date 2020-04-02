['segments_helper.rb', 'company_helper.rb'].each { |file| require Rails.root.join("test/lib/helpers/#{file}") }

module CompanySegmentsTestHelper
  include SegmentsHelper
  include ApiCompanyHelper

  COMPANY_FILTER_PARAMS = { 'name' => 'First Com Filter', 'query_hash' => [{ 'condition' => 'created_at', 'operator' => 'is_greater_than', 'type' => 'default', 'value' => 'today' }] }
  COMPANY_UPDATED_FILTER_PARAMS = { 'name'=>'First Com Filter', 'query_hash'=>[{ 'condition' => 'created_at', 'operator' => 'is_greater_than', 'type' => 'default', 'value' => 'month' }] }

    def create_company_segment
      company_filter = @account.company_filters.new({name: Faker::Name.name, data: COMPANY_FILTER_PARAMS["query_hash"]})
      company_filter.save!
      company_filter
    end

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
