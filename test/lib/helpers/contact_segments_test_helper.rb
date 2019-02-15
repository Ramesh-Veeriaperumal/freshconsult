['segments_helper.rb'].each { |file| require Rails.root.join("test/lib/helpers/#{file}") }

module ContactSegmentsTestHelper
  include SegmentsHelper

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
                                  language: options[:blocked] || 'en',
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
