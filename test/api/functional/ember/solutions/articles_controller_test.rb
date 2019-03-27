require_relative '../../../test_helper'
module Ember
  module Solutions
    class ArticlesControllerTest < ActionController::TestCase
      include SolutionsTestHelper

      def setup
        super
        initial_setup
        @account.reload
      end

      @@initial_setup_run = false

      def initial_setup
        return if @@initial_setup_run
        MixpanelWrapper.stubs(:send_to_mixpanel).returns(true)
        Account.stubs(:current).returns(@account)
        $redis_others.perform_redis_op('set', 'ARTICLE_SPAM_REGEX', '(gmail|kindle|face.?book|apple|microsoft|google|aol|hotmail|aim|mozilla|quickbooks|norton).*(support|phone|number)')
        $redis_others.perform_redis_op('set', 'PHONE_NUMBER_SPAM_REGEX', '(1|I)..?8(1|I)8..?85(0|O)..?78(0|O)6|(1|I)..?877..?345..?3847|(1|I)..?877..?37(0|O)..?3(1|I)89|(1|I)..?8(0|O)(0|O)..?79(0|O)..?9(1|I)86|(1|I)..?8(0|O)(0|O)..?436..?(0|O)259|(1|I)..?8(0|O)(0|O)..?969..?(1|I)649|(1|I)..?844..?922..?7448|(1|I)..?8(0|O)(0|O)..?75(0|O)..?6584|(1|I)..?8(0|O)(0|O)..?6(0|O)4..?(1|I)88(0|O)|(1|I)..?877..?242..?364(1|I)|(1|I)..?844..?782..?8(0|O)96|(1|I)..?844..?895..?(0|O)4(1|I)(0|O)|(1|I)..?844..?2(0|O)4..?9294|(1|I)..?8(0|O)(0|O)..?2(1|I)3..?2(1|I)7(1|I)|(1|I)..?855..?58(0|O)..?(1|I)8(0|O)8|(1|I)..?877..?424..?6647|(1|I)..?877..?37(0|O)..?3(1|I)89|(1|I)..?844..?83(0|O)..?8555|(1|I)..?8(0|O)(0|O)..?6(1|I)(1|I)..?5(0|O)(0|O)7|(1|I)..?8(0|O)(0|O)..?584..?46(1|I)(1|I)|(1|I)..?844..?389..?5696|(1|I)..?844..?483..?(0|O)332|(1|I)..?844..?78(0|O)..?675(1|I)|(1|I)..?8(0|O)(0|O)..?596..?(1|I)(0|O)65|(1|I)..?888..?573..?5222|(1|I)..?855..?4(0|O)9..?(1|I)555|(1|I)..?844..?436..?(1|I)893|(1|I)..?8(0|O)(0|O)..?89(1|I)..?4(0|O)(0|O)8|(1|I)..?855..?662..?4436')
        $redis_others.perform_redis_op('set', 'CONTENT_SPAM_CHAR_REGEX', 'ℴ|ℕ|ℓ|ℳ|ℱ|ℋ|ℝ|ⅈ|ℯ|ℂ|○|ℬ|ℂ|ℙ|ℹ|ℒ|ⅉ|ℐ')
        additional = @account.account_additional_settings
        additional.supported_languages = ['es', 'ru-RU']
        additional.save
        subscription = @account.subscription
        subscription.state = 'active'
        subscription.save
        @account.reload
        setup_articles
        @@initial_setup_run = true
        MixpanelWrapper.unstub(:send_to_mixpanel)
        Account.unstub(:current)
      end

      def setup_articles
        @category_meta = Solution::CategoryMeta.last

        @folder_meta = Solution::FolderMeta.new
        @folder_meta.visibility = 1
        @folder_meta.solution_category_meta = @category_meta
        @folder_meta.account = @account
        @folder_meta.save

        @folder = Solution::Folder.new
        @folder.name = 'test folder'
        @folder.description = 'test description'
        @folder.account = @account
        @folder.parent_id = @folder_meta.id
        @folder.language_id = Language.find_by_code('en').id
        @folder.save

        @articlemeta = Solution::ArticleMeta.new
        @articlemeta.art_type = 1
        @articlemeta.solution_folder_meta_id = @folder_meta.id
        @articlemeta.solution_category_meta = @folder_meta.solution_category_meta
        @articlemeta.account_id = @account.id
        @articlemeta.published = false
        @articlemeta.save

        @article = Solution::Article.new
        @article.title = 'Sample'
        @article.description = '<b>aaa</b>'
        @article.status = 2
        @article.language_id = @account.language_object.id
        @article.parent_id = @articlemeta.id
        @article.account_id = @account.id
        @article.user_id = @account.agents.first.id
        @article.save

        temp_article_meta = Solution::ArticleMeta.new
        temp_article_meta.art_type = 1
        temp_article_meta.solution_folder_meta_id = @folder_meta.id
        temp_article_meta.solution_category_meta = @folder_meta.solution_category_meta
        temp_article_meta.account_id = @account.id
        temp_article_meta.published = false
        temp_article_meta.save

        temp_article = Solution::Article.new
        temp_article.title = 'Sample article without draft'
        temp_article.description = '<b>Test</b>'
        temp_article.status = 2
        temp_article.language_id = @account.language_object.id
        temp_article.parent_id = temp_article_meta.id
        temp_article.account_id = @account.id
        temp_article.user_id = @account.agents.first.id
        temp_article.save

        @draft = Solution::Draft.new
        @draft.account = @account
        @draft.article = @article
        @draft.title = 'Sample'
        @draft.category_meta = Solution::FolderMeta.first.solution_category_meta
        @draft.status = 1
        @draft.description = '<b>aaa</b>'
        @draft.save

        @draft_body = Solution::DraftBody.new
        @draft_body.draft = @draft
        @draft_body.description = '<b>aaa</b>'
        @draft_body.account = @account
        @draft_body.save

        @category = Solution::Category.new
        @category.name = "es category"
        @category.description = "es cat description"
        @category.language_id = Language.find_by_code('es').id
        @category.parent_id = @category_meta.id
        @category.account = @account
        @category.save

        @folder = Solution::Folder.new
        @folder.name = 'es folder'
        @folder.description = 'es folder description'
        @folder.account = @account
        @folder.parent_id = @folder_meta.id
        @folder.language_id = Language.find_by_code('es').id
        @folder.save

        @article_with_lang = Solution::Article.new
        @article_with_lang.title = 'es article'
        @article_with_lang.description = '<b>aaa</b>'
        @article_with_lang.status = 1
        @article_with_lang.language_id = Language.find_by_code('es').id
        @article_with_lang.parent_id = @articlemeta.id
        @article_with_lang.account_id = @account.id
        @article_with_lang.user_id = @account.agents.first.id
        @article_with_lang.save
      end

      def wrap_cname(params)
        { article: params }
      end

      def test_index_with_no_params
        article_ids = []
        article_ids = @account.solution_articles.all.collect(&:parent_id)
        get :index, controller_params(version: 'private')
        assert_response 400
        match_json([bad_request_error_pattern('language_id', :missing_field)])
      end

      def test_index_with_invalid_ids
        valid_article_id = @account.solution_articles.last.parent_id
        invalid_ids = [valid_article_id + 10, valid_article_id + 20]
        get :index, controller_params(version: 'private', ids: invalid_ids.join(','), language_id: 6)
        assert_response 404
      end

      def test_index_with_valid_ids
        article_ids = []
        article_ids = @account.solution_articles.all.collect(&:parent_id)
        get :index, controller_params(version: 'private', ids: article_ids.join(','), language_id: 6)
        articles = @account.solution_articles.where(parent_id: article_ids, language_id: 6).first(10)
        assert_response 200
        pattern = articles.map { |article| private_api_solution_article_pattern_index(article) }
        match_json(pattern)
      end

      def test_index_with_valid_ids_array
        article_ids = []
        article_ids = @account.solution_articles.all.collect(&:parent_id)
        get :index, controller_params(version: 'private', ids: article_ids, language_id: 6)
        articles = @account.solution_articles.where(parent_id: article_ids, language_id: 6).first(10)
        assert_response 200
        pattern = articles.map { |article| private_api_solution_article_pattern_index(article) }
        match_json(pattern)
      end

      def test_index_with_valid_ids_and_different_language
        article_ids = []
        article_ids = @account.solution_articles.where(language_id: 8).map(&:parent_id)
        Account.any_instance.stubs(:all_portal_language_objects).returns([Language.find_by_code('es')])
        get :index, controller_params(version: 'private', ids: article_ids, language_id: 8)
        articles = @account.solution_articles.where(parent_id: article_ids, language_id: 8).first(10)
        assert_response 200
        pattern = articles.map { |article| private_api_solution_article_pattern_index(article) }
        match_json(pattern)
        Account.any_instance.unstub(:all_portal_language_objects)
      end

      def test_index_with_additional_params
        article_ids = []
        article_ids = @account.solution_articles.all.collect(&:parent_id)
        get :index, controller_params(version: 'private', ids: article_ids.join(','), language_id: 6, test: 2)
        articles = @account.solution_articles.where(parent_id: article_ids, language_id: 6).first(10)
        assert_response 400
        match_json([bad_request_error_pattern('test', :invalid_field)])
      end

      def test_index_with_invalid_language_id
        article_ids = []
        article_ids = @account.solution_articles.all.collect(&:parent_id)
        get :index, controller_params(version: 'private', ids: article_ids.join(','), language_id: 1000)
        assert_response 400
        match_json([bad_request_error_pattern('language_id', :not_included, list: @account.all_portal_language_objects.map(&:id))])
      end

      def test_index_with_valid_ids_and_user_id
        article_ids = []
        article_ids = @account.solution_articles.all.collect(&:parent_id)
        get :index, controller_params(version: 'private', ids: article_ids.join(','), user_id: @agent.id, language_id: 6)
        articles = @account.solution_articles.where(parent_id: article_ids, language_id: 6).first(10)
        assert_response 200
        pattern = articles.map { |article| private_api_solution_article_pattern_index(article, {}, true, @agent) }
        match_json(pattern)
      end

      def test_index_with_both_draft_and_article
        draft = @account.solution_drafts.last
        get :index, controller_params(version: 'private', ids: draft.article.parent_id, language_id: 6)
        response_body = JSON.parse(response.body).last
        assert_response 200
        response_body.must_match_json_expression private_api_solution_article_pattern_index(draft.article)
      end

      def test_article_content_with_invalid_id
        article = @account.solution_articles.where(language_id: 6).last
        get :article_content, controller_params(version: 'private', id: article.parent_id + 20, language_id: 6)
        assert_response 404
      end

      def test_article_content
        article = @account.solution_articles.where(language_id: 6).last
        get :article_content, controller_params(version: 'private', id: article.parent_id, language_id: 6)
        assert_response 200
        match_json(article_content_pattern(article))
      end

      def test_article_content_with_different_language
        Account.any_instance.stubs(:all_portal_language_objects).returns([Language.find_by_code('es')])
        article = @account.solution_articles.where(language_id: 8).last
        get :article_content, controller_params(version: 'private', id: article.parent_id, language_id: 8)
        assert_response 200
        match_json(article_content_pattern(article))
        Account.any_instance.unstub(:all_portal_language_objects)
      end

      def test_article_content_without_language_id
        article = @account.solution_articles.where(language_id: 6).last
        Account.current.reload
        get :article_content, controller_params(version: 'private', id: article.parent_id)
        assert_response 400
        match_json([bad_request_error_pattern('language_id', :missing_field)])
      end

      def test_article_content_with_additional_params
        article = @account.solution_articles.where(language_id: 6).last
        get :article_content, controller_params(version: 'private', id: article.parent_id, language_id: 6, test: 2)
        assert_response 400
        match_json([bad_request_error_pattern('test', :invalid_field)])
      end

      def test_article_content_with_invalid_language_id
        article = @account.solution_articles.where(language_id: 6).last
        get :article_content, controller_params(version: 'private', id: article.parent_id, language_id: 1000)
        assert_response 400
        match_json([bad_request_error_pattern('language_id', :not_included, list: @account.all_portal_language_objects.map(&:id))])
      end

      def test_article_content_with_both_draft_and_article
        draft = @account.solution_drafts.last
        get :article_content, controller_params(version: 'private', id: draft.article.parent_id, language_id: 6)
        assert_response 200
        match_json(article_content_pattern(draft.article))
      end

      def test_show_article_without_feature
        article = @account.solution_articles.last
        get :show, controller_params(version: 'private', id: article.parent_id)
        assert_response 200
      end

      def test_bulk_update_tags
        article = @account.solution_articles.where(language_id: 6).last
        tags = [Faker::Name.name, Faker::Name.name]
        put :bulk_update, construct_params({ version: 'private' }, ids: [article.parent_id], properties: { tags: tags })
        assert_response 204
        article.reload
        assert (article.reload.tags.map(&:name) - tags).empty?
      end

      def test_bulk_update_tags_without_tags_privilege
        User.any_instance.stubs(:privilege?).with(:create_tags).returns(false)
        User.any_instance.stubs(:privilege?).with(:publish_solution).returns(true)
        article = @account.solution_articles.where(language_id: 6).last
        tags = [Faker::Name.name, Faker::Name.name]
        put :bulk_update, construct_params({ version: 'private' }, ids: [article.parent_id], properties: { tags: tags })
        assert_response 400
      ensure
        User.any_instance.unstub(:privilege?)
      end

      def test_bulk_update_author
        folder = @account.solution_folder_meta.where(is_default: false).first
        populate_articles(folder)
        articles = folder.solution_article_meta.pluck(:id)
        agent_id = @account.technicians.first.id
        tags = [Faker::Name.name, Faker::Name.name]
        put :bulk_update, construct_params({ version: 'private' }, ids: articles, properties: { agent_id: agent_id })
        assert_response 204
        assert folder.reload.solution_article_meta.all? { |meta| meta.solution_articles.where(language_id: @account.language_object.id).first.user_id == agent_id }
      ensure
        User.any_instance.unstub(:privilege?)
      end

      def test_bulk_update_author_without_publish_solution
        folder = @account.solution_folder_meta.where(is_default: false).first
        populate_articles(folder)
        articles = folder.solution_article_meta.pluck(:id)
        agent_id = @account.agents.first.id
        User.any_instance.stubs(:privilege?).with(:publish_solution).returns(false)
        tags = [Faker::Name.name, Faker::Name.name]
        put :bulk_update, construct_params({ version: 'private' }, ids: articles, properties: { agent_id: agent_id })
        assert_response 403
      ensure
        User.any_instance.unstub(:privilege?)
      end

      def test_bulk_update_author_without_admin_tasks
        folder = @account.solution_folder_meta.where(is_default: false).first
        populate_articles(folder)
        articles = folder.solution_article_meta.pluck(:id)
        agent_id = @account.agents.first.id
        User.any_instance.stubs(:privilege?).with(:publish_solution).returns(true)
        User.any_instance.stubs(:privilege?).with(:admin_tasks).returns(false)
        tags = [Faker::Name.name, Faker::Name.name]
        put :bulk_update, construct_params({ version: 'private' }, ids: articles, properties: { agent_id: agent_id })
        assert_response 400
        match_json(bulk_validation_error_pattern(:agent_id, :cannot_change_author_id))
      ensure
        User.any_instance.unstub(:privilege?)
      end

      def test_bulk_update_invaild_author
        folder = @account.solution_folder_meta.where(is_default: false).first
        populate_articles(folder)
        articles = folder.solution_article_meta.pluck(:id)
        tags = [Faker::Name.name, Faker::Name.name]
        put :bulk_update, construct_params({ version: 'private' }, ids: articles, properties: { agent_id: 10_192_910 })
        assert_response 400
        match_json(bulk_validation_error_pattern(:agent_id, :invalid_agent_id))
      end

      def test_bulk_update_invaild_author_datatype
        folder = @account.solution_folder_meta.where(is_default: false).first
        populate_articles(folder)
        articles = folder.solution_article_meta.pluck(:id)
        tags = [Faker::Name.name, Faker::Name.name]
        put :bulk_update, construct_params({ version: 'private' }, ids: articles, properties: { agent_id: 'one' })
        assert_response 400
        match_json(bulk_validation_error_pattern(:agent_id, :datatype_mismatch))
      end

      def test_bulk_update_folder
        folder = @account.solution_folder_meta.where(is_default: false).first
        populate_articles(folder)
        articles = folder.solution_article_meta.pluck(:id)
        put :bulk_update, construct_params({ version: 'private' }, ids: articles, properties: { folder_id: folder.id })
        assert_response 204
        assert folder.reload.solution_article_meta.all? { |meta| meta.solution_folder_meta_id == folder.id }
      end

      def test_bulk_update_invalid_folder
        folder = @account.solution_folder_meta.where(is_default: false).first
        populate_articles(folder)
        articles = folder.solution_article_meta.pluck(:id)
        tags = [Faker::Name.name, Faker::Name.name]
        put :bulk_update, construct_params({ version: 'private' }, ids: articles, properties: { folder_id: 10_102_910_201 })
        assert_response 400
        match_json(bulk_validation_error_pattern(:folder_id, :invalid_folder_id))
      end

      def test_bulk_update_invaild_folder_datatype
        folder = @account.solution_folder_meta.where(is_default: false).first
        populate_articles(folder)
        articles = folder.solution_article_meta.pluck(:id)
        put :bulk_update, construct_params({ version: 'private' }, ids: articles, properties: { folder_id: 'one' })
        assert_response 400
        match_json(bulk_validation_error_pattern(:folder_id, :datatype_mismatch))
      end

      def test_bulk_update_without_anyproperties
        folder = @account.solution_folder_meta.where(is_default: false).first
        populate_articles(folder)
        articles = folder.solution_article_meta.pluck(:id)
        tags = [Faker::Name.name, Faker::Name.name]
        put :bulk_update, construct_params({ version: 'private' }, ids: articles)
        assert_response 400
        match_json(error_pattern(:properties, :missing_field))
      end

      def test_bulk_update_articles_exception
        folder = @account.solution_folder_meta.where(is_default: false).first
        populate_articles(folder)
        articles = folder.solution_article_meta.pluck(:id)
        tags = [Faker::Name.name, Faker::Name.name]
        Solution::ArticleMeta.any_instance.stubs(:save!).raises(StandardError)
        put :bulk_update, construct_params({ version: 'private' }, ids: articles, properties: { folder_id: folder.id })
        assert_response 202
      ensure
        Solution::ArticleMeta.any_instance.unstub(:save!)
      end

      private

        def populate_articles(folder_meta)
          return if folder_meta.article_count > 4
          for i in 1..2 do
            articlemeta = Solution::ArticleMeta.new
            articlemeta.art_type = 1
            articlemeta.solution_folder_meta_id = folder_meta.id
            articlemeta.solution_category_meta = folder_meta.solution_category_meta
            articlemeta.account_id = @account.id
            articlemeta.published = false
            articlemeta.save

            article_with_lang = Solution::Article.new
            article_with_lang.title = Faker::Name.name
            article_with_lang.description = '<b>aaa</b>'
            article_with_lang.status = 1
            article_with_lang.language_id = @account.language_object.id
            article_with_lang.parent_id = articlemeta.id
            article_with_lang.account_id = @account.id
            article_with_lang.user_id = @account.agents.first.id
            article_with_lang.save
          end
        end

        def bulk_validation_error_pattern(field, code)
          {
            description: 'Validation failed',
            errors: [
              {
                field: 'properties',
                nested_field: "properties.#{field}",
                message: :string,
                code: code.to_s
              }
            ]
          }
        end

        def error_pattern(field, code)
          {
            description: 'Validation failed',
            errors: [
              {
                field: field.to_s,
                message: :string,
                code: code.to_s
              }
            ]
          }
        end
    end
  end
end
