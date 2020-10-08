require_relative '../../../../test/api/test_helper'
['contact_segments_test_helper.rb', 'company_segments_test_helper.rb'].each { |file| require "#{Rails.root}/test/lib/helpers/#{file}" }
['solutions_helper.rb', 'solution_builder_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
class Support::HomeControllerTest < ActionController::TestCase
    include SolutionsTestHelper
    include SolutionFoldersTestHelper
    include SolutionsHelper
    include SolutionBuilderHelper
    include ContactSegmentsTestHelper
    include CompanySegmentsTestHelper
    include ApiCompanyHelper
    include CoreSolutionsTestHelper

    def setup
      super
      @account.features.enable_multilingual.create
      @account.add_feature(:segments)
      initial_setup
    end

    @@initial_setup_run = false

    def initial_setup
      return if @@initial_setup_run
      additional = @account.account_additional_settings
      additional.supported_languages = ["es","ru-RU"]
      additional.save
      @account.add_feature(:multi_language)
      @account.reload
      @@initial_setup_run = true
    end

  def test_folder_visibility_company_segments_visible_to_user_in_segment_only
    create_company_segment
    company = create_company({ created_at: Time.now })
    filter = Segments::Match::Company.new(company).all.first
    user = add_new_user(Account.current, active: true)
    Account.current.user_companies.create(company_id: company.id, user_id: user.id, default: 1, client_manager: 1)
    folder = create_folder({visibility: 7})
    folder.company_filters = [filter]
    user.make_current
    login_as(user)
    get :index
    assert_match "/support/solutions/folders/#{folder.id}", response.body
  end

  def test_folder_visibility_company_segments_not_visible_to_user_not_in_segment_only
    create_company_segment
    company = create_company({ created_at: Time.now })
    filter = Segments::Match::Company.new(company).all.first
    user = add_new_user(Account.current, active: true)
    folder = create_folder({visibility: 7})
    folder.company_filters = [filter]
    user.make_current
    login_as(user)
    get :index
    assert_not_match "/support/solutions/folders/#{folder.id}", response.body
  end

  def test_folder_visibility_contact_segments_visible_to_user_in_segment_only
    create_contact_segment
    user = add_new_user(Account.current, active: true)
    tag = Helpdesk::Tag.new(name: "apple")
    user.add_tag(tag)
    user.save!
    filter = Segments::Match::Contact.new(user).all.first
    folder = create_folder({visibility: 6})
    p folder.inspect
    p filter
    p Account.current.contact_filters_from_cache
    folder.contact_filters = [filter]
    user.make_current
    login_as(user)
    get :index
    assert_match "/support/solutions/folders/#{folder.id}", response.body
  end

  def test_folder_visibility_contact_segments_not_visible_to_user_not_in_segment_only
    create_contact_segment
    user = add_new_user(Account.current, active: true, created_at: Time.now - 2.months)
    folder = create_folder({visibility: 6})
    folder.contact_filters = [Account.current.contact_filters.first]
    user.make_current
    login_as(user)
    get :index
    assert_not_match "/support/solutions/folders/#{folder.id}", response.body
  end

    def test_image_property_included_in_og_meta_tags
      user = add_new_user(Account.current, active: true)
      user.make_current
      login_as(user)
      get :index
      assert_match "<meta property=\"og:image\"", response.body
    end

    def test_when_deny_iframe_not_set
      Account.any_instance.stubs(:multilingual?).returns(false)
      get :index
      assert_response 200
      assert_nil response.headers['X-Frame-Options']
    ensure
      Account.any_instance.unstub(:multilingual?)
    end

    def test_when_deny_iframe_is_set
      Account.any_instance.stubs(:multilingual?).returns(false)
      AccountAdditionalSettings.any_instance.stubs(:security).returns(deny_iframe_embedding: true)
      get :index
      assert_response 200
      assert_equal response.headers['X-Frame-Options'], 'SAMEORIGIN'
    ensure
      Account.any_instance.unstub(:multilingual?)
    end

    def test_redirect_support_home
      get :index, portal_type: 'facebook'
      assert_redirected_to '/support/home'
    end
end
