require_relative '../../../../test_helper'
module Channel::V2::ApiSolutions
  class FoldersControllerTest < ActionController::TestCase
    include JweTestHelper
    include SolutionsTestHelper
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
  end
end
