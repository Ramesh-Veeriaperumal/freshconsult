require_relative '../../../../test_helper'
['solutions_helper.rb', 'solution_builder_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
module Channel::V2::ApiSolutions
  class CategoriesControllerTest < ActionController::TestCase
    include SolutionsTestHelper
    include JweTestHelper
    include SolutionBuilderHelper
    include SolutionsHelper
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
      p = Portal.new
      p.name = "Sample Portal"
      p.account_id  = @account.id
      p.save
      @account.features.enable_multilingual.create
      @account.reload
      @@initial_setup_run = true
    end

    def wrap_cname(params)
      { category: params }
    end

    # refactor logic
    def get_category
      @account.solution_category_meta.where(is_default:false).select{ |x| x.children}.first
    end

    def get_meta_with_translation
      @account.solution_category_meta.where(is_default:false).select{|x| x.children if x.children.count > 1}.first
    end

    def get_meta_without_translation
      @account.solution_category_meta.where(is_default:false).select{|x| x.children if x.children.count == 1}.first
    end

    def test_show_category
    	set_jwe_auth_header(SUPPORT_BOT)
      sample_category = get_category
      get :show, controller_params(id: sample_category.parent_id)
      assert_response 200
    end

    def test_show_category_with_allow_language_fallback_param
      set_jwe_auth_header(SUPPORT_BOT)
      sample_category = get_category
      get :show, controller_params(id: sample_category.parent_id, allow_language_fallback: 'true')
      assert_response 200
    end

    def test_show_category_with_invalid_allow_language_fallback_param
      set_jwe_auth_header(SUPPORT_BOT)
      sample_category = get_category
      get :index, controller_params(id: sample_category.parent_id, allow_language_fallback: 'invalid')
      assert_response 400
      expected = { description: 'Validation failed', errors: [{ field: 'allow_language_fallback', message: "Value set is of type String.It should be a/an Boolean", code: 'datatype_mismatch' }] }
      assert_equal(expected, JSON.parse(response.body, symbolize_names: true))
    end

    def test_show_unavailable_category
    	set_jwe_auth_header(SUPPORT_BOT)
      get :show, controller_params(id: 99999)
      assert_response :missing
    end
  end
end
