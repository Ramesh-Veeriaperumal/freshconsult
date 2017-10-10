require_relative '../../test_helper'
module ApiSearch
  class ContactsControllerTest < ActionController::TestCase
    include SearchTestHelper

    CHOICES = ['Get Smart', 'Pursuit of Happiness', 'Armaggedon'].freeze

    def setup
      super
      initial_setup
    end

    @@initial_setup_run = false

    def initial_setup
      return if @@initial_setup_run
      @account.launch(:service_reads)
      @account.launch(:service_writes)
      create_contact_field(cf_params(type: 'text', field_type: 'custom_text', label: 'sample_text', editable_in_signup: 'true'))
      create_contact_field(cf_params(type: 'number', field_type: 'custom_number', label: 'sample_number', editable_in_signup: 'true'))
      create_contact_field(cf_params(type: 'checkbox', field_type: 'custom_checkbox', label: 'sample_checkbox', editable_in_signup: 'true'))
      create_contact_field(cf_params(type: 'date', field_type: 'custom_date', label: 'sample_date', editable_in_signup: 'true'))

      create_contact_field(cf_params(type: 'text', field_type: 'custom_dropdown', label: 'sample_dropdown', editable_in_signup: 'true'))

      cfid = ContactField.find_by_name('cf_sample_dropdown').id
      ContactFieldChoice.create(value: CHOICES[0], position: 1)
      ContactFieldChoice.create(value: CHOICES[1], position: 2)
      ContactFieldChoice.create(value: CHOICES[2], position: 3)
      ContactFieldChoice.update_all(account_id: @account.id)
      ContactFieldChoice.update_all(contact_field_id: cfid)

      3.times { Company.create(name: Faker::Name.name, account_id: @account.id) }
      @account.reload
      clear_es(@account.id)
      30.times { create_search_contact(contact_params_hash) }
      @account.contacts.last(5).map { |x| x.update_attributes('cf_sample_date' => nil, 'customer_id' => nil) }
      write_data_to_es(@account.id)
      @@initial_setup_run = true
    end

    def wrap_cname(params)
      { api_search: params }
    end

    def contact_params_hash
      tags = %w(tag1 tag2 tag3 TAG4 TAG5 TAG6)
      special_chars = ['!', '#', '$', '%', '&', '(', ')', '*', '+', ',', '-', '.', '/', ':', ';', '<', '=', '>', '?', '@', '[', '\\', ']', '^', '_', '`', '{', '|', '}', '~']
      email = Faker::Internet.email
      twitter_id = Faker::Internet.user_name
      company_id = @account.company_ids[rand(3)]
      mobile = Faker::Number.number(10)
      phone = Faker::Number.number(10)
      n = rand(10)
      custom_fields = { cf_sample_number: rand(5) + 1, cf_sample_checkbox: rand(5) % 2 ? true : false, cf_sample_text: Faker::Lorem.word + ' ' + special_chars.join, cf_sample_date: rand(10).days.until, cf_sample_dropdown: CHOICES[rand(3)] }

      custom_fields[:cf_sample_number] = nil if n % 3 == 0
      custom_fields[:cf_sample_text] = nil if n % 4 == 0
      custom_fields[:cf_sample_date] = nil if n < 3 == 0

      params_hash = { email: email, twitter_id: twitter_id, customer_id: company_id, mobile: mobile, phone: phone, tags: [tags[rand(6)], tags[rand(6)]].uniq, language: ContactConstants::LANGUAGES[n],
                      time_zone: ContactConstants::TIMEZONES[n], custom_field: custom_fields, created_at: n.days.until.iso8601, updated_at: (n + 2).days.until.iso8601, active: true }
      params_hash[:tags] = nil if n < 5
      params_hash[:active] = false if n < 4
      params_hash[:mobile] = nil if n == 4
      params_hash[:phone] = nil if n == 2
      params_hash
    end

    def test_contacts_active
      contacts = @account.contacts.select(&:active?)
      get :index, controller_params(query: '"active:true"')
      assert_response 200
      pattern = contacts.map { |contact| index_contact_pattern(contact) }
      match_json(results: pattern, total: contacts.size)
    end

    def test_contacts_invalid_query_format
      get :index, controller_params(query: 'company_id:1 OR company_id:2')
      assert_response 400
      match_json([bad_request_error_pattern('query', :query_format_invalid)])
    end

    def test_contacts_invalid_date_format
      get :index, controller_params(query: '"created_at:>\'20170707\'"')
      assert_response 400
      match_json([bad_request_error_pattern('query', :query_format_invalid)])
    end

    def test_contacts_valid_date
      d1 = (Date.today - 1).iso8601
      contacts = @account.contacts.select { |x| x.created_at.utc.to_date.iso8601 <= d1 }
      get :index, controller_params(query: '"created_at :< \'' + d1 + '\'"')
      assert_response 200
      pattern = contacts.map { |contact| index_contact_pattern(contact) }
      match_json(results: pattern, total: contacts.size)
    end

    def test_contacts_valid_range
      d1 = (Date.today - 8).iso8601
      d2 = (Date.today - 1).iso8601
      contacts = @account.contacts.select { |x| x.created_at.utc.to_date.iso8601 >= d1 && x.created_at.utc.to_date.iso8601 <= d2 }
      get :index, controller_params(query: '"(created_at :> \'' + d1 + '\' AND created_at :< \'' + d2 + '\')"')
      assert_response 200
      pattern = contacts.map { |contact| index_contact_pattern(contact) }
      match_json(results: pattern, total: contacts.size)
    end

    def test_contacts_valid_range_and_filter
      d1 = (Date.today - 8).iso8601
      d2 = (Date.today - 1).iso8601
      contacts = @account.contacts.select { |x| (x.created_at.utc.to_date.iso8601 >= d1 && x.created_at.utc.to_date.iso8601 <= d2) && x.customer_id == 2 }
      get :index, controller_params(query: '"(created_at :> \'' + d1 + '\' AND created_at :< \'' + d2 + '\') AND company_id:2 "')
      assert_response 200
      pattern = contacts.map { |contact| index_contact_pattern(contact) }
      match_json(results: pattern, total: contacts.size)
    end

    def test_contacts_created_on_a_day
      d1 = Date.today.to_date.iso8601
      contacts = @account.contacts.select { |x| x.created_at.utc.to_date.iso8601 == d1 && x.deleted == false }
      get :index, controller_params(query: '"created_at: \'' + d1 + '\'"')
      assert_response 200
      response = parse_response @response.body
      assert response['total'] == contacts.size
    end

    def test_contacts_updated_on_a_day
      d1 = (Date.today + 2).to_date.iso8601
      contacts = @account.contacts.select { |x| x.updated_at.utc.to_date.iso8601 == d1 }
      get :index, controller_params(query: '"updated_at: \'' + d1 + '\'"')
      assert_response 200
      response = parse_response @response.body
      assert response['total'] == contacts.size
    end

    # def test_contacts_custom_date_on_a_day
    #   d1 = Date.today.to_date.iso8601
    #   contacts = @account.contacts.select { |x| x.cf_sample_date && x.cf_sample_date.utc.to_date.iso8601 == d1 }
    #   get :index, controller_params(query: '"sample_date: \'' + d1 + '\'"')
    #   assert_response 200
    #   pattern = contacts.map { |contact| index_contact_pattern(contact) }
    #   match_json(results: pattern, total: contacts.size)
    # end

    # def test_contacts_custom_date_valid_range_and_filter
    #   d1 = (Date.today - 8).iso8601
    #   d2 = (Date.today - 1).iso8601
    #   contacts = @account.contacts.select { |x| x.cf_sample_date && (x.cf_sample_date.utc.to_date.iso8601 >= d1 && x.cf_sample_date.utc.to_date.iso8601 <= d2) }
    #   get :index, controller_params(query: '"(sample_date :> \'' + d1 + '\' AND sample_date :< \'' + d2 + '\')"')
    #   assert_response 200
    #   pattern = contacts.map { |contact| index_contact_pattern(contact) }
    #   match_json(results: pattern, total: contacts.size)
    # end

    # def test_contacts_custom_date_null
    #   contacts = @account.contacts.select { |x| x.cf_sample_date.nil? }
    #   get :index, controller_params(query: '"sample_date : null"')
    #   assert_response 200
    #   pattern = contacts.map { |contact| index_contact_pattern(contact) }
    #   match_json(results: pattern, total: contacts.size)
    # end

    def test_contacts_company_id
      contacts = @account.contacts.select { |x| [1, 2].include?(x.customer_id) }
      get :index, controller_params(query: '"company_id:1 OR company_id:2"')
      assert_response 200
      pattern = contacts.map { |contact| index_contact_pattern(contact) }
      match_json(results: pattern, total: contacts.size)
    end

    def test_contacts_company_id_null
      contacts = @account.contacts.select { |x| x.customer_id.nil? }
      get :index, controller_params(query: '"company_id:null"')
      assert_response 200
      response = parse_response @response.body
      assert response['total'] == contacts.size
    end

    def test_contacts_custom_fields
      contacts = @account.contacts.select { |x| x.custom_field['cf_sample_number'] == 1 || x.custom_field['cf_sample_checkbox'] == true || x.company_id == 2 }
      get :index, controller_params(query: '"sample_number:1 OR sample_checkbox:true OR company_id:2"')
      assert_response 200
      pattern = contacts.map { |contact| index_contact_pattern(contact) }
      match_json(results: pattern, total: contacts.size)
    end

    def test_contacts_invalid_email
      get :index, controller_params(query: '"email:\'aabbccdd\'"')
      assert_response 400
      match_json([bad_request_error_pattern('email', "It should contain elements that are in the 'valid email address' format")])
    end

    def test_contacts_email_filter
      email1 = @account.contacts.first.email
      email2 = @account.contacts.last.email
      contacts = @account.contacts.select { |x| [email1, email2].include?(x.email) }
      get :index, controller_params(query: '"email:\'' + email1 + '\' or email:\'' + email2 + '\'"')
      assert_response 200
      pattern = contacts.map { |contact| index_contact_pattern(contact) }
      match_json(results: pattern, total: contacts.size)
    end

    def test_contacts_email_combined_condition
      email1 = @account.contacts.first.email
      email2 = @account.contacts.last.email
      d1 = @account.contacts.last.created_at.to_date.iso8601
      contacts = @account.contacts.select { |x| ([email1, email2].include?(x.email) || x.created_at.utc.to_date.iso8601 == d1) && x.deleted == false }
      get :index, controller_params(query: '"(email:\'' + email1 + '\' or email:\'' + email2 + '\') or created_at:\'' + d1 + '\'"')
      assert_response 200
      response = parse_response @response.body
      assert response['total'] == contacts.size
    end

    def test_contacts_invalid_email
      get :index, controller_params(query: '"email:\'aabbccdd\'"')
      assert_response 400
      match_json([bad_request_error_pattern('email', "It should contain elements that are in the 'valid email address' format")])
    end

    def test_contacts_email_null
      contacts = @account.contacts.select { |x| x.email.nil? }
      get :index, controller_params(query: '"email : null"')
      assert_response 200
      pattern = contacts.map { |contact| index_contact_pattern(contact) }
      match_json(results: pattern, total: contacts.size)
    end

    def test_contacts_valid_tag
      contacts = @account.contacts.select { |x| x.tag_names.include?('tag1') || x.tag_names.include?('TAG4') }
      get :index, controller_params(query: '"tag:tag1 or tag:\'TAG4\'"')
      assert_response 200
      pattern = contacts.map { |contact| index_contact_pattern(contact) }
      match_json(results: pattern, total: contacts.size)
    end

    def test_contacts_tag_case_sensitive
      get :index, controller_params(query: '"tag:tag4"')
      assert_response 200
      response = parse_response @response.body
      assert response['total'] == 0
    end

    def test_contacts_tag_invalid_length
      get :index, controller_params(query: '"tag:' + 'a' * 33 + '"')
      assert_response 400
      match_json([bad_request_error_pattern('tag', :array_too_long, max_count: ApiConstants::TAG_MAX_LENGTH_STRING, element_type: :characters)])
    end

    def test_contacts_tag_null
      contacts = @account.contacts.select { |x| x.tags.empty? }
      get :index, controller_params(query: '"tag : null"')
      assert_response 200
      response = parse_response @response.body
      assert response['total'] == contacts.size
    end

    def test_contacts_twitter_id_filter
      twitter1, twitter2 = @account.contacts.map(&:twitter_id).reject(&:blank?).uniq.first(2)
      contacts = @account.contacts.select { |x| [twitter1, twitter2].include?(x.twitter_id) }
      get :index, controller_params(query: '"twitter_id:\'' + twitter1 + '\' or twitter_id:\'' + twitter2 + '\'"')
      assert_response 200
      pattern = contacts.map { |contact| index_contact_pattern(contact) }
      match_json(results: pattern, total: contacts.size)
    end

    def test_contacts_twitter_id_null
      contacts = @account.contacts.select { |x| x.twitter_id.nil? }
      get :index, controller_params(query: '"twitter_id : null"')
      assert_response 200
      response = parse_response @response.body
      assert response['total'] == contacts.size
    end

    def test_contacts_mobile_filter
      mobile1, mobile2 = @account.contacts.map(&:mobile).reject(&:blank?).uniq.first(2)
      contacts = @account.contacts.select { |x| [mobile1, mobile2].include?(x.mobile) }
      get :index, controller_params(query: '"mobile:\'' + mobile1 + '\' or mobile:\'' + mobile2 + '\'"')
      assert_response 200
      pattern = contacts.map { |contact| index_contact_pattern(contact) }
      match_json(results: pattern, total: contacts.size)
    end

    def test_contacts_mobile_null
      contacts = @account.contacts.select { |x| x.mobile.nil? }
      get :index, controller_params(query: '"mobile : null"')
      assert_response 200
      response = parse_response @response.body
      assert response['total'] == contacts.size
    end

    def test_contacts_phone_filter
      phone1, phone2 = @account.contacts.map(&:phone).reject(&:blank?).uniq.first(2)
      contacts = @account.contacts.select { |x| [phone1, phone2].include?(x.phone) }
      get :index, controller_params(query: '"phone:\'' + phone1 + '\' or phone:\'' + phone2 + '\'"')
      assert_response 200
      pattern = contacts.map { |contact| index_contact_pattern(contact) }
      match_json(results: pattern, total: contacts.size)
    end

    def test_contacts_phone_null
      contacts = @account.contacts.select { |x| x.phone.nil? }
      get :index, controller_params(query: '"phone : null"')
      assert_response 200
      response = parse_response @response.body
      assert response['total'] == contacts.size
    end

    def test_contacts_language_filter
      language1, language2 = @account.contacts.map(&:language).reject(&:blank?).uniq.first(2)
      contacts = @account.contacts.select { |x| [language1, language2].include?(x.language) }
      get :index, controller_params(query: '"language:\'' + language1 + '\' or language:\'' + language2 + '\'"')
      assert_response 200
      pattern = contacts.map { |contact| index_contact_pattern(contact) }
      match_json(results: pattern, total: contacts.size)
    end

    def test_contacts_invalid_language
      get :index, controller_params(query: '"language:\'aaaa\'"')
      assert_response 400
      match_json([bad_request_error_pattern('language', :not_included, list: ContactConstants::LANGUAGES.join(','))])
    end

    def test_contacts_time_zone_filter
      time_zone1, time_zone2 = @account.contacts.map(&:time_zone).reject(&:blank?).uniq.first(2)
      contacts = @account.contacts.select { |x| [time_zone1, time_zone2].include?(x.time_zone) }
      get :index, controller_params(query: '"time_zone:\'' + time_zone1 + '\' or time_zone:\'' + time_zone2 + '\'"')
      assert_response 200
      pattern = contacts.map { |contact| index_contact_pattern(contact) }
      match_json(results: pattern, total: contacts.size)
    end

    def test_contacts_invalid_time_zone
      get :index, controller_params(query: '"time_zone:\'bbbb\'"')
      assert_response 400
      match_json([bad_request_error_pattern('time_zone', :not_included, list: ContactConstants::TIMEZONES.join(','))])
    end

    # Custom fields

    def test_contacts_custom_dropdown_null
      contacts = @account.contacts.select { |x| x.cf_sample_dropdown.nil? }
      get :index, controller_params(query: '"sample_dropdown: null"')
      assert_response 200
      pattern = contacts.map { |contact| index_contact_pattern(contact) }
      match_json(results: pattern, total: contacts.size)
    end

    def test_contacts_custom_dropdown_valid_choice
      choice = CHOICES[rand(3)]
      contacts = @account.contacts.select { |x| x.cf_sample_dropdown == choice }
      get :index, controller_params(query: '"sample_dropdown:\'' + choice + '\' "')
      assert_response 200
      pattern = contacts.map { |contact| index_contact_pattern(contact) }
      match_json(results: pattern, total: contacts.size)
    end

    def test_contacts_custom_dropdown_invalid_choice
      get :index, controller_params(query: '"sample_dropdown:aaabbbccc"')
      assert_response 400
      match_json([bad_request_error_pattern('sample_dropdown', :not_included, list: CHOICES.join(','))])
    end

    def test_contacts_custom_dropdown_combined_condition
      choice = CHOICES[rand(3)]
      contacts = @account.contacts.select { |x| x.cf_sample_dropdown == choice && x.active? }
      get :index, controller_params(query: '"sample_dropdown:\'' + choice + '\' AND active:true"')
      assert_response 200
      pattern = contacts.map { |contact| index_contact_pattern(contact) }
      match_json(results: pattern, total: contacts.size)
    end

    def test_custom_number_null
      contacts = @account.contacts.select { |x| x.cf_sample_number.nil? }
      get :index, controller_params(query: '"sample_number: null"')
      assert_response 200
      pattern = contacts.map { |contact| index_contact_pattern(contact) }
      match_json(results: pattern, total: contacts.size)
    end

    def test_contacts_custom_fields_string_value_for_custom_number
      get :index, controller_params(query: '"sample_number:\'123\'"')
      assert_response 400
    end

    def test_custom_text_null
      contacts = @account.contacts.select { |x| x.cf_sample_text.nil? }
      get :index, controller_params(query: '"sample_text: null"')
      assert_response 200
      pattern = contacts.map { |contact| index_contact_pattern(contact) }
      match_json(results: pattern, total: contacts.size)
    end

    def test_contacts_custom_text_special_characters
      text = @account.contacts.map(&:cf_sample_text).compact.last(2)
      contacts = @account.contacts.select { |x| text.include?(x.cf_sample_text) }
      get :index, controller_params(query: "\"sample_text:'#{text[0]}' or sample_text:'#{text[1]}'\"")
      assert_response 200
      pattern = contacts.map { |contact| index_contact_pattern(contact) }
      match_json(results: pattern, total: contacts.size)
    end

    def test_contacts_custom_text_invalid_special_characters
      get :index, controller_params(query: "\"sample_text:'aaa\'a' or sample_text:'aaa\"aa'\"")
      assert_response 400
    end

    def test_contacts_filter_using_custom_checkbox
      contacts = @account.contacts.select { |x| x.cf_sample_checkbox == true }
      get :index, controller_params(query: '"sample_checkbox:true"')
      assert_response 200
      pattern = contacts.map { |contact| index_contact_pattern(contact) }
      match_json(results: pattern, total: contacts.size)
    end

    def test_contacts_combined_condition
      choice = CHOICES[rand(3)]
      contacts = @account.contacts.select { |x| x.cf_sample_dropdown == choice && x.active? && x.cf_sample_checkbox == true && x.cf_sample_text.nil? }
      get :index, controller_params(query: '"sample_dropdown:\'' + choice + '\' AND active:true AND sample_checkbox:true AND sample_text:null"')
      assert_response 200
      pattern = contacts.map { |contact| index_contact_pattern(contact) }
      match_json(results: pattern, total: contacts.size)
    end

    # custom date not allowed
    def test_contacts_custom_date
      d1 = Date.today.to_date.iso8601
      get :index, controller_params(query: '"sample_date: \'' + d1 + '\'"')
      assert_response 400
      match_json([bad_request_error_pattern('sample_date', :invalid_field)])
    end
  end
end
