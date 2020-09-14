require_relative '../../../../test_helper'
module Channel::V2::ApiSolutions
  class FoldersControllerTest < ActionController::TestCase
    include JweTestHelper
    include SolutionsTestHelper
    include SolutionFoldersTestHelper
    include SolutionsPlatformsTestHelper

    SUPPORT_BOT = 'frankbot'.freeze

    def setup
      super
      initial_setup
    end

    @@initial_setup_run = false

    def initial_setup
      return if @@initial_setup_run
      additional = @account.account_additional_settings
      additional.supported_languages = ["es","ru-RU"]
      additional.save
      @account.features.enable_multilingual.create
      @account.reload
      @@initial_setup_run = true
    end

    def create_company
      company = Company.create(name: Faker::Name.name, account_id: @account.id)
      company.save
      company
    end

    def get_company
      company ||= create_company
    end

    def wrap_cname(params)
      { folder: params }
    end

    def meta_scoper
      @account.solution_folder_meta.where(is_default: false)
    end

    def get_folder
      meta_scoper.collect{ |x| x.children }.flatten.first
    end

    def get_category
      @account.solution_category_meta.where(is_default: false).first
    end

    def get_category_with_folders
      @account.solution_category_meta.where(is_default: false).select { |x| x if x.children.count > 0 }.first
    end

    def get_folder_without_translation
      meta_scoper.select{|x| x.children if x.children.count == 1}.first
    end

    def get_folder_with_translation
      meta_scoper.select{|x| x.children if x.children.count > 1}.first
    end

    def get_default_folder
      @account.solution_folder_meta.where(is_default: true).first.children.first
    end

    def test_show_folder
      set_jwe_auth_header(SUPPORT_BOT)
      sample_folder = get_folder
      get :show, controller_params(id: sample_folder.parent_id)
      p response.body
      assert_response 200
    end

    def test_show_unavailable_folder
      set_jwe_auth_header(SUPPORT_BOT)
      get :show, controller_params(id: 99999)
      assert_response :missing
    end

    def test_folder_filter_with_portal_id
      setup_channel_api do
        set_jwe_auth_header(SUPPORT_BOT)
        portal_id = @account.portals.first.id
        folders = get_folders_by_portal_id(portal_id)

        get :folder_filter, controller_params(version: 'channel', portal_id: portal_id)
        assert_response 200
        expected_response = folders.map { |folder_obj| solution_folder_pattern_index_channel_api(folder_obj) }
        match_json(expected_response)
      end
    end

    def test_folder_filter_with_invalid_portal_id
      setup_channel_api do
        set_jwe_auth_header(SUPPORT_BOT)

        get :folder_filter, controller_params(version: 'channel', portal_id: 9999)
        assert_response 400
        match_json(validation_error_pattern(bad_request_error_pattern('portal_id', :invalid_portal_id, code: :invalid_value)))
      end
    end

    def test_folder_filter_with_language
      setup_channel_api do
        set_jwe_auth_header(SUPPORT_BOT)
        portal_id = @account.portals.first.id
        language = 'ru-RU'
        language_object = Language.find_by_code(language)

        create_folder_translation(language_object.to_key)
        folders = @account.solution_folders.where(language_id: language_object.id)

        get :folder_filter, controller_params(version: 'channel', language: language)
        assert_response 200
        expected_response = folders.map { |folder_obj| solution_folder_pattern_index_channel_api(folder_obj) }
        match_json(expected_response)
      end
    end

    def test_folder_filter_with_invalid_platform
      enable_omni_bundle do
        setup_channel_api do
          set_jwe_auth_header(SUPPORT_BOT)
          get :folder_filter, controller_params(version: 'channel', platforms: Faker::Lorem.word)

          assert_response 400
          match_json(validation_error_pattern(bad_request_error_pattern('platforms', :not_included, list: SolutionConstants::PLATFORM_TYPES.join(','), code: :invalid_value)))
        end
      end
    end

    def test_folder_filter_with_null_platform
      enable_omni_bundle do
        setup_channel_api do
          set_jwe_auth_header(SUPPORT_BOT)
          get :folder_filter, controller_params(version: 'channel', platforms: '')

          assert_response 400
          match_json(validation_error_pattern(bad_request_error_pattern('platforms', :comma_separated_values, prepend_msg: :input_received, given_data_type: DataTypeValidator::DATA_TYPE_MAPPING[NilClass], code: :invalid_value)))
        end
      end
    end

    def test_folder_filter_with_null_tags
      enable_omni_bundle do
        setup_channel_api do
          set_jwe_auth_header(SUPPORT_BOT)
          get :folder_filter, controller_params(version: 'channel', tags: '')

          assert_response 400
          match_json(validation_error_pattern(bad_request_error_pattern('tags', :comma_separated_values, prepend_msg: :input_received, given_data_type: DataTypeValidator::DATA_TYPE_MAPPING[NilClass], code: :invalid_value)))
        end
      end
    end

    def test_folder_filter_with_portal_id_and_platform_and_tags_without_omni_feature
      setup_channel_api do
        set_jwe_auth_header(SUPPORT_BOT)
        get :folder_filter, controller_params(version: 'channel', portal_id: 1, platforms: 'web', tags: Faker::Lorem.word)
        assert_response 403

        errors = [
          bad_request_error_pattern('platforms', :require_feature, feature: :omni_bundle_2020, code: :access_denied),
          bad_request_error_pattern('tags', :require_feature, feature: :omni_bundle_2020, code: :access_denied)
        ]

        match_json(validation_error_pattern(errors))
      end
    end

    def test_folder_filter_with_platform_and_tags_with_omni_feature
      enable_omni_bundle do
        setup_channel_api do
          set_jwe_auth_header(SUPPORT_BOT)
          platform = 'web'
          tag_name = Faker::Lorem.word

          get_folder_with_platform_mapping_and_tags({}, [tag_name])
          folders = filter_folders_by_platforms([platform])
          folders = filter_folders_by_tags([tag_name])

          get :folder_filter, controller_params(version: 'channel', platforms: platform, tags: tag_name)
          assert_response 200
          expected_response = folders.map { |folder_obj| solution_folder_pattern_index_channel_api(folder_obj) }
          match_json(expected_response)
        end
      end
    end

    def test_folder_filter_with_language_allow_language_fallback_params
      setup_channel_api do
        set_jwe_auth_header(SUPPORT_BOT)
        portal_id = @account.portals.first.id
        language = 'ru-RU'
        language_object = Language.find_by_code(language)

        create_folder_translation(language_object.to_key)
        get :folder_filter, controller_params(version: 'channel', language: language, allow_language_fallback: 'true')
        assert_response 200
      end
    end

    def test_folder_filter_with_invalid_language_allow_language_fallback_params
      setup_channel_api do
        set_jwe_auth_header(SUPPORT_BOT)
        portal_id = @account.portals.first.id
        language = 'ru-RU'
        language_object = Language.find_by_code(language)
        create_folder_translation(language_object.to_key)
        get :folder_filter, controller_params(version: 'channel', language: language, allow_language_fallback: 'incorrect')
        assert_response 400
        expected ={:description=>"Validation failed",
          :errors=>
           [{:field=>"allow_language_fallback",
             :message=>"Value set is of type String.It should be a/an Boolean",
             :code=>"datatype_mismatch"}]}
        assert_equal(expected, JSON.parse(response.body, symbolize_names: true))
      end
    end
  
    def test_allow_language_for_category_folders
      setup_channel_api do
        set_jwe_auth_header(SUPPORT_BOT)
        sample_category_meta = get_category_with_folders
        get :category_folders, controller_params(id: sample_category_meta.id, allow_language_fallback: 'true')
        assert_response 200
      end
    end

    def test_invalid_allow_language_fallback_for_category_folders
      setup_channel_api do
        set_jwe_auth_header(SUPPORT_BOT)
        sample_category_meta = get_category_with_folders
        get :category_folders, controller_params(id: sample_category_meta.id, allow_language_fallback: 'invalid')
        assert_response 400
        results = parse_response(@response.body)
        assert_equal results, { 'description' => 'Validation failed', 'errors' => [{ 'field' => 'allow_language_fallback', 'message' => 'Value set is of type String.It should be a/an Boolean', 'code' => 'datatype_mismatch' }] }
      end
    end

    def test_page_params_for_category_folders
      setup_channel_api do
        set_jwe_auth_header(SUPPORT_BOT)
        sample_category_meta = get_category_with_folders
        get :category_folders, controller_params(id: sample_category_meta.id, page: 1)
        assert_response 200
      end
    end

    def test_per_page_params_for_category_folders
      setup_channel_api do
        set_jwe_auth_header(SUPPORT_BOT)
        sample_category_meta = get_category_with_folders
        get :category_folders, controller_params(id: sample_category_meta.id, per_page: 1)
        assert_response 200
      end
    end
  end
end
