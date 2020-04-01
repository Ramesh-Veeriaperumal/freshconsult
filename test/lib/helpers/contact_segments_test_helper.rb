['segments_helper.rb'].each { |file| require Rails.root.join("test/lib/helpers/#{file}") }

module ContactSegmentsTestHelper
  include SegmentsHelper

  CONTACT_FILTER_PARAMS = {"name"=>"Today", "query_hash"=>[{"condition"=>"created_at", "operator"=>"is_greater_than", "type"=>"default", "value"=>"today"}, {"condition"=>"tag_names", "operator"=>"is_in", "type"=>"default", "value"=>["apple"]}]}
  CONTACT_UPDATED_FILTER_PARAMS = {"name"=>"This month", "query_hash"=>[{"condition"=>"created_at", "operator"=>"is_greater_than", "type"=>"default", "value"=>"month"}, {"condition"=>"tag_names", "operator"=>"is_in", "type"=>"default", "value"=>["apple", "RK"]}]}

  def create_contact_segment
    contact_filter = @account.contact_filters.new({name: Faker::Name.name, data: CONTACT_FILTER_PARAMS["query_hash"]})
    contact_filter.save!
    contact_filter
  end

  def create_contact(options={})
    if options[:email]
      user = User.find_by_email(options[:email])
      return user if user
    end
    new_user = FactoryGirl.build(:user,
                                  account: account,
                                  name: options[:name] || Faker::Name.name,
                                  email: options[:email] || Faker::Internet.email,
                                  time_zone: options[:time_zone] || 'Chennai',
                                  delta: 1,
                                  deleted: options[:deleted] || 0,
                                  blocked: options[:blocked] || 0,
                                  company_ids: options[:company_ids] || [],
                                  language: options[:language] || 'en',
                                  active: options[:active] || false,
                                  tag_names: options[:tag_names] || "",
                                  created_at: options[:created_at] || Time.zone.now)
    if options[:unique_external_id]
      new_user.unique_external_id = options[:unique_external_id]
    end
    new_user.custom_field = options[:custom_fields] if options.key?(:custom_fields)
    new_user.save_without_session_maintenance
    new_user.reload
  end

  def all_fields
    field_scoper.contact_fields_from_cache
  end

  def allowed_default_fields
    Segments::FilterDataConstants::ALLOWED_CONTACT_DEFAULT_FIELDS
  end

  def field_scoper
    account.contact_form
  end

  def segment_scoper
    account.contact_filters
  end
end
