require_relative '../../../test_helper'
['solutions_helper.rb', 'solution_builder_helper.rb'].each { |file| require Rails.root.join('spec', 'support', file) }

require Rails.root.join('test', 'core', 'helpers', 'users_test_helper.rb')

module Ember
  module Solutions
    module DraftsTestParameters
      include SolutionsTestHelper

      def article_params(options = {})
        lang_hash = { lang_codes: options[:lang_codes] }
        category = create_category({ portal_id: Account.current.main_portal.id }.merge(lang_hash))
        {
          title: options[:title] || 'Test',
          description: 'Test',
          folder_id: create_folder({ visibility: Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:anyone], category_id: category.id }.merge(lang_hash)).id,
          status: options[:status] || Solution::Article::STATUS_KEYS_BY_TOKEN[:published]
        }.merge(lang_hash)
      end

      def get_my_drafts(language = 6)
        @account.solution_drafts.my_drafts(@account.main_portal.id, language)
      end

      def autosave_params(with_timstamp = true)
        @title = Faker::Name.name
        @description = Faker::Lorem.paragraph
        result = { title: @title, description: @description }
        result.merge!({timestamp: @draft.updation_timestamp}) if with_timstamp
        result
      end

      def update_params
        @title = Faker::Name.name
        @description = Faker::Lorem.paragraph
        @agent = add_test_agent(@account)
        { title: @title, description: @description, modified_at: @draft.modified_at.to_i, user_id: @agent.id, last_updated_at: @draft.updation_timestamp }
      end

      def create_drafts_for_article_meta article_meta
        all_account_language_keys.each do |language|
          draft = article_meta.safe_send("#{language}_article").build_draft_from_article
          draft.save
        end
      end
    end

    class DraftsControllerTest < ActionController::TestCase
      include SolutionsTestHelper
      include SolutionsHelper
      include SolutionBuilderHelper
      include SolutionDraftsTestHelper
      include AttachmentsTestHelper
      include SolutionsArticleVersionsTestHelper
      include DraftsTestParameters
      include CoreUsersTestHelper
      include PrivilegesHelper
      include SolutionsApprovalsTestHelper

      def setup
        super
        before_all
        @account.features.enable_multilingual.create
      end

      @@before_all_run = false

      def before_all
        return if @@before_all_run

        subscription = @account.subscription
        subscription.state = 'active'
        subscription.save

        additional = @account.account_additional_settings
        additional.supported_languages = ['es', 'ru-RU']
        additional.save
        @account.reload
        setup_articles
        @@before_all_run = true
      end

      def setup_articles
        4.times do
          languages = all_account_language_keys
          article_meta = create_article(article_params.merge(lang_codes: languages))
          create_drafts_for_article_meta article_meta
        end
      end

      def wrap_cname(params)
        { draft: params }
      end

      def test_index
        get :index, controller_params(version: 'private', portal_id: @account.main_portal.id)
        assert_response 200
        drafts = get_my_drafts
        assert_equal response.api_meta[:count], drafts.size
        pattern = drafts.first(3).map { |draft| private_api_solution_article_pattern(draft.article, exclude_description: true, exclude_attachments: true, exclude_tags: true) }
        match_json(pattern)
      end

      def test_index_without_privilege
        User.any_instance.stubs(:privilege?).with(:view_solutions).returns(false)
        get :index, controller_params(version: 'private')
        assert_response 403
        match_json(request_error_pattern(:access_denied))
        User.any_instance.unstub(:privilege?)
      end

      def test_index_without_portal_id
        get :index, controller_params(version: 'private')
        assert_response 400
        match_json([bad_request_error_pattern(:portal_id, :datatype_mismatch, code: :missing_field, expected_data_type: String)])
      end

      def test_index_with_additional_field
        get :index, controller_params(version: 'private', portal_id: @account.main_portal.id, test: 'Test')
        assert_response 400
        match_json([bad_request_error_pattern('test', :invalid_field)])
      end

      def test_index_with_invalid_portal_id
        get :index, controller_params(version: 'private', portal_id: 'Test')
        assert_response 400
        match_json([bad_request_error_pattern(:portal_id, :invalid_portal_id)])
      end

      def test_index_with_language
        languages = @account.supported_languages + ['primary']
        language = @account.supported_languages.first

        article = create_article(article_params(lang_codes: languages, status: 1))
        get :index, controller_params(version: 'private', portal_id: @account.main_portal.id, language: language)
        assert_response 200
        drafts = get_my_drafts(Language.find_by_code(language).id)
        assert_equal response.api_meta[:count], drafts.size
        pattern = drafts.first(3).map { |draft| private_api_solution_article_pattern(draft.article, { exclude_description: true, exclude_attachments: true, exclude_tags: true }, true, nil) }
        match_json(pattern.ordered!)
      end

      def test_index_invalid_language
        get :index, controller_params(version: 'private', portal_id: @account.main_portal.id, language: 'test')
        assert_response 404
        match_json(request_error_pattern(:language_not_allowed, code: 'test', list: (@account.supported_languages + [@account.language]).sort.join(', ')))
      end

      def test_autosave
        article_with_draft
        put :autosave, construct_params({ version: 'private', article_id: @article.parent_id }, autosave_params)
        assert_response 200
        match_json(autosave_pattern(@draft.reload))
        assert_equal @draft.title, @title
        assert_equal @draft.description, @description
      end

      def test_autosave_with_base64_png_content
        article_with_draft
        params = { title: 'dummy', description: base64_png_image }
        put :autosave, construct_params({ version: 'private', article_id: @article.parent_id }, params)

        assert_response 400
        match_json([bad_request_error_pattern('description', :article_description_base64_error, code: :article_base64_content_error)])
      end

      def test_autosave_with_base64_jpeg_content
        article_with_draft
        params = { title: 'dummy', description: base64_jpeg_image }
        put :autosave, construct_params({ version: 'private', article_id: @article.parent_id }, params)

        assert_response 400
        match_json([bad_request_error_pattern('description', :article_description_base64_error, code: :article_base64_content_error)])
      end

      def test_autosave_with_base64_gif_content
        article_with_draft
        params = { title: 'dummy', description: base64_gif_image }
        put :autosave, construct_params({ version: 'private', article_id: @article.parent_id }, params)

        assert_response 400
        match_json([bad_request_error_pattern('description', :article_description_base64_error, code: :article_base64_content_error)])
      end

      def test_autosave_with_base64_svg_content
        article_with_draft
        params = { title: 'dummy', description: base64_svg_image }
        put :autosave, construct_params({ version: 'private', article_id: @article.parent_id }, params)

        assert_response 400
        match_json([bad_request_error_pattern('description', :article_description_base64_error, code: :article_base64_content_error)])
      end

      def test_autosave_with_base64_plain_text_content
        article_with_draft
        params = { title: 'dummy', description: base64_plain_text }
        put :autosave, construct_params({ version: 'private', article_id: @article.parent_id }, params)

        assert_response 400
        match_json([bad_request_error_pattern('description', :article_description_base64_error, code: :article_base64_content_error)])
      end

      def test_autosave_with_base64_html_content
        article_with_draft
        params = { title: 'dummy', description: base64_html_text }
        put :autosave, construct_params({ version: 'private', article_id: @article.parent_id }, params)

        assert_response 400
        match_json([bad_request_error_pattern('description', :article_description_base64_error, code: :article_base64_content_error)])
      end

      def test_autosave_with_base64_html_content_with_kb_allow_base64_images_enabled
        Account.any_instance.stubs(:kb_allow_base64_images_enabled?).returns(true)
        article_with_draft
        params = autosave_params
        params[:description] = "<img src='data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAUAAAAFCAYAAACNbyblAAAAHElEQVQI12P48w38GIAXDIBKE0DHxgljNBAAO9TXL0Y4OHwAAAABJRU5ErkJggg==' alt='Red dot'/>"
        put :autosave, construct_params({ version: 'private', article_id: @article.parent_id }, params)
        assert_response 200
        match_json(autosave_pattern(@draft.reload))
        assert_equal @draft.title, @title
        assert_equal @draft.description, "<img src=\"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAUAAAAFCAYAAACNbyblAAAAHElEQVQI12P48w38GIAXDIBKE0DHxgljNBAAO9TXL0Y4OHwAAAABJRU5ErkJggg==\" alt=\"Red dot\">"
      ensure
        Account.any_instance.unstub(:kb_allow_base64_images_enabled?)
      end

      def test_autosave_with_article_approval
        Account.any_instance.stubs(:article_approval_workflow_enabled?).returns(true)
        add_privilege(User.current, :approve_article)
        User.current.reload
        @article = get_in_review_article
        @draft = @article.draft
        put :autosave, construct_params({ version: 'private', article_id: @article.parent_id }, autosave_params)
        assert_response 200
        match_json(autosave_pattern(@draft.reload))
        assert_equal @draft.title, @title
        assert_equal @draft.description, @description
        assert_in_review @article
      ensure
        Account.any_instance.unstub(:article_approval_workflow_enabled?)
      end

      def test_update_description_with_base64_plain_text_with_kb_allow_base64_images_enabled
        Account.any_instance.stubs(:kb_allow_base64_images_enabled?).returns(true)
        article_with_draft
        params_hash = update_params
        params_hash[:description] = "<img src='data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAUAAAAFCAYAAACNbyblAAAAHElEQVQI12P48w38GIAXDIBKE0DHxgljNBAAO9TXL0Y4OHwAAAABJRU5ErkJggg==' alt='Red dot'/>"
        put :update, construct_params({ version: 'private', article_id: @article.parent_id }, params_hash)
        assert_response 200
        match_json(private_api_solution_article_pattern(@article.reload))
      ensure
        Account.any_instance.unstub(:kb_allow_base64_images_enabled?)
      end

      def test_autosave_with_article_approval_different_user
        Account.any_instance.stubs(:article_approval_workflow_enabled?).returns(true)
        user = User.current
        add_test_agent.make_current
        add_privilege(User.current, :approve_article)
        User.current.reload
        @article = get_in_review_article
        user.make_current
        add_test_agent.make_current
        @draft = @article.draft
        put :autosave, construct_params({ version: 'private', article_id: @article.parent_id }, autosave_params)
        assert_response 200
        match_json(autosave_pattern(@draft.reload))
        assert_equal @draft.title, @title
        assert_equal @draft.description, @description
        assert_no_approval @article
      ensure
        user.make_current
        Account.any_instance.unstub(:article_approval_workflow_enabled?)
      end

      def test_autosave_with_article_approval_in_approved_state
        Account.any_instance.stubs(:article_approval_workflow_enabled?).returns(true)
        add_privilege(User.current, :approve_article)
        User.current.reload
        @article = get_approved_article
        @draft = @article.draft
        put :autosave, construct_params({ version: 'private', article_id: @article.parent_id }, autosave_params)
        assert_response 200, response.body
        match_json(autosave_pattern(@draft.reload))
        assert_equal @draft.title, @title
        assert_equal @draft.description, @description
        assert_no_approval @article
      ensure
        Account.any_instance.unstub(:article_approval_workflow_enabled?)
      end

      def test_autosave_without_privilege
        User.any_instance.stubs(:privilege?).with(:create_and_edit_article).returns(false)
        User.any_instance.stubs(:privilege?).with(:publish_solution).returns(false)
        article_with_draft
        put :autosave, construct_params({ version: 'private', article_id: @article.parent_id }, autosave_params)
        assert_response 403
        match_json(request_error_pattern(:access_denied))
        User.any_instance.unstub(:privilege?)
      end

      def test_autosave_without_mandatory_field
        article_with_draft
        put :autosave, construct_params({ version: 'private', article_id: @article.parent_id }, title: Faker::Name.name, timestamp: @draft.updation_timestamp)
        assert_response 400
        match_json([bad_request_error_pattern(:description, :datatype_mismatch, code: :missing_field, expected_data_type: String)])
      end

      def test_autosave_with_additional_field
        article_with_draft
        put :autosave, construct_params({ version: 'private', article_id: @article.parent_id }, test: 'test')
        assert_response 400
        match_json([bad_request_error_pattern('test', :invalid_field)])
      end

      def test_autosave_for_article_without_draft
        article_without_draft
        title = Faker::Name.name
        description = Faker::Lorem.paragraph
        put :autosave, construct_params({ version: 'private', article_id: @article.parent_id }, title: title, description: description)
        assert_response 200
        draft = @article.draft
        assert_equal draft.title, title
        assert_equal draft.description, description
      end

      def test_autosave_with_invalid_article
        article_with_draft
        put :autosave, construct_params({ version: 'private', article_id: 9999 }, autosave_params)
        assert_response 404
      end

      def test_autosave_with_locked_draft
        article_with_draft
        Solution::Draft.any_instance.stubs(:locked?).returns(true)
        put :autosave, construct_params({ version: 'private', article_id: @article.parent_id }, autosave_params)
        assert_response 400
        match_json(request_error_pattern_with_info(:draft_locked, {}, user_id: @draft.user_id))
        Solution::Draft.any_instance.unstub(:locked?)
      end

      def test_autosave_with_invalid_timestamp
        article_with_draft
        params = autosave_params
        params[:timestamp] += 5
        put :autosave, construct_params({ version: 'private', article_id: @article.parent_id }, params)
        assert_response 400
        match_json(request_error_pattern_with_info(:content_changed, {}, user_id: @draft.user_id))
      end

      def test_autosave_with_primary_language
        article_with_draft
        put :autosave, construct_params({ version: 'private', article_id: @article.parent_id, language: @account.language }, autosave_params)
        assert_response 200
        match_json(autosave_pattern(@draft.reload))
        assert_equal @draft.title, @title
        assert_equal @draft.description, @description
      end

      def test_autosave_with_secondary_language
        language = @account.supported_languages.first
        article_with_draft(language)
        put :autosave, construct_params({ version: 'private', article_id: @article.parent_id, language: language }, autosave_params)
        assert_response 200
        match_json(autosave_pattern(@draft.reload))
        assert_equal @draft.title, @title
        assert_equal @draft.description, @description
      end

      def test_autosave_with_invalid_language
        language = @account.supported_languages.first
        article_with_draft(language)
        put :autosave, construct_params({ version: 'private', article_id: @article.parent_id, language: 'test' }, autosave_params)
        assert_response 404
        match_json(request_error_pattern(:language_not_allowed, code: 'test', list: (@account.supported_languages + [@account.language]).sort.join(', ')))
      end

      def test_autosave_without_multilingual
        @account.features.enable_multilingual.destroy
        language = @account.supported_languages.first
        article_with_draft(language)
        put :autosave, construct_params({ version: 'private', article_id: @article.parent_id, language: language }, autosave_params)
        match_json(request_error_pattern(:require_feature, feature: 'MultilingualFeature'))
        assert_response 404
      end

      def test_autosave_with_emoji_content_feature_enabled
        Account.current.launch(:encode_emoji_in_solutions)
        article_with_draft
        title = 'hey 👋 there ⛺️😅💁🏿‍♀️👨‍👨‍👧‍👧this is line after emoji'
        description = 'hey 👋 there ⛺️😅💁🏿‍♀️👨‍👨‍👧‍👧this is line after emoji'
        put :autosave, construct_params({ version: 'private', article_id: @article.parent_id }, { title: title, description: description, timestamp: @draft.updation_timestamp })
        title = UnicodeSanitizer.remove_4byte_chars(title)
        description = UnicodeSanitizer.utf84b_html_c(description)
        assert_response 200
        match_json(autosave_pattern(@draft.reload))
        assert_equal @draft.title, title
        assert_equal @draft.description, description
        Account.current.rollback(:encode_emoji_in_solutions)
      end

      def test_autosave_with_emoji_content_feature_disabled
        Account.current.rollback(:encode_emoji_in_solutions)
        article_with_draft
        title = 'hey 👋 there ⛺️😅💁🏿‍♀️👨‍👨‍👧‍👧this is line after emoji'
        description = 'hey 👋 there ⛺️😅💁🏿‍♀️👨‍👨‍👧‍👧this is line after emoji'
        put :autosave, construct_params({ version: 'private', article_id: @article.parent_id }, { title: title, description: description, timestamp: @draft.updation_timestamp })
        title = UnicodeSanitizer.remove_4byte_chars(title)
        description = UnicodeSanitizer.remove_4byte_chars(description)
        assert_response 200
        match_json(autosave_pattern(@draft.reload))
        assert_equal @draft.title, title
        assert_equal @draft.description, description
      end

      def test_destroy
        article_with_draft
        assert @article.draft.present?
        delete :destroy, controller_params(version: 'private', article_id: @article.parent_id)
        assert_response 204
        assert_nil @article.reload.draft
      end

      def test_destroy_with_draft_article
        article_with_draft
        @article.set_status(false)
        @article.save!
        assert @article.draft.present?
        delete :destroy, controller_params(version: 'private', article_id: @article.parent_id)
        assert_response 400
        assert @article.reload.draft.present?
        match_json([bad_request_error_pattern('status', :cannot_destroy_draft_for_draft_article)])
      end

      def test_destroy_with_primary_language
        article_with_draft
        assert @article.draft.present?
        delete :destroy, controller_params(version: 'private', article_id: @article.parent_id, language: @account.language)
        assert_response 204
        assert_nil @article.reload.draft
      end

      def test_destroy_with_secondary_language
        language = @account.supported_languages.first
        article_with_draft(language)
        assert @article.draft.present?
        delete :destroy, controller_params(version: 'private', article_id: @article.parent_id, language: language)
        assert_response 204
        assert_nil @article.reload.draft
      end

      def test_destroy_with_invalid_language
        language = @account.supported_languages.first
        article_with_draft(language)
        assert @article.draft.present?
        delete :destroy, controller_params(version: 'private', article_id: @article.parent_id, language: 'test')
        assert_response 404
        match_json(request_error_pattern(:language_not_allowed, code: 'test', list: (@account.supported_languages + [@account.language]).sort.join(', ')))
      end

      def test_destroy_without_multilingual
        @account.features.enable_multilingual.destroy
        language = @account.supported_languages.first
        article_with_draft(language)
        delete :destroy, controller_params(version: 'private', article_id: @article.parent_id, language: language)
        match_json(request_error_pattern(:require_feature, feature: 'MultilingualFeature'))
        assert_response 404
      end

      def test_destroy_without_privilege
        article_with_draft
        User.any_instance.stubs(:privilege?).with(:create_and_edit_article).returns(false)
        delete :destroy, controller_params(version: 'private', article_id: @article.parent_id)
        assert_response 403
        match_json(request_error_pattern(:access_denied))
        User.any_instance.unstub(:privilege?)
      end

      def test_destroy_with_locked_draft
        article_with_draft
        Solution::Draft.any_instance.stubs(:locked?).returns(true)
        delete :destroy, controller_params(version: 'private', article_id: @article.parent_id)
        assert_response 400
        match_json(request_error_pattern_with_info(:draft_locked, {}, user_id: @draft.user_id))
        Solution::Draft.any_instance.unstub(:locked?)
      end

      def test_destroy_with_invalid_article
        delete :destroy, controller_params(version: 'private', article_id: 9999)
        assert_response 404
      end

      def test_destroy_without_draft
        article_without_draft
        delete :destroy, controller_params(version: 'private', article_id: @article.parent_id)
        assert_response 404
      end

      def test_update
        article_with_draft
        put :update, construct_params({ version: 'private', article_id: @article.parent_id }, update_params)
        assert_response 200
        match_json(private_api_solution_article_pattern(@article.reload))
      end

      def test_update_description_with_base64_png
        article_with_draft
        params_hash = update_params
        params_hash[:description] = base64_png_image

        put :update, construct_params({ version: 'private', article_id: @article.parent_id }, params_hash)
        assert_response 400
        match_json([bad_request_error_pattern('description', :article_description_base64_error, code: :article_base64_content_error)])
      end

      def test_update_description_with_base64_jpeg
        article_with_draft
        params_hash = update_params
        params_hash[:description] = base64_jpeg_image

        put :update, construct_params({ version: 'private', article_id: @article.parent_id }, params_hash)
        assert_response 400
        match_json([bad_request_error_pattern('description', :article_description_base64_error, code: :article_base64_content_error)])
      end

      def test_update_description_with_base64_svg
        article_with_draft
        params_hash = update_params
        params_hash[:description] = base64_svg_image

        put :update, construct_params({ version: 'private', article_id: @article.parent_id }, params_hash)
        assert_response 400
        match_json([bad_request_error_pattern('description', :article_description_base64_error, code: :article_base64_content_error)])
      end

      def test_update_description_with_base64_gif
        article_with_draft
        params_hash = update_params
        params_hash[:description] = base64_gif_image

        put :update, construct_params({ version: 'private', article_id: @article.parent_id }, params_hash)
        assert_response 400
        match_json([bad_request_error_pattern('description', :article_description_base64_error, code: :article_base64_content_error)])
      end

      def test_update_description_with_base64_html
        article_with_draft
        params_hash = update_params
        params_hash[:description] = base64_html_text

        put :update, construct_params({ version: 'private', article_id: @article.parent_id }, params_hash)
        assert_response 400
        match_json([bad_request_error_pattern('description', :article_description_base64_error, code: :article_base64_content_error)])
      end

      def test_update_description_with_base64_plain_text
        article_with_draft
        params_hash = update_params
        params_hash[:description] = base64_plain_text

        put :update, construct_params({ version: 'private', article_id: @article.parent_id }, params_hash)
        assert_response 400
        match_json([bad_request_error_pattern('description', :article_description_base64_error, code: :article_base64_content_error)])
      end

      def test_update_with_primary_language
        article_with_draft
        put :update, construct_params({ version: 'private', article_id: @article.parent_id, language: @account.language }, update_params)
        assert_response 200
        match_json(private_api_solution_article_pattern(@article, {}, true, nil))
      end

      def test_update_with_secondary_language
        language = @account.supported_languages.first
        article_with_draft(language)
        put :update, construct_params({ version: 'private', article_id: @article.parent_id, language: language }, update_params)
        assert_response 200
        match_json(private_api_solution_article_pattern(@article, {}, true, nil))
      end

      def test_update_with_invalid_language
        language = @account.supported_languages.first
        article_with_draft(language)
        put :update, construct_params({ version: 'private', article_id: @article.parent_id, language: 'test' }, update_params)
        assert_response 404
        match_json(request_error_pattern(:language_not_allowed, code: 'test', list: (@account.supported_languages + [@account.language]).sort.join(', ')))
      end

      def test_update_without_multilingual
        @account.features.enable_multilingual.destroy
        language = @account.supported_languages.first
        article_with_draft(language)
        put :update, construct_params({ version: 'private', article_id: @article.parent_id, language: language }, update_params)
        match_json(request_error_pattern(:require_feature, feature: 'MultilingualFeature'))
        assert_response 404
      end

      def test_update_without_privilege
        article_with_draft
        User.any_instance.stubs(:privilege?).with(:create_and_edit_article).returns(false)
        put :update, construct_params({ version: 'private', article_id: @article.parent_id }, update_params)
        assert_response 403
        match_json(request_error_pattern(:access_denied))
      ensure
        User.any_instance.unstub(:privilege?)
      end

      def test_update_with_mandatory_attributes_missing
        article_with_draft
        put :update, construct_params({ version: 'private', article_id: @article.parent_id }, user_id: User.current.id)
        assert_response 400
        match_json([bad_request_error_pattern(:description, :datatype_mismatch, code: :missing_field, expected_data_type: String),
                    bad_request_error_pattern(:title, :datatype_mismatch, code: :missing_field, expected_data_type: String),
                    bad_request_error_pattern(:modified_at, :datatype_mismatch, code: :missing_field, expected_data_type: Integer),
                    bad_request_error_pattern(:last_updated_at, :datatype_mismatch, code: :missing_field, expected_data_type: Integer)])
      end

      def test_update_with_additional_field
        article_with_draft
        put :update, construct_params({ version: 'private', article_id: @article.parent_id }, test: 'test')
        assert_response 400
        match_json([bad_request_error_pattern('test', :invalid_field)])
      end

      def test_update_with_invalid_author
        article_with_draft
        params = update_params
        params[:user_id] = 999_999_999
        put :update, construct_params({ version: 'private', article_id: @article.parent_id }, params)
        assert_response 400
        match_json([bad_request_error_pattern('user_id', :invalid_draft_author)])
      end

      def test_update_with_invalid_article
        article_with_draft
        put :update, construct_params({ version: 'private', article_id: 9999 }, update_params)
        assert_response 404
      end

      def test_update_without_draft
        article_without_draft
        put :update, construct_params({ version: 'private', article_id: @article.parent_id }, title: Faker::Name.name)
        assert_response 404
      end

      def test_update_without_article_approval
        Account.any_instance.stubs(:article_approval_workflow_enabled?).returns(false)
        language = @account.supported_languages.first
        article_with_draft(language)
        put :update, construct_params({ version: 'private', article_id: @article.parent_id, language: language }, update_params.merge(approval_data: { user_id: 1 }))
        assert_response 400
        match_json([bad_request_error_pattern('approval_data', :approval_data_not_allowed, code: :invalid_value)])
      ensure
        Account.any_instance.unstub(:article_approval_workflow_enabled?)
      end

      def test_update_with_approval
        Account.any_instance.stubs(:article_approval_workflow_enabled?).returns(true)
        language = @account.supported_languages.first
        article_with_draft(language)
        approver = add_test_agent(@account)
        add_privilege(approver, :approve_article)
        user = add_test_agent(@account)
        Solution::ApprovalNotificationWorker.expects(:perform_async).times(0)
        put :update, construct_params({ version: 'private', article_id: @article.parent_id, language: language }, update_params.merge(approval_data: { user_id: user.id, approver_id: approver.id, approval_status: Helpdesk::ApprovalConstants::STATUS_KEYS_BY_TOKEN[:approved] }))
        assert_response 200
        approval_data = JSON.parse(response.body)['approval_data']
        assert_equal approval_data['approver_id'], approver.id
        assert_equal approval_data['user_id'], user.id
        assert_equal approval_data['approval_status'], Helpdesk::ApprovalConstants::STATUS_KEYS_BY_TOKEN[:approved]
      ensure
        Account.any_instance.unstub(:article_approval_workflow_enabled?)
      end

      def test_update_with_approval_without_all_properties
        Account.any_instance.stubs(:article_approval_workflow_enabled?).returns(true)
        language = @account.supported_languages.first
        article_with_draft(language)
        approver = add_test_agent(@account)
        add_privilege(approver, :approve_article)
        user = add_test_agent(@account)
        put :update, construct_params({ version: 'private', article_id: @article.parent_id, language: language }, update_params.merge(approval_data: { user_id: user.id, approver_id: approver.id }))
        assert_response 400
        match_json([bad_request_error_pattern('approval_data', :approval_data_invalid, code: :invalid_value)])
      ensure
        Account.any_instance.unstub(:article_approval_workflow_enabled?)
      end

      def test_update_with_approval_invalid_status
        Account.any_instance.stubs(:article_approval_workflow_enabled?).returns(true)
        language = @account.supported_languages.first
        article_with_draft(language)
        approver = add_test_agent(@account)
        add_privilege(approver, :approve_article)
        user = add_test_agent(@account)
        put :update, construct_params({ version: 'private', article_id: @article.parent_id, language: language }, update_params.merge(approval_data: { user_id: user.id, approver_id: approver.id, approval_status: -1 }))
        assert_response 400
        match_json(approval_data_validation_error_pattern(:approval_status, :invalid_value))
      ensure
        Account.any_instance.unstub(:article_approval_workflow_enabled?)
      end

      def test_update_with_approval_invalid_user
        Account.any_instance.stubs(:article_approval_workflow_enabled?).returns(true)
        language = @account.supported_languages.first
        article_with_draft(language)
        approver = add_test_agent(@account)
        add_privilege(approver, :approve_article)
        user = add_test_agent(@account)
        put :update, construct_params({ version: 'private', article_id: @article.parent_id, language: language }, update_params.merge(approval_data: { user_id: 999_999_999, approver_id: approver.id, approval_status: Helpdesk::ApprovalConstants::STATUS_KEYS_BY_TOKEN[:approved] }))
        assert_response 400
        match_json(approval_data_validation_error_pattern(:user_id, :invalid_user_id))
      ensure
        Account.any_instance.unstub(:article_approval_workflow_enabled?)
      end

      def test_update_with_approval_invalid_approver
        Account.any_instance.stubs(:article_approval_workflow_enabled?).returns(true)
        language = @account.supported_languages.first
        article_with_draft(language)
        approver = add_test_agent(@account)
        add_privilege(approver, :approve_article)
        user = add_test_agent(@account)
        put :update, construct_params({ version: 'private', article_id: @article.parent_id, language: language }, update_params.merge(approval_data: { user_id: user.id, approver_id: 999_999_999, approval_status: Helpdesk::ApprovalConstants::STATUS_KEYS_BY_TOKEN[:approved] }))
        assert_response 400
        match_json(approval_data_validation_error_pattern(:approver_id, :invalid_approver_id))
      ensure
        Account.any_instance.unstub(:article_approval_workflow_enabled?)
      end

      def test_update_with_invalid_last_modified_at
        article_with_draft
        params = update_params
        params[:last_updated_at] = params[:last_updated_at] + 5
        put :update, construct_params({ version: 'private', article_id: @article.parent_id }, params)
        assert_response 400
        match_json(request_error_pattern_with_info(:content_changed, {}, user_id: @draft.user_id))
      end

      def test_delete_attachment
        article_with_draft
        attachment_id = create_attachment(attachable_type: 'Solution::Article', attachable_id: @article.id).id
        delete :delete_attachment, controller_params(version: 'private', article_id: @article.parent_id, attachment_type: 'attachment', attachment_id: attachment_id)
        assert_response 200
        match_json(autosave_pattern(@draft.reload))
        assert_equal @draft.meta[:deleted_attachments][:attachments].size, 1
      end

      def test_delete_attachment_of_primary_article_draft
        article_with_draft
        attachment_id = create_attachment(attachable_type: 'Solution::Article', attachable_id: @article.id).id
        delete :delete_attachment, controller_params(version: 'private', article_id: @article.parent_id, attachment_type: 'attachment', attachment_id: attachment_id, language: @account.language)
        assert_response 200
        match_json(autosave_pattern(@draft.reload))
        assert_equal @draft.meta[:deleted_attachments][:attachments].size, 1
      end

      def test_delete_attachment_of_secondary_article_draft
        language = @account.supported_languages.first
        article_with_draft(language)
        attachment_id = create_attachment(attachable_type: 'Solution::Article', attachable_id: @article.id).id
        delete :delete_attachment, controller_params(version: 'private', article_id: @article.parent_id, attachment_type: 'attachment', attachment_id: attachment_id, language: language)
        assert_response 200
        match_json(autosave_pattern(@draft.reload))
        assert_equal @draft.meta[:deleted_attachments][:attachments].size, 1
      end

      def test_delete_attachment_without_multilingual
        @account.features.enable_multilingual.destroy
        language = @account.supported_languages.first
        article_with_draft(language)
        attachment_id = create_attachment(attachable_type: 'Solution::Article', attachable_id: @article.id).id
        delete :delete_attachment, controller_params(version: 'private', article_id: @article.parent_id, attachment_type: 'attachment', attachment_id: attachment_id, language: language)
        assert_response 404
        match_json(request_error_pattern(:require_feature, feature: 'MultilingualFeature'))
      end

      def test_delete_attachment_without_privilege
        User.any_instance.stubs(:privilege?).with(:create_and_edit_article).returns(false)
        User.any_instance.stubs(:privilege?).with(:publish_solution).returns(false)
        delete :delete_attachment, controller_params(version: 'private', article_id: 1, attachment_type: 'attachment', attachment_id: 1)
        assert_response 403
        match_json(request_error_pattern(:access_denied))
        User.any_instance.unstub(:privilege?)
      end

      def test_delete_attachment_with_cloud_files
        article_with_draft
        attachment_id = create_cloud_file_attachment(droppable_type: 'Solution::Article', droppable_id: @article.id).id
        delete :delete_attachment, controller_params(version: 'private', article_id: @article.parent_id, attachment_type: 'cloud_file', attachment_id: attachment_id)
        assert_response 200
        match_json(autosave_pattern(@draft.reload))
        assert_equal @draft.meta[:deleted_attachments][:cloud_files].size, 1
      end

      def test_delete_attachment_with_invalid_attachment
        article_with_draft
        delete :delete_attachment, controller_params(version: 'private', article_id: @article.parent_id, attachment_type: 'attachment', attachment_id: 999)
        assert_response 404
      end

      def test_delete_attachment_with_invalid_article_id
        article_with_draft
        attachment_id = create_attachment(attachable_type: 'Solution::Article', attachable_id: @article.id).id
        delete :delete_attachment, controller_params(version: 'private', article_id: 999, attachment_type: 'attachment', attachment_id: attachment_id)
        assert_response 404
      end
    end
    # class end

    class DraftsControllerVersionsTest < ActionController::TestCase
      include SolutionsArticleVersionsTestHelper
      include SolutionsArticlesTestHelper
      include SolutionsTestHelper
      include SolutionsHelper
      include SolutionBuilderHelper
      include DraftsTestParameters
      include SolutionDraftsTestHelper
      include AttachmentsTestHelper


      tests Ember::Solutions::DraftsController

      def setup
        super
        @account = Account.first
        Account.stubs(:current).returns(@account)
        setup_multilingual
        before_all
        @account.add_feature(:article_versioning)
        languages = all_account_language_keys
        article_meta = create_article(article_params(lang_codes: languages))
        create_drafts_for_article_meta article_meta
      end

      def teardown
        Account.unstub(:current)
      end

      @@before_all_run = false

      def before_all
        return if @@before_all_run
        setup_redis_for_articles
        setup_multilingual
        @account.reload
        @@before_all_run = true
      end

      def wrap_cname(params)
        { draft: params }
      end

      def test_autosave_without_article_versioning
        article_with_draft
        disable_article_versioning do
          should_not_create_version(@article) do
            put :autosave, construct_params({ version: 'private', article_id: @article.parent_id, language: @account.language }, autosave_params.merge(session: session))
            assert_response 200
            @article.reload
            draft = @article.draft
            match_json(autosave_pattern(draft))
            assert_equal draft.title, @title
            assert_equal draft.description, @description
          end
        end
      end

      def test_destroy_with_article_versions
        article = @account.solution_articles.where(language_id: @account.language_object.id).first
        article.draft.publish! if article.draft
        article.reload
        3.times do
          create_draft_version_for_article(article)
        end
        @draft = article.draft
        delete :destroy, controller_params(version: 'private', article_id: article.parent_id)
        assert_response 204
        article.solution_article_versions.latest.each do |article_verion|
          break if article_verion.status == Solution::Article::STATUS_KEYS_BY_TOKEN[:published]
          assert_equal article_verion.discarded?, true
        end
      end

      def test_first_autosave_creates_article_version
        article = @account.solution_articles.where(language_id: @account.language_object.id).first
        article.draft.publish! if article.draft
        3.times do
          create_version_for_article(article)
        end

        @draft = article.create_draft_from_article
        should_create_version(article) do
          put :autosave, construct_params({ version: 'private', article_id: article.parent_id, language: @account.language }, autosave_params.merge(session: 'first-session'))
          assert_response 200
          article.reload
          draft = article.draft
          match_json(autosave_pattern(draft))
          assert_equal draft.title, @title
          assert_equal draft.description, @description
          latest_version = get_latest_version(article)
          assert_version_draft(latest_version)
        end
      end

      def test_second_autosave_should_not_create_version
        article = @account.solution_articles.where(language_id: @account.language_object.id).first
        article.draft.publish! if article.draft
        3.times do
          create_version_for_article(article)
        end

        session = 'same-autosave-session'

        @draft = article.create_draft_from_article
        should_not_create_version(article) do
         stub_version_session(session) do
            put :autosave, construct_params({ version: 'private', article_id: article.parent_id, language: @account.language }, autosave_params.merge(session: session))
            assert_response 200
            article.reload
            draft = article.draft
            match_json(autosave_pattern(draft))
            assert_equal draft.title, @title
            assert_equal draft.description, @description
            latest_version = get_latest_version(article)
            assert_version_draft(latest_version)
          end
        end
      end

      def test_published_autosave
        sample_article = create_article(article_params(lang_codes: all_account_language_keys).merge(status: 2)).primary_article
        should_create_version(sample_article) do
          put :autosave, construct_params({ version: 'private', article_id: sample_article.parent_id, language: @account.language }, autosave_params(false).merge(session: 'first-session'))
          assert_response 200
          sample_article.reload
          draft = sample_article.draft
          match_json(autosave_pattern(draft))
          assert_equal draft.title, @title
          assert_equal draft.description, @description
          latest_version = get_latest_version(sample_article)
          assert_version_draft(latest_version)
        end
      end

      def test_draft_autosave
        sample_article = create_article(article_params(lang_codes: all_account_language_keys).merge(status: 1)).primary_article
        @draft = sample_article.draft
        should_create_version(sample_article) do
          put :autosave, construct_params({ version: 'private', article_id: sample_article.parent_id, language: @account.language }, autosave_params.merge(session: 'first-session'))
          assert_response 200
          sample_article.reload
          draft = sample_article.draft
          match_json(autosave_pattern(draft))
          assert_equal draft.title, @title
          assert_equal draft.description, @description
          latest_version = get_latest_version(sample_article)
          assert_version_draft(latest_version)
        end
      end

      def test_published_draft_autosave
        sample_article = create_article(article_params(lang_codes: all_account_language_keys).merge(status: 2)).primary_article
        create_draft_version_for_article(sample_article)
        @draft = sample_article.draft
        should_create_version(sample_article) do
          put :autosave, construct_params({ version: 'private', article_id: sample_article.parent_id, language: @account.language }, autosave_params.merge(session: 'first-session'))
          assert_response 200
          sample_article.reload
          draft = sample_article.draft
          match_json(autosave_pattern(draft))
          assert_equal draft.title, @title
          assert_equal draft.description, @description
          latest_version = get_latest_version(sample_article)
          assert_version_draft(latest_version)
        end
      end
          
      def test_autosave_cancel
        sample_article = create_article(article_params(lang_codes: all_account_language_keys).merge(status: 2)).primary_article
        create_draft_version_for_article(sample_article)
        @draft = sample_article.draft
        should_delete_version(sample_article) do
          stub_version_session('first-session') do
            put :update, construct_params({ version: 'private', article_id: sample_article.parent_id, session: 'first-session' }, update_params)
            assert_response 200
            match_json(private_api_solution_article_pattern(sample_article.reload))
          end
        end
      end
    end
    # class end
  end
end
