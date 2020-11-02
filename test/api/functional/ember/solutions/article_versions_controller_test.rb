require_relative '../../../test_helper'
['solutions_helper.rb', 'solution_builder_helper.rb'].each { |file| require Rails.root.join('spec', 'support', file) }

module Ember
  module Solutions
    class ArticleVersionsControllerTest < ActionController::TestCase
      include SolutionsArticleVersionsTestHelper
      include SolutionsArticlesTestHelper
      include SolutionsTestHelper
      include SolutionsHelper
      include SolutionBuilderHelper
      include AttachmentsTestHelper

      def setup
        super
        @account = Account.first
        Account.stubs(:current).returns(@account)
        setup_multilingual
        before_all
        @account.add_feature(:article_versioning)
        create_article(article_params(lang_codes: all_account_languages))
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

      def test_index_without_privilege
        User.any_instance.stubs(:privilege?).with(:view_solutions).returns(false)
        get :index, controller_params(version: 'private', article_id: get_article_with_versions.parent.id)
        assert_response 403
        match_json(request_error_pattern(:access_denied))
      ensure
        User.any_instance.unstub(:privilege?)
      end

      def test_index_without_feature
        disable_article_versioning do
          get :index, controller_params(version: 'private', article_id: get_article_with_versions.parent.id)
          assert_response 403
          match_json(request_error_pattern(:require_feature, feature: 'Article Versioning'))
        end
      end

      def test_index_with_invalid_article_id
        get :index, controller_params(version: 'private', article_id: 99_999_999)
        assert_response 404
      end

      def test_index_with_invalid_article_id_with_valid_language
        get :index, controller_params(version: 'private', language: 'en', article_id: 99_999_999)
        assert_response 404
      end

      def test_index_with_invalid_language
        get :index, controller_params(version: 'private', article_id: get_article_with_versions.parent.id, language: 'dummy')
        assert_response 404
      end

      def test_index_with_non_supported_language
        non_supported_lang = get_valid_not_supported_language
        get :index, controller_params(version: 'private', article_id: get_article_with_versions.parent.id, language: non_supported_lang)
        assert_response 404
        match_json(request_error_pattern(:language_not_allowed, code: non_supported_lang, list: (@account.supported_languages + [@account.language]).sort.join(', ')))
      end

      def test_index_with_valid_language
        supported_lang = @account.all_language_objects.first
        article_meta = get_article_with_versions.parent
        get :index, controller_params(version: 'private', article_id: article_meta.id, language: supported_lang.code)
        assert_response 200
        match_json(article_verion_index_pattern(article_meta.safe_send("#{supported_lang.to_key}_article").solution_article_versions.latest.limit(30)))
      end

      def test_index_without_language
        article_meta = get_article_with_versions.parent
        get :index, controller_params(version: 'private', article_id: article_meta.id)
        assert_response 200
        match_json(article_verion_index_pattern(article_meta.safe_send("primary_article").solution_article_versions.latest.limit(30)))
      end

      def test_index_without_multilingual
        supported_lang = Language.find_by_code(@account.supported_languages.last)
        Account.any_instance.stubs(:multilingual?).returns(false)
        article_meta = get_article_with_versions.parent
        get :index, controller_params(version: 'private', article_id: article_meta.id, language: supported_lang.code)
        assert_response 404
        match_json(request_error_pattern(:require_feature, feature: 'MultilingualFeature'))
      ensure
        Account.any_instance.unstub(:multilingual?)
      end

      def test_show_without_privilege
        User.any_instance.stubs(:privilege?).with(:view_solutions).returns(false)
        article = get_article_with_versions
        get :show, controller_params(version: 'private', article_id: article.parent.id, id: article.solution_article_versions.last.id)
        assert_response 403
        match_json(request_error_pattern(:access_denied))
      ensure
        User.any_instance.unstub(:privilege?)
      end

      def test_show_without_feature
        disable_article_versioning do
          article = get_article_with_versions
          get :show, controller_params(version: 'private', article_id: article.parent.id, id: article.solution_article_versions.last.id)
          assert_response 403
          match_json(request_error_pattern(:require_feature, feature: 'Article Versioning'))
        end
      end

      def test_show_with_invalid_article_id
        article = get_article_with_versions
        get :show, controller_params(version: 'private', article_id: 99_999_999, id: article.solution_article_versions.last.id)
        assert_response 404
      end

      def test_show_with_invalid_version_id
        article = get_article_with_versions
        get :show, controller_params(version: 'private', article_id: article.parent.id, id: 999_999_999)
        assert_response 404
      end

      def test_show_with_invalid_language
        article = get_article_with_versions
        get :show, controller_params(version: 'private', article_id: article.parent.id, id: article.solution_article_versions.last.id, language: 'dummy')
        assert_response 404
      end

      def test_show_with_non_supported_language
        non_supported_lang = get_valid_not_supported_language
        article = get_article_with_versions
        get :show, controller_params(version: 'private', article_id: article.parent.id, id: article.solution_article_versions.last.id, language: non_supported_lang)
        assert_response 404
        match_json(request_error_pattern(:language_not_allowed, code: non_supported_lang, list: (@account.supported_languages + [@account.language]).sort.join(', ')))
      end

      def test_show_with_valid_language
        supported_lang = @account.all_language_objects.first
        article_meta = get_article_with_versions.parent
        AwsWrapper::S3.stubs(:read).returns('{"title": "title", "description":"description"}')
        article_version = article_meta.safe_send("#{supported_lang.to_key}_article").solution_article_versions.latest.first
        get :show, controller_params(version: 'private', article_id: article_meta.id, id: article_version.version_no, language: supported_lang.code)
        assert_response 200
        match_json(article_verion_pattern(article_version))
      ensure
        AwsWrapper::S3.unstub(:read)
      end

      def test_show_without_language
        article_meta = get_article_with_versions.parent
        AwsWrapper::S3.stubs(:read).returns('{"title": "title", "description":"description"}')
        article_version = article_meta.safe_send('primary_article').solution_article_versions.latest.first
        get :show, controller_params(version: 'private', article_id: article_meta.id, id: article_version.version_no)
        assert_response 200
        match_json(article_verion_pattern(article_version))
      ensure
        AwsWrapper::S3.unstub(:read)
      end

      def test_show_without_multilingual
        supported_lang = Language.find_by_code(@account.supported_languages.last)
        article_meta = get_article_with_versions.parent
        AwsWrapper::S3.stubs(:read).returns('{"title": "title", "description":"description"}')
        article_version = article_meta.solution_article_versions.latest.first
        Account.any_instance.stubs(:multilingual?).returns(false)
        get :show, controller_params(version: 'private', article_id: article_meta.id, id: article_version.version_no, language: supported_lang.code)
        assert_response 404
        match_json(request_error_pattern(:require_feature, feature: 'MultilingualFeature'))
      ensure
        Account.any_instance.unstub(:multilingual?)
      end

      def test_restore_with_valid_language
        session = Faker::Name.name
        supported_lang = @account.all_language_objects.first
        article_meta = get_article_with_versions.parent
        article = article_meta.safe_send("#{supported_lang.to_key}_article")
        article.draft.publish! if article.draft
        3.times do
          create_version_for_article(article)
        end
        stub_version_session(session) do
          stub_version_content do
            params_hash = { session: session }
            article_version = article_meta.safe_send("#{supported_lang.to_key}_article").solution_article_versions.first
            should_create_version(article) do
              post :restore, controller_params(version: 'private', article_id: article_meta.id, id: article_version.version_no, language: supported_lang.code)
              assert_response 204
              latest_version = get_latest_version(article)
              assert_version_draft(latest_version)
            end
          end
        end
      end

      def test_restore_without_privilege
        User.any_instance.stubs(:privilege?).with(:publish_solution).returns(false)
        article = get_article_with_versions
        should_not_create_version(article) do
          post :restore, controller_params(version: 'private', article_id: article.parent.id, id: article.solution_article_versions.last.id)
          assert_response 403
          match_json(request_error_pattern(:access_denied))
        end
      ensure
        User.any_instance.unstub(:privilege?)
      end

      def test_restore_without_feature
        disable_article_versioning do
          article = get_article_with_versions
          should_not_create_version(article) do
            post :restore, controller_params(version: 'private', article_id: article.parent.id, id: article.solution_article_versions.last.id)
            assert_response 403
            match_json(request_error_pattern(:require_feature, feature: 'Article Versioning'))
          end
        end
      end

      def test_restore_with_invalid_article_id
        article = get_article_with_versions
        should_not_create_version(article) do
          post :restore, controller_params(version: 'private', article_id: 99_999_999, id: article.solution_article_versions.last.id)
          assert_response 404
        end
      end

      def test_restore_with_invalid_version_id
        article = get_article_with_versions
        should_not_create_version(article) do
          post :restore, controller_params(version: 'private', article_id: article.parent.id, id: 999_999_999)
          assert_response 404
        end
      end

      def test_restore_with_invalid_language
        article = get_article_with_versions
        should_not_create_version(article) do
          post :restore, controller_params(version: 'private', article_id: article.parent.id, id: article.solution_article_versions.last.id, language: 'dummy')
          assert_response 404
        end
      end

      def test_restore_with_non_supported_language
        non_supported_lang = get_valid_not_supported_language
        article = get_article_with_versions
        should_not_create_version(article) do
          post :restore, controller_params(version: 'private', article_id: article.parent.id, id: article.solution_article_versions.last.id, language: non_supported_lang)
          assert_response 404
          match_json(request_error_pattern(:language_not_allowed, code: non_supported_lang, list: (@account.supported_languages + [@account.language]).sort.join(', ')))
        end
      end

      def test_restore_without_language
        session = Faker::Name.name
        supported_lang = @account.all_language_objects.first
        article_meta = get_article_with_versions.parent
        article = article_meta.safe_send('primary_article')
        article.draft.publish! if article.draft
        3.times do
          create_version_for_article(article)
        end
        stub_version_session(session) do
          stub_version_content do
            params_hash = { session: session }
            article_version = article_meta.safe_send('primary_article').solution_article_versions.first
            should_create_version(article) do
              post :restore, controller_params(version: 'private', article_id: article_meta.id, id: article_version.version_no)
              assert_response 204
              latest_version = get_latest_version(article)
              assert_version_draft(latest_version)
            end
          end
        end
      end

      def test_restore_without_multilingual
        session = Faker::Name.name
        stub_version_session(session) do
          params_hash = { session: session }
          supported_lang = Language.find_by_code(@account.supported_languages.last)
          article_meta = get_article_with_versions.parent
          article_version = article_meta.solution_article_versions.latest.first
          article = article_meta.safe_send('primary_article')
          should_not_create_version(article) do
            Account.any_instance.stubs(:multilingual?).returns(false)
            post :restore, controller_params(version: 'private', article_id: article_meta.id, id: article_version.version_no, language: supported_lang.code)
            assert_response 404
            match_json(request_error_pattern(:require_feature, feature: 'MultilingualFeature'))
          end
        end
      ensure
        Account.any_instance.unstub(:multilingual?)
      end

      def test_restore_with_latest_current_version
        session = Faker::Name.name
        stub_version_session(session) do
          params_hash = { session: session }
          supported_lang = @account.all_language_objects.first
          article_meta = get_article_with_versions.parent
          article_version = article_meta.safe_send("#{supported_lang.to_key}_article").solution_article_versions.latest.first
          article = article_meta.safe_send('primary_article')
          should_not_create_version(article) do
            post :restore, controller_params(version: 'private', article_id: article_meta.id, id: article_version.version_no, language: supported_lang.code)
            assert_response 412
          end
        end
      ensure
        Account.any_instance.unstub(:multilingual?)
      end

      def test_restore_with_draft_locked
        session = Faker::Name.name
        supported_lang = @account.all_language_objects.first
        article_meta = get_article_with_versions.parent
        article = article_meta.safe_send('primary_article')
        3.times do
          create_version_for_article(article)
        end
        stub_version_session(session) do
          params_hash = { session: session }
          article_version = article_meta.safe_send('primary_article').solution_article_versions.second
          create_draft(article: article) unless article.draft
          should_not_create_version(article) do
            Solution::Draft.any_instance.stubs(:locked?).returns(true)
            post :restore, controller_params(version: 'private', article_id: article_meta.id, id: article_version.version_no)
            assert_response 400
          end
        end
      end

      def test_restore_with_same_session
        session = Faker::Name.name
        supported_lang = @account.all_language_objects.first
        article_meta = get_article_with_versions.parent
        article = article_meta.safe_send('primary_article')
        article.draft.publish! if article.draft
        3.times do
          create_version_for_article(article)
        end
        stub_version_session(session) do
          stub_version_content do
            article_version = article_meta.safe_send('primary_article').solution_article_versions.second
            params_hash = { session: article_version.session }
            article = article_meta.safe_send('primary_article')
            should_create_version(article) do
              post :restore, controller_params(version: 'private', article_id: article_meta.id, id: article_version.version_no)
              assert_response 204
            end
          end
        end
      end

      def test_restore_with_normal_attachments
        article_meta = get_article_with_versions.parent
        article = article_meta.safe_send('primary_article')
        attachment = article.attachments.build(:content => fixture_file_upload('/files/attachment.txt', 'text/plain', :binary),
                                               :description => Faker::Name.first_name, 
                                               :account_id => article.account_id)
        attachment.save
        article.draft.publish! if article.draft
        3.times do
          create_version_for_article(article)
        end
        session = Faker::Name.name
        stub_version_session(session) do
          stub_version_content do
            article_version = article_meta.safe_send('primary_article').solution_article_versions.second
            params_hash = { session: article_version.session }
            should_create_version(article) do
              post :restore, controller_params(version: 'private', article_id: article_meta.id, id: article_version.version_no)
              assert_response 204
            end
          end
        end
      end

      def test_restore_with_cloud_files
        article_meta = get_article_with_versions.parent
        article = article_meta.safe_send('primary_article')
        cloud_file = article.cloud_files.build(:url => 'https://www.dropbox.com/s/7d3z51nidxe358m/GettingStarted.pdf?dl=0',
                                               :application_id => 20, :filename => 'Getting Started.pdf')
        cloud_file.save
        article.draft.publish! if article.draft
        3.times do
          create_version_for_article(article)
        end
        session = Faker::Name.name
        stub_version_session(session) do
          stub_version_content do
            article_version = article_meta.safe_send('primary_article').solution_article_versions.second
            params_hash = { session: article_version.session }
            should_create_version(article) do
              post :restore, controller_params(version: 'private', article_id: article_meta.id, id: article_version.version_no)
              assert_response 204
            end
          end
        end
      end

      def test_restore_with_attachments_in_deleted_meta
        article_meta = get_article_with_versions.parent
        article = article_meta.safe_send('primary_article')
        attachment = article.attachments.build(:content => fixture_file_upload('/files/attachment.txt', 'text/plain', :binary),
                                               :description => Faker::Name.first_name, 
                                               :account_id => article.account_id)
        attachment.save
        article.draft.publish! if article.draft
        article.reload
        create_draft(article: article)
        article.draft.meta[:deleted_attachments] ||= {}
        deleted_attachment = []
        deleted_attachment << article.attachments.first.id
        article.draft.meta[:deleted_attachments].merge!({ attachments: deleted_attachment })
        article.draft.save
        session = Faker::Name.name
        stub_version_session(session) do
          stub_version_content do
            article_version = article_meta.safe_send('primary_article').solution_article_versions.latest.second
            params_hash = { session: article_version.session }
            should_create_version(article) do
              post :restore, controller_params(version: 'private', article_id: article_meta.id, id: article_version.version_no)
              assert_equal article.solution_article_versions.latest.first.meta[:attachments].count, 1
              assert_response 204
            end
          end
        end
      end

      def test_restore_with_deleted_cloud_files
        article_meta = get_article_with_versions.parent
        article = article_meta.safe_send('primary_article')
        cloud_file = article.cloud_files.build(:url => 'https://www.dropbox.com/s/7d3z51nidxe358m/GettingStarted.pdf?dl=0',
                                               :application_id => 20,
                                               :filename => 'Getting Started.pdf')
        cloud_file.save!
        article.draft.publish! if article.draft
        article.reload
        create_draft(article: article)
        draft = article.reload.draft
        draft.meta[:deleted_attachments] ||= {}
        deleted_cloud_files = []
        deleted_cloud_files << article.cloud_files.first.id
        draft.meta[:deleted_attachments].merge!({ cloud_files: deleted_cloud_files })
        draft.save!
        draft.publish!
        stub_version_content do
          article_version = article.reload.solution_article_versions.latest.second
          should_create_version(article) do
            post :restore, controller_params(version: 'private', article_id: article_meta.id, id: article_version.version_no)
            assert_response 204
            assert_equal article.reload.solution_article_versions.latest.first.meta[:cloud_files].count, 1
          end
        end
      end

      def test_restore_with_deleted_attachments_in_draft
        article_meta = get_article_with_versions.parent
        article = article_meta.safe_send('primary_article')
        article.draft.publish! if article.draft

        attachment = article.attachments.build(content: fixture_file_upload('/files/attachment.txt', 'text/plain', :binary), description: Faker::Name.first_name, account_id: article.account_id)
        attachment.save

        create_draft(article: article)
        article.draft.meta[:deleted_attachments] ||= {}

        deleted_attachment = article.draft.meta[:deleted_attachments].key?(:attachments) ? article.draft.meta[:deleted_attachments][:attachments] : []
        deleted_attachment << attachment.id
        article.draft.meta[:deleted_attachments][:attachments] = deleted_attachment
        article.draft.save

        session = Faker::Name.name
        stub_version_session(session) do
          stub_version_content do
            article_version = article_meta.safe_send('primary_article').solution_article_versions.latest.third
            params_hash = { session: article_version.session }
            should_create_version(article) do
              post :restore, controller_params(version: 'private', article_id: article_meta.id, id: article_version.version_no)
              assert_equal article.draft.meta[:deleted_attachments][:attachments].count, 1
              assert_response 204
            end
          end
        end
      end

      def test_attachment_size_validation_during_restore
        article_meta = get_article_with_versions.parent
        article = article_meta.safe_send('primary_article')

        file_size = Account.current.attachment_limit
        file_props = {
          content: fixture_file_upload('/files/attachment.txt', 'text/plain', :binary),
          description: Faker::Name.first_name,
          account_id: article.account_id,
          content_file_size: file_size.megabytes
        }

        attachment = article.attachments.build(file_props)
        attachment.save

        cloud_file = article.cloud_files.build(url: 'https://www.dropbox.com/s/7d3z51nidxe358m/GettingStarted.pdf?dl=0', application_id: 20, filename: 'Getting Started.pdf')
        cloud_file.save

        article.draft.publish! if article.draft
        create_draft(article: article)

        article.draft.meta[:deleted_attachments] ||= {}
        deleted_attachment = article.draft.meta[:deleted_attachments].key?(:attachments) ? article.draft.meta[:deleted_attachments][:attachments] : []
        deleted_attachment << article.attachments.first.id
        article.draft.meta[:deleted_attachments][:attachments] = deleted_attachment

        deleted_cloud_file = article.draft.meta[:deleted_attachments].key?(:cloud_files) ? article.draft.meta[:deleted_attachments][:cloud_files] : []
        deleted_cloud_file << article.cloud_files.first.id
        article.draft.meta[:deleted_attachments][:cloud_files] = deleted_cloud_file
        article.draft.save

        draft_attachment = article.draft.attachments.build(file_props)
        draft_attachment.save
        Account.any_instance.stubs(:kb_increased_file_limit_enabled?).returns(false)

        session = Faker::Name.name
        stub_version_session(session) do
          should_not_create_version(article) do
            article_version = article_meta.safe_send('primary_article').solution_article_versions.latest.second
            params_hash = { session: article_version.session }
            post :restore, controller_params(version: 'private', article_id: article_meta.id, id: article_version.version_no)
            assert_response 400
            match_json(attachment_size_validation_error_pattern(file_size))
          end
        end
      ensure
        article.attachments.delete(attachment)
        article.draft.attachments.delete(draft_attachment)
        Account.any_instance.unstub(:kb_increased_file_limit_enabled?)
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
    end
  end
end
