require_relative '../../../test_helper'
['solutions_helper.rb', 'solution_builder_helper.rb'].each { |file| require Rails.root.join('spec', 'support', file) }

module Ember
  module Solutions
    class DraftsControllerTest < ActionController::TestCase
      include SolutionsTestHelper
      include SolutionsHelper
      include SolutionBuilderHelper
      include SolutionDraftsTestHelper
      include AttachmentsTestHelper

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
        additional.supported_languages = ['es','ru-RU']
        additional.save
        @account.reload
        setup_articles
        @@before_all_run = true
      end

      def setup_articles
        4.times do
          languages = @account.supported_languages_objects.map(&:to_key) + ['primary']
          article_meta = create_article(article_params.merge(lang_codes: languages))
          languages.each do |language|
            draft = article_meta.safe_send("#{language}_article").build_draft_from_article
            draft.save
          end
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

        # binarize sync won't work if multilingual is not enabled. Cleaning up data for now. We have an FR issue for the same
        get_my_drafts(Language.find_by_code(language).id).each do |draft|
          draft.discarding = true
          draft.destroy
        end

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

      def test_autosave_without_privilege
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

      def test_destroy
        article_with_draft
        assert @article.draft.present?
        delete :destroy, controller_params(version: 'private', article_id: @article.parent_id)
        assert_response 204
        assert_nil @article.reload.draft
      end

      def test_destroy_with_primary_language
        article_with_draft
        assert @article.draft.present?
        delete :destroy, controller_params(version: 'private', article_id: @article.parent_id, language: @account.language)
        assert_response 204
        assert_nil @article.reload.draft
      end

      def test_destory_with_secondary_language
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
        User.any_instance.stubs(:privilege?).with(:delete_solution).returns(false)
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
        User.any_instance.stubs(:privilege?).with(:publish_solution).returns(false)
        put :update, construct_params({ version: 'private', article_id: @article.parent_id }, update_params)
        assert_response 403
        match_json(request_error_pattern(:access_denied))
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
        params[:user_id] = 9999
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
        assert_equal @article.draft.meta[:deleted_attachments][:attachments].size, 1
      end

      def test_delete_attachment_of_primary_article_draft
        article_with_draft
        attachment_id = create_attachment(attachable_type: 'Solution::Article', attachable_id: @article.id).id
        delete :delete_attachment, controller_params(version: 'private', article_id: @article.parent_id, attachment_type: 'attachment', attachment_id: attachment_id, language: @account.language)
        assert_response 200
        match_json(autosave_pattern(@draft.reload))
        assert_equal @article.draft.meta[:deleted_attachments][:attachments].size, 1
      end

      def test_delete_attachment_of_secondary_article_draft
        language = @account.supported_languages.first
        article_with_draft(language)
        attachment_id = create_attachment(attachable_type: 'Solution::Article', attachable_id: @article.id).id
        delete :delete_attachment, controller_params(version: 'private', article_id: @article.parent_id, attachment_type: 'attachment', attachment_id: attachment_id, language: language)
        assert_response 200
        match_json(autosave_pattern(@draft.reload))
        assert_equal @article.draft.meta[:deleted_attachments][:attachments].size, 1
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
        assert_equal @article.draft.meta[:deleted_attachments][:cloud_files].size, 1
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

      private

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

        def autosave_params
          @title = Faker::Name.name
          @description = Faker::Lorem.paragraph
          { title: @title, description: @description, timestamp: @draft.updation_timestamp }
        end

        def update_params
          @title = Faker::Name.name
          @description = Faker::Lorem.paragraph
          @agent = add_test_agent(@account)
          { title: @title, description: @description, modified_at: @draft.modified_at.to_i, user_id: @agent.id, last_updated_at: @draft.updation_timestamp }
        end
    end
  end
end
