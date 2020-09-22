require_relative '../../../test_helper'

require Rails.root.join('test', 'models', 'helpers', 'tag_use_test_helper.rb')

['solutions_helper.rb', 'solution_builder_helper.rb'].each { |file| require Rails.root.join('spec', 'support', file) }

module Ember
  module Solutions
    class ArticlesControllerTest < ActionController::TestCase
      include SearchTestHelper
      include SolutionsTestHelper
      include AttachmentsTestHelper
      include PrivilegesHelper
      include InstalledApplicationsTestHelper
      include SolutionsHelper
      include SolutionBuilderHelper
      include TagUseTestHelper
      include SolutionsArticlesTestHelper
      include SolutionsArticlesCommonTests
      include SolutionsArticleVersionsTestHelper
      include SolutionsApprovalsTestHelper
      include SolutionsTemplatesTestHelper
      include SolutionsPlatformsTestHelper

      def setup
        super
        Account.stubs(:current).returns(@account)
        initial_setup
        setup_multilingual
        @account.reload
        @account.revoke_feature :marketplace
      end

      def teardown
        Account.unstub(:current)
        @account.add_feature :marketplace
      end

      @@initial_setup_run = false

      def initial_setup
        @portal_id = Account.current.main_portal.id
        return if @@initial_setup_run

        setup_redis_for_articles

        @account.add_feature(:article_filters)
        @account.add_feature(:article_export)
        @account.add_feature(:adv_article_bulk_actions)
        @account.add_feature(:suggested_articles_count)

        @account.reload
        setup_articles
        @@initial_setup_run = true
      end

      def setup_articles # dont destroy articles from setup_articles in any of our test cases
        @@category_meta = Solution::CategoryMeta.last

        @folder_meta = Solution::FolderMeta.new
        @folder_meta.visibility = 1
        @folder_meta.solution_category_meta = @@category_meta
        @folder_meta.account = @account
        @folder_meta.save
        @@folder_meta = @folder_meta

        @folder = Solution::Folder.new
        @folder.name = "test folder #{Time.now}"
        @folder.description = 'test description'
        @folder.account = @account
        @folder.parent_id = @folder_meta.id
        @folder.language_id = Language.find_by_code('en').id
        @folder.save
        @@folder = @folder

        @articlemeta = Solution::ArticleMeta.new
        @articlemeta.art_type = 1
        @articlemeta.solution_folder_meta_id = @folder_meta.id
        @articlemeta.solution_category_meta = @folder_meta.solution_category_meta
        @articlemeta.account_id = @account.id
        @articlemeta.published = false
        @articlemeta.save
        @@articlemeta = @articlemeta

        @article = Solution::Article.new
        @article.title = "Sample #{Time.now}"
        @article.description = '<b>aaa</b>'
        @article.status = 2
        @article.language_id = @account.language_object.id
        @article.parent_id = @articlemeta.id
        @article.account_id = @account.id
        @article.user_id = @account.agents.first.id
        @article.save
        @@article = @article

        temp_article_meta = Solution::ArticleMeta.new
        temp_article_meta.art_type = 1
        temp_article_meta.solution_folder_meta_id = @folder_meta.id
        temp_article_meta.solution_category_meta = @folder_meta.solution_category_meta
        temp_article_meta.account_id = @account.id
        temp_article_meta.published = false
        temp_article_meta.save

        temp_article = Solution::Article.new
        temp_article.title = "Sample article without draft #{Time.now}"
        temp_article.description = '<b>Test</b>'
        temp_article.status = 2
        temp_article.language_id = @account.language_object.id
        temp_article.parent_id = temp_article_meta.id
        temp_article.account_id = @account.id
        temp_article.user_id = @account.agents.first.id
        temp_article.save

        create_draft(article: @article)

        @category = Solution::Category.new
        @category.name = "es category #{Time.now}"
        @category.description = 'es cat description'
        @category.language_id = Language.find_by_code('es').id
        @category.parent_id = @@category_meta.id
        @category.account = @account
        @category.save
        @category_with_lang = @category

        @folder = Solution::Folder.new
        @folder.name = "es folder #{Time.now}"
        @folder.description = 'es folder description #{Time.now}'
        @folder.account = @account
        @folder.parent_id = @folder_meta.id
        @folder.language_id = Language.find_by_code('es').id
        @folder.save
        @folder_with_lang = @folder

        @article_with_lang = Solution::Article.new
        @article_with_lang.title = 'es article'
        @article_with_lang.description = '<b>aaa</b>'
        @article_with_lang.status = 1
        @article_with_lang.language_id = Language.find_by_code('es').id
        @article_with_lang.parent_id = @articlemeta.id
        @article_with_lang.account_id = @account.id
        @article_with_lang.user_id = @account.agents.first.id
        @article_with_lang.save
        @article_with_lang = @article_with_lang
      end

      def wrap_cname(params)
        { article: params }
      end

      def test_index_with_no_params
        article_ids = []
        article_ids = @account.solution_articles.limit(10).collect(&:parent_id)
        get :index, controller_params(version: 'private')
        assert_response 400
        match_json([bad_request_error_pattern('language', :missing_field)])
      end

      def test_index_with_invalid_ids
        valid_article_id = @account.solution_articles.last.parent_id
        invalid_ids = [valid_article_id + 10, valid_article_id + 20]
        get :index, controller_params(version: 'private', ids: invalid_ids.join(','), language: 'en')
        assert_response 404
      end

      def test_index_with_valid_ids
        article_ids = []
        article_ids = @account.solution_articles.where(language_id: 6).limit(10).collect(&:parent_id)
        get :index, controller_params(version: 'private', ids: article_ids.join(','), language: 'en')
        articles = @account.solution_articles.where(parent_id: article_ids, language_id: 6).first(10)
        assert_response 200
        pattern = articles.map { |article| private_api_solution_article_index_pattern(article, exclude_draft: true) }
        match_json(pattern.ordered!)
      end

      def test_index_with_language_id
        language_id = 6
        article_ids = @account.solution_articles.where(language_id: 6).limit(10).collect(&:parent_id)
        get :index, controller_params(version: 'private', ids: article_ids.join(','), language_id: language_id)
        articles = @account.solution_articles.where(parent_id: article_ids, language_id: language_id).first(10)
        assert_response 200
        pattern = articles.map { |article| private_api_solution_article_index_pattern(article, exclude_draft: true) }
        match_json(pattern.ordered!)
      end

      def test_index_with_invalid_language_id
        language_id = 6
        article_ids = @account.solution_articles.where(language_id: 6).limit(10).collect(&:parent_id)
        get :index, controller_params(version: 'private', ids: article_ids.join(','), language_id: 0)
        assert_response 404
      end

      def test_index_with_valid_ids_array
        article_ids = []
        article_ids = @account.solution_articles.where(language_id: 6).limit(10).collect(&:parent_id)
        get :index, controller_params(version: 'private', ids: article_ids, language: 'en')
        articles = @account.solution_articles.where(parent_id: article_ids, language_id: 6).first(10)
        assert_response 200
        pattern = articles.map { |article| private_api_solution_article_index_pattern(article, exclude_draft: true) }
        match_json(pattern.ordered!)
      end

      def test_index_with_valid_ids_and_different_language
        article_ids = []
        article_ids = @account.solution_articles.where(language_id: 8).map(&:parent_id)
        Account.any_instance.stubs(:all_language_objects).returns([Language.find_by_code('es')])
        get :index, controller_params(version: 'private', ids: article_ids, language: 'es')
        articles = @account.solution_articles.where(parent_id: article_ids, language_id: 8).first(10)
        assert_response 200
        pattern = articles.map { |article| private_api_solution_article_index_pattern(article, exclude_draft: true) }
        match_json(pattern.ordered!)
        Account.any_instance.unstub(:all_language_objects)
      end

      def test_index_with_additional_params
        article_ids = []
        article_ids = @account.solution_articles.where(language_id: 6).limit(10).collect(&:parent_id)
        get :index, controller_params(version: 'private', ids: article_ids.join(','), language: 'en', test: 2)
        articles = @account.solution_articles.where(parent_id: article_ids, language_id: 6).first(10)
        assert_response 400
        match_json([bad_request_error_pattern('test', :invalid_field)])
      end

      def test_index_with_invalid_language
        article_ids = []
        article_ids = @account.solution_articles.limit(10).collect(&:parent_id)
        get :index, controller_params(version: 'private', ids: article_ids.join(','), language: '1000')
        assert_response 400
        match_json([bad_request_error_pattern('language', :not_included, list: @account.all_language_objects.map(&:code).join(','))])
      end

      def test_index_with_valid_ids_and_user_id
        article_ids = []
        article_ids = @account.solution_articles.where(language_id: 6).limit(10).collect(&:parent_id)
        get :index, controller_params(version: 'private', ids: article_ids.join(','), user_id: @agent.id, language: 'en')
        articles = @account.solution_articles.where(parent_id: article_ids, language_id: 6).first(10)
        assert_response 200
        pattern = articles.map { |article| private_api_solution_article_index_pattern(article, { exclude_draft: true }, true, @agent) }
        match_json(pattern.ordered!)
      end

      def test_index_with_both_draft_and_article
        sample_article = @account.solution_articles.where(language_id: 6).first
        create_draft(article: sample_article)
        draft = sample_article.draft
        get :index, controller_params(version: 'private', ids: draft.article.parent_id, language: 'en')
        response_body = JSON.parse(response.body).last
        assert_response 200
        response_body.must_match_json_expression private_api_solution_article_index_pattern(draft.article, exclude_draft: true)
      end

      def test_article_content_with_invalid_id
        article = @account.solution_articles.where(language_id: 6).last
        get :article_content, controller_params(version: 'private', id: article.parent_id + 20, language: 'en')
        assert_response 404
      end

      def test_article_content
        article = @account.solution_articles.where(language_id: 6).last
        get :article_content, controller_params(version: 'private', id: article.parent_id, language: 'en')
        assert_response 200
        match_json(article_content_pattern(article))
      end

      def test_article_content_with_language_id
        language_id = 6
        article = @account.solution_articles.where(language_id: language_id).last
        get :article_content, controller_params(version: 'private', id: article.parent_id, language_id: language_id)
        assert_response 200
        match_json(article_content_pattern(article))
      end

      def test_article_content_with_invalid_language_id
        language_id = 6
        article = @account.solution_articles.where(language_id: language_id).last
        get :article_content, controller_params(version: 'private', id: article.parent_id, language_id: 0)
        assert_response 404
      end

      def test_article_content_with_different_language
        Account.any_instance.stubs(:all_language_objects).returns([Language.find_by_code('es')])
        article = @account.solution_articles.where(language_id: 8).last
        get :article_content, controller_params(version: 'private', id: article.parent_id, language: 'es')
        assert_response 200
        match_json(article_content_pattern(article))
        Account.any_instance.unstub(:all_language_objects)
      end

      def test_article_content_without_language_id
        article = @account.solution_articles.where(language_id: 6).last
        Account.current.reload
        get :article_content, controller_params(version: 'private', id: article.parent_id)
        assert_response 400
        match_json([bad_request_error_pattern('language', :missing_field)])
      end

      def test_article_content_with_additional_params
        article = @account.solution_articles.where(language_id: 6).last
        get :article_content, controller_params(version: 'private', id: article.parent_id, language: 'en', test: 2)
        assert_response 400
        match_json([bad_request_error_pattern('test', :invalid_field)])
      end

      def test_article_content_with_invalid_language_id
        article = @account.solution_articles.where(language_id: 6).last
        get :article_content, controller_params(version: 'private', id: article.parent_id, language: '1000')
        assert_response 404
        match_json(request_error_pattern(:language_not_allowed, code: '1000', list: (@account.supported_languages + [@account.language]).sort.join(', ')))
      end

      def test_article_content_with_both_draft_and_article
        draft = @account.solution_drafts.last
        get :article_content, controller_params(version: 'private', id: draft.article.parent_id, language: draft.article.language_code)
        assert_response 200
        match_json(article_content_pattern(draft.article))
      end

      def test_show_article_without_feature
        article = @account.solution_articles.last
        get :show, controller_params(version: 'private', id: article.parent_id)
        assert_response 200
      end

      def test_show_published_article
        sample_article = get_article_without_draft
        sample_article.reload
        get :show, controller_params(version: 'private', id: sample_article.parent_id)
        match_json(private_api_solution_article_pattern(sample_article))
        assert_response 200
      end

      def test_show_draft_article
        sample_article = get_article_with_draft
        get :show, controller_params(version: 'private', id: sample_article.parent_id)
        match_json(private_api_solution_article_pattern(sample_article))
        assert_response 200
      end

      def test_show_published_article_with_freshconnect_enabled
        Account.any_instance.stubs(:collaboration_enabled?).returns(true)
        sample_article = get_article_without_draft
        sample_article.reload
        time_now = Time.zone.now
        Timecop.freeze(time_now) do
          get :show, controller_params(version: 'private', id: sample_article.parent_id)
        end
        resp_json = JSON.parse(response.body)
        convo_token_dec = decrypted_convo_token(resp_json['collaboration']['convo_token'])
        convo_token_dec.each(&:symbolize_keys!)
        assert_equal construct_convo_payload(sample_article, time_now), convo_token_dec
        resp_json.delete('collaboration')
        response.body = resp_json.to_json
        match_json(private_api_solution_article_pattern(sample_article))
        assert_response 200
      ensure
        Account.any_instance.unstub(:collaboration_enabled?)
      end

      def test_show_draft_article_with_freshconnect_enabled
        Account.any_instance.stubs(:collaboration_enabled?).returns(true)
        sample_article = get_article_with_draft
        time_now = Time.zone.now
        Timecop.freeze(time_now) do
          get :show, controller_params(version: 'private', id: sample_article.parent_id)
        end
        resp_json = JSON.parse(response.body)
        convo_token_dec = decrypted_convo_token(resp_json['collaboration']['convo_token'])
        convo_token_dec.each(&:symbolize_keys!)
        assert_equal construct_convo_payload(sample_article, time_now), convo_token_dec
        resp_json.delete('collaboration')
        response.body = resp_json.to_json
        match_json(private_api_solution_article_pattern(sample_article))
        assert_response 200
      ensure
        Account.any_instance.unstub(:collaboration_enabled?)
      end

      def test_show_unavailalbe_article
        get :show, controller_params(version: 'private', id: 99_999)
        assert_response :missing
      end

      def test_create_a_draft_article
        folder_meta = get_folder_meta
        title = Faker::Name.name
        paragraph = Faker::Lorem.paragraph
        post :create, construct_params({ version: 'private', id: folder_meta.id }, title: title, description: paragraph, status: 1)
        assert_response 201
        assert Solution::Article.last.draft
        match_json(private_api_solution_article_pattern(Solution::Article.last))
      end

      def test_create_with_base64_description
        folder_meta = get_folder_meta
        title = Faker::Name.name
        description = '<img src="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAUAAAAFCAYAAACNbyblAAAAHElEQVQI12P4//8/w38GIAXDIBKE0DHxgljNBAAO9TXL0Y4OHwAAAABJRU5ErkJggg==" alt="Red dot" />'

        post :create, construct_params({ version: 'private', id: folder_meta.id }, title: title, description: description, status: 1)

        assert_response 400
        match_json([bad_request_error_pattern('description', :article_description_base64_error, code: :article_base64_content_error)])
      end

      def test_update_with_base64_description_with_kb_allow_base64_images_enabled
        Account.any_instance.stubs(:kb_allow_base64_images_enabled?).returns(true)
        sample_article = get_article_without_draft
        base64_content = "<img src='data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAUAAAAFCAYAAACNbyblAAAAHElEQVQI12P48w38GIAXDIBKE0DHxgljNBAAO9TXL0Y4OHwAAAABJRU5ErkJggg==' alt='Red dot'/>"
        params_hash = {  title: 'new draft title', description: base64_content, agent_id: @agent.id }
        put :update, construct_params({ version: 'private', id: sample_article.parent_id }, params_hash)
        assert_response 200
        assert sample_article.reload.draft
        assert sample_article.reload.draft.reload.title == 'new draft title'
        match_json(private_api_solution_article_pattern(sample_article.reload))
      ensure
        Account.any_instance.unstub(:kb_allow_base64_images_enabled?)
      end

      def test_create_and_publish_article
        folder_meta = get_folder_meta
        title = Faker::Name.name
        paragraph = Faker::Lorem.paragraph
        post :create, construct_params({ version: 'private', id: folder_meta.id }, title: title, description: paragraph, status: 2)
        assert_response 201
        assert_nil Solution::Article.last.draft
        match_json(private_api_solution_article_pattern(Solution::Article.last))
      end

      def test_create_article_with_html_content
        folder_meta = get_folder_meta
        title = Faker::Name.name
        paragraph = "<h2 style=\"color: rgb(0, 0, 0); margin-top: 1em; margin-bottom: 0.25em; overflow: hidden; border-bottom-width: 1px; border-bottom-style: solid; border-bottom-color: rgb(170, 170, 170); font-family: 'Linux Libertine', Georgia, Times, serif, 'Helvetica Neue', Helvetica, Arial, sans-serif; line-height: 1.3;\">\n<span id=\"Etymology\">Etymology</span><span style=\"-webkit-user-select: none; font-size: small; font-weight: normal; margin-left: 1em; line-height: 1em; display: inline-block; white-space: nowrap; unicode-bidi: isolate; font-family: sans-serif, 'Helvetica Neue', Helvetica, Arial, sans-serif;\"><span style=\"margin-right: 0.25em; color: rgb(85, 85, 85);\">[</span><a href=\"https://en.wikipedia.org/w/index.php?title=Tamils&amp;action=edit&amp;section=1\" title=\"Edit section: Etymology\" style=\"color: rgb(11, 0, 128); background-image: none;\">edit</a><span style=\"margin-left: 0.25em; color: rgb(85, 85, 85);\">]</span></span>\n</h2>\n<p>See also: <a href=\"https://en.wikipedia.org/wiki/Sources_of_ancient_Tamil_history\" title=\"Sources of ancient Tamil history\" style=\"color: rgb(11, 0, 128); background-image: none;\">Sources of ancient Tamil history</a></p>\n<p style=\"margin-top: 0.5em; margin-bottom: 0.5em; line-height: 22.4px; color: rgb(37, 37, 37); font-family: sans-serif, 'Helvetica Neue', Helvetica, Arial, sans-serif; font-size: 14px;\">It is unknown as to whether the term <i>Thamizhar</i> and its equivalents in <a href=\"https://en.wikipedia.org/wiki/Prakrit\" title=\"Prakrit\" style=\"color: rgb(11, 0, 128); background-image: none;\">Prakrit</a> such as <i>Damela</i>, <i>Dameda</i>, <i>Dhamila</i> and <i>Damila</i> was a self designation or a term denoted by outsiders. Epigraphic evidence of an ethnic group termed as such is found in ancient Sri Lanka where a number of inscriptions have come to light datable from the 6th to the 5th century BCE mentioning <i>Damela</i> or <i>Dameda</i> persons. In the well-known <a href=\"https://en.wikipedia.org/wiki/Hathigumpha_inscription\" title=\"Hathigumpha inscription\" style=\"color: rgb(11, 0, 128); background-image: none;\">Hathigumpha inscription</a>of the <a href=\"https://en.wikipedia.org/wiki/Kalinga_(India)\" title=\"Kalinga (India)\" style=\"color: rgb(11, 0, 128); background-image: none;\">Kalinga</a> ruler <a href=\"https://en.wikipedia.org/wiki/Kharavela\" title=\"Kharavela\" style=\"color: rgb(11, 0, 128); background-image: none;\">Kharavela</a>, refers to a <i>T(ra)mira samghata</i> (Confederacy of Tamil rulers) dated to 150 BC. It also mentions that the league of Tamil kingdoms had been in existence 113 years before then.<sup id=\"cite_ref-KI157_30-0\" style=\"line-height: 1; unicode-bidi: isolate; white-space: nowrap; font-size: 11.2px; font-weight: normal; font-style: normal;\"><a href=\"https://en.wikipedia.org/wiki/Tamils#cite_note-KI157-30\" style=\"color: rgb(11, 0, 128); background-image: none;\">[29]</a></sup> In <a href=\"https://en.wikipedia.org/wiki/Amaravathi_village,_Guntur_district\" title=\"Amaravathi village, Guntur district\" style=\"color: rgb(11, 0, 128); background-image: none;\">Amaravati</a> in present-day <a href=\"https://en.wikipedia.org/wiki/Andhra_Pradesh\" title=\"Andhra Pradesh\" style=\"color: rgb(11, 0, 128); background-image: none;\">Andhra Pradesh</a> there is an inscription referring to a<i>Dhamila-vaniya</i> (Tamil trader) datable to the 3rd century AD.<sup id=\"cite_ref-KI157_30-1\" style=\"line-height: 1; unicode-bidi: isolate; white-space: nowrap; font-size: 11.2px; font-weight: normal; font-style: normal;\"><a href=\"https://en.wikipedia.org/wiki/Tamils#cite_note-KI157-30\" style=\"color: rgb(11, 0, 128); background-image: none;\">[29]</a></sup> Another inscription of about the same time in <a href=\"https://en.wikipedia.org/wiki/Nagarjunakonda\" title=\"Nagarjunakonda\" style=\"color: rgb(11, 0, 128); background-image: none;\">Nagarjunakonda</a> seems to refer to a<i>Damila</i>. A third inscription in <a href=\"https://en.wikipedia.org/wiki/Kanheri_Caves\" title=\"Kanheri Caves\" style=\"color: rgb(11, 0, 128); background-image: none;\">Kanheri Caves</a> refers to a <i>Dhamila-gharini</i> (Tamil house-holder). In the <a href=\"https://en.wikipedia.org/wiki/Buddhist\" title=\"Buddhist\" style=\"color: rgb(11, 0, 128); background-image: none;\">Buddhist</a> <a href=\"https://en.wikipedia.org/wiki/Jataka\" title=\"Jataka\" style=\"color: rgb(11, 0, 128); background-image: none;\">Jataka</a> story known as <i>Akiti Jataka</i>there is a mention to <i>Damila-rattha</i> (Tamil dynasty). There were trade relationship between the <a href=\"https://en.wikipedia.org/wiki/Roman_Empire\" title=\"Roman Empire\" style=\"color: rgb(11, 0, 128); background-image: none;\">Roman Empire</a> and <a href=\"https://en.wikipedia.org/wiki/Pandyan_Empire\" title=\"Pandyan Empire\" style=\"color: rgb(11, 0, 128); background-image: none;\">Pandyan Empire</a>. As recorded by <a href=\"https://en.wikipedia.org/wiki/Strabo\" title=\"Strabo\" style=\"color: rgb(11, 0, 128); background-image: none;\">Strabo</a>, <a href=\"https://en.wikipedia.org/wiki/Emperor_Augustus\" title=\"Emperor Augustus\" style=\"color: rgb(11, 0, 128); background-image: none;\">Emperor Augustus</a> of <a href=\"https://en.wikipedia.org/wiki/Rome\" title=\"Rome\" style=\"color: rgb(11, 0, 128); background-image: none;\">Rome</a> received at <a href=\"https://en.wikipedia.org/wiki/Antioch\" title=\"Antioch\" style=\"color: rgb(11, 0, 128); background-image: none;\">Antioch</a> an ambassador from a king called <i>Pandyan of Dramira</i>.<sup id=\"cite_ref-The_cyclop.C3.A6dia_of_India_and_of_Eastern_and_Southern_Asia_31-0\" style=\"line-height: 1; unicode-bidi: isolate; white-space: nowrap; font-size: 11.2px; font-weight: normal; font-style: normal;\"><a href=\"https://en.wikipedia.org/wiki/Tamils#cite_note-The_cyclop.C3.A6dia_of_India_and_of_Eastern_and_Southern_Asia-31\" style=\"color: rgb(11, 0, 128); background-image: none;\">[30]</a></sup> Hence, it is clear that by at least the 300 BC, the ethnic identity of Tamils has been formed as a distinct group.<sup id=\"cite_ref-KI157_30-2\" style=\"line-height: 1; unicode-bidi: isolate; white-space: nowrap; font-size: 11.2px; font-weight: normal; font-style: normal;\"><a href=\"https://en.wikipedia.org/wiki/Tamils#cite_note-KI157-30\" style=\"color: rgb(11, 0, 128); background-image: none;\">[29]</a></sup> <i>Thamizhar</i>is etymologically related to Tamil, the language spoken by Tamil people. Southworth suggests that the name comes from tam-miz &gt; tam-iz 'self-speak', or 'one's own speech'.<sup id=\"cite_ref-32\" style=\"line-height: 1; unicode-bidi: isolate; white-space: nowrap; font-size: 11.2px; font-weight: normal; font-style: normal;\"><a href=\"https://en.wikipedia.org/wiki/Tamils#cite_note-32\" style=\"color: rgb(11, 0, 128); background-image: none;\">[31]</a></sup> Zvelebil suggests an etymology of <i>tam-iz</i>, with tam meaning \"self\" or \"one's self\", and \"-iz\" having the connotation of \"unfolding sound\". Alternatively, he suggests a derivation of <i>tamiz</i> &lt; <i>tam-iz</i> &lt; <i>*tav-iz</i> &lt;<i>*tak-iz</i>, meaning in origin \"the proper process (of speaking).\"<sup id=\"cite_ref-33\" style=\"line-height: 1; unicode-bidi: isolate; white-space: nowrap; font-size: 11.2px; font-weight: normal; font-style: normal;\"><a href=\"https://en.wikipedia.org/wiki/Tamils#cite_note-33\" style=\"color: rgb(11, 0, 128); background-image: none;\">[32]</a></sup> Another theory say the term <i>Thamizhar</i> was derived from the name of the ancient people <i>Dravida</i> &gt; <i>Dramila</i> &gt; <i>Damila</i> &gt; <i>Tamila</i> &gt;<i>Tamilar</i><sup id=\"cite_ref-34\" style=\"line-height: 1; unicode-bidi: isolate; white-space: nowrap; font-size: 11.2px; font-weight: normal; font-style: normal;\"><a href=\"https://en.wikipedia.org/wiki/Tamils#cite_note-34\" style=\"color: rgb(11, 0, 128); background-image: none;\">[33]</a></sup></p>\n<p><br></p>\n"
        post :create, construct_params({ version: 'private', id: folder_meta.id }, title: title, description: paragraph, status: 2)
        assert_response 201
        match_json(private_api_solution_article_pattern(Solution::Article.last))
      end

      def test_create_article_with_html_data_content
        folder_meta = get_folder_meta
        title = Faker::Name.name
        paragraph = '<div data-identifyelement="123"><a data-toggle="tooltip">Click</a></div>'
        post :create, construct_params({ version: 'private', id: folder_meta.id }, title: title, description: paragraph, status: 2)
        assert_response 201
        match_json(private_api_solution_article_pattern(Solution::Article.last))
        assert_equal paragraph, (parse_response @response.body)['description']
      end

      def test_create_article_with_seo_data
        folder_meta = get_folder_meta
        title = Faker::Name.name
        seo_title = Faker::Name.name
        seo_desc = Faker::Lorem.paragraph
        paragraph = Faker::Lorem.paragraph
        post :create, construct_params({ version: 'private', id: folder_meta.id }, title: title, description: paragraph, status: 2, seo_data: { meta_title: seo_title, meta_description: seo_desc, meta_keywords: ['tag3', 'tag4', 'tag4'] })
        assert_response 201
        match_json(private_api_solution_article_pattern(Solution::Article.last))
      end

      def test_create_article_with_invalid_seo_data
        folder_meta = get_folder_meta
        post :create, construct_params({ version: 'private', id: folder_meta.id }, description: '<b>aaaa</b>', title: 'aaaa', status: 1, seo_data: { meta_title: 1, meta_description: 1, meta_keywords: 1 })
        assert_response 400
        match_json([bad_request_error_pattern('meta_title', :datatype_mismatch, code: :datatype_mismatch, expected_data_type: 'String', given_data_type: 'Integer', prepend_msg: :input_received),
                    bad_request_error_pattern('meta_description', :datatype_mismatch, code: :datatype_mismatch, expected_data_type: 'String', given_data_type: 'Integer', prepend_msg: :input_received),
                    bad_request_error_pattern('meta_keywords', :datatype_mismatch, code: :datatype_mismatch, expected_data_type: 'Array', given_data_type: 'Integer', prepend_msg: :input_received)])
      end

      def test_create_article_with_new_tags
        folder_meta = get_folder_meta
        title = Faker::Name.name
        paragraph = Faker::Lorem.paragraph
        tags = Faker::Lorem.words(3).uniq
        tags = tags.map do |tag|
          tag = "#{tag}#{Time.now.to_i}"
          assert_equal @account.tags.map(&:name).include?(tag), false
          tag
        end
        post :create, construct_params({ version: 'private', id: folder_meta.id }, title: title, description: paragraph, status: 2, tags: tags)
        assert_response 201
        match_json(private_api_solution_article_pattern(Solution::Article.last))
      end

      def test_create_article_with_existing_tags
        folder_meta = get_folder_meta
        title = Faker::Name.name
        paragraph = Faker::Lorem.paragraph
        tag = Faker::Lorem.word
        @account.tags.create(name: tag) unless @account.tags.map(&:name).include?(tag)
        post :create, construct_params({ version: 'private', id: folder_meta.id }, title: title, description: paragraph, status: 2, tags: [tag])
        assert_response 201
        match_json(private_api_solution_article_pattern(Solution::Article.last))
      end

      def test_create_article_with_new_tags_without_priviledge
        folder_meta = get_folder_meta
        title = Faker::Name.name
        paragraph = Faker::Lorem.paragraph
        tags = Faker::Lorem.words(3).uniq
        tags = tags.map do |tag|
          tag = "#{tag}_solutions_#{Time.now.to_i}"
          assert_equal @account.tags.map(&:name).include?(tag), false
          tag
        end
        User.current.reload
        remove_privilege(User.current, :create_tags)
        post :create, construct_params({ version: 'private', id: folder_meta.id }, title: title, description: paragraph, status: 1, tags: tags)
        assert_response 400
        add_privilege(User.current, :create_tags)
      end

      def test_create_article_with_existing_tags_without_priviledge
        folder_meta = get_folder_meta
        title = Faker::Name.name
        paragraph = Faker::Lorem.paragraph
        tag = Faker::Lorem.word
        @account.tags.create(name: tag) unless @account.tags.map(&:name).include?(tag)
        User.current.reload
        remove_privilege(User.current, :create_tags)
        post :create, construct_params({ version: 'private', id: folder_meta.id }, title: title, description: paragraph, status: 2, tags: [tag])
        assert_response 201
        match_json(private_api_solution_article_pattern(Solution::Article.last))
        article = Solution::Article.last
        assert_equal article.tags.count, 1
        add_privilege(User.current, :create_tags)
      end

      def test_create_article_without_params
        folder_meta = get_folder_meta
        post :create, construct_params({ version: 'private', id: folder_meta.id }, {})
        assert_response 400
        match_json([bad_request_error_pattern('title', 'Mandatory attribute missing', code: :missing_field),
                    bad_request_error_pattern('description', 'Mandatory attribute missing', code: :missing_field),
                    bad_request_error_pattern('status', :not_included, list: [1, 2].join(','), code: :missing_field)])
      end

      def test_create_article_with_invalid_params
        folder_meta = get_folder_meta
        post :create, construct_params({ version: 'private', id: folder_meta.id }, description: 1, title: 1, status: 'a', type: 'c', seo_data: 1, tags: 'a')
        assert_response 400
        match_json([bad_request_error_pattern('status', :not_included, list: [1, 2].join(','), code: :invalid_value),
                    bad_request_error_pattern('type', :not_included, list: [1, 2].join(','), code: :invalid_value),
                    bad_request_error_pattern('description', :datatype_mismatch, code: :datatype_mismatch, expected_data_type: 'String', given_data_type: 'Integer', prepend_msg: :input_received),
                    bad_request_error_pattern('seo_data', :datatype_mismatch, code: :datatype_mismatch, expected_data_type: 'key/value pair', given_data_type: 'Integer', prepend_msg: :input_received),
                    bad_request_error_pattern('tags', :datatype_mismatch, code: :datatype_mismatch, expected_data_type: 'Array', given_data_type: 'String', prepend_msg: :input_received),
                    bad_request_error_pattern('title', :datatype_mismatch, code: :datatype_mismatch, expected_data_type: 'String', given_data_type: 'Integer', prepend_msg: :input_received)])
      end

      def test_create_article_with_invalid_status
        folder_meta = get_folder_meta
        post :create, construct_params({ version: 'private', id: folder_meta.id }, description: '<b>aaaa</b>', title: 'Sample title', status: 3)
        assert_response 400
        match_json([bad_request_error_pattern('status', :not_included, list: [1, 2].join(','))])
      end

      def test_create_article_with_title_exceeding_max_length
        folder_meta = get_folder_meta
        post :create, construct_params({ version: 'private', id: folder_meta.id }, description: '<b>aaaa</b>', title: 'a' * 260, status: 1)
        assert_response 400
        match_json([bad_request_error_pattern('title', :too_long_too_short, current_count: 260, element_type: 'characters', max_count: 240, min_count: 3)])
      end

      def test_create_article_in_unavailable_folder
        post :create, construct_params({ version: 'private', id: 9999 }, description: '<b>aaaa</b>', title: 'aaaa', status: 1)
        assert_response :missing
      end

      def test_create_with_normal_attachments
        folder_meta = get_folder_meta
        attachment_ids = []
        2.times do
          attachment_ids << create_attachment(attachable_type: 'UserDraft', attachable_id: User.current.id).id
        end
        title = Faker::Name.name
        paragraph = Faker::Lorem.paragraph
        post :create, construct_params({ version: 'private', id: folder_meta.id }, title: title, description: paragraph, status: 2, attachments_list: attachment_ids)
        assert_response 201
        match_json(private_api_solution_article_pattern(Solution::Article.last))
        assert Solution::Article.last.attachments.count == 2
      end

      def test_create_with_invalid_attachment_ids
        folder_meta = get_folder_meta
        attachment_ids = []
        attachment_ids << create_attachment(attachable_type: 'UserDraft', attachable_id: @agent.id).id
        invalid_ids = [attachment_ids.last + 10, attachment_ids.last + 20]
        title = Faker::Name.name
        paragraph = Faker::Lorem.paragraph
        post :create, construct_params({ version: 'private', id: folder_meta.id }, title: title, description: paragraph, status: 1, attachments_list: invalid_ids)
        assert_response 400
        match_json([bad_request_error_pattern(:attachments_list, :invalid_attachments, invalid_ids: invalid_ids.join(','))])
      end

      def test_create_with_invalid_attachment_ids_format
        folder_meta = get_folder_meta
        title = Faker::Name.name
        paragraph = Faker::Lorem.paragraph
        post :create, construct_params({ version: 'private', id: folder_meta.id }, title: title, description: paragraph, status: 1, attachments_list: ['abc', 'def'])
        assert_response 400
        match_json([bad_request_error_pattern(:attachments_list, 'It should contain elements of type Positive Integer only', code: 'datatype_mismatch')])
      end

      def test_create_with_cloud_attachments
        folder_meta = get_folder_meta
        app = create_application('dropbox')
        cloud_file_params = [{ name: 'image.jpg', url: CLOUD_FILE_IMAGE_URL, application_id: app.application_id }]
        title = Faker::Name.name
        paragraph = Faker::Lorem.paragraph
        post :create, construct_params({ version: 'private', id: folder_meta.id }, title: title, description: paragraph, status: 2, cloud_file_attachments: cloud_file_params)
        assert_response 201
        match_json(private_api_solution_article_pattern(Solution::Article.last))
        assert Solution::Article.last.cloud_files.count == 1
      end

      def test_create_with_cloud_file_invalid_application
        folder_meta = get_folder_meta
        cloud_file_params = [{ name: 'image.jpg', url: CLOUD_FILE_IMAGE_URL, application_id: 99_999 }]
        title = Faker::Name.name
        paragraph = Faker::Lorem.paragraph
        post :create, construct_params({ version: 'private', id: folder_meta.id }, title: title, description: paragraph, status: 1, cloud_file_attachments: cloud_file_params)
        assert_response 400
        match_json([bad_request_error_pattern(:application_id, :invalid_list, list: [99_999])])
      end

      def test_create_with_missing_cloud_file_param_application_id
        folder_meta = get_folder_meta
        cloud_file_params = [{ name: 'image.jpg', link: CLOUD_FILE_IMAGE_URL }]
        title = Faker::Name.name
        paragraph = Faker::Lorem.paragraph
        post :create, construct_params({ version: 'private', id: folder_meta.id }, title: title, description: paragraph, status: 1, cloud_file_attachments: cloud_file_params)
        assert_response 400
      end

      def test_create_with_missing_cloud_file_param_name
        folder_meta = get_folder_meta
        cloud_file_params = [{ link: CLOUD_FILE_IMAGE_URL, provider: 'invalid' }]
        title = Faker::Name.name
        paragraph = Faker::Lorem.paragraph
        post :create, construct_params({ version: 'private', id: folder_meta.id }, title: title, description: paragraph, status: 1, cloud_file_attachments: cloud_file_params)
        assert_response 400
      end

      def test_create_with_missing_cloud_file_param_link
        folder_meta = get_folder_meta
        cloud_file_params = [{ name: 'image.jpg', provider: 'invalid' }]
        title = Faker::Name.name
        paragraph = Faker::Lorem.paragraph
        post :create, construct_params({ version: 'private', id: folder_meta.id }, title: title, description: paragraph, status: 1, cloud_file_attachments: cloud_file_params)
        assert_response 400
      end

      def test_create_a_draft_article_with_templates_used
        Account.any_instance.stubs(:solutions_templates_enabled?).returns(true)
        folder_meta = get_folder_meta
        title = Faker::Name.name
        paragraph = Faker::Lorem.paragraph
        sample_template1 = create_sample_template
        sample_template2 = create_sample_template
        post :create, construct_params({ version: 'private', id: folder_meta.id },
                                       title: title, description: paragraph,
                                       status: 1, templates_used: [sample_template1.id, sample_template2.id])
        assert_response 201
        article = Solution::Article.last
        stm = article.solution_template_mappings
        assert article.draft
        match_json(private_api_solution_article_pattern(article))
        assert_equal 2, stm.size
        assert_equal article.id, stm[0].article_id
        assert_equal sample_template1.id, stm[0].template_id
        assert_equal 1, stm[0].used_cnt
        assert_equal article.id, stm[1].article_id
        assert_equal sample_template2.id, stm[1].template_id
        assert_equal 1, stm[1].used_cnt
      ensure
        Account.any_instance.unstub(:solutions_templates_enabled?)
        sample_template2.destroy
        sample_template1.destroy
      end

      def test_create_a_draft_article_with_templates_used_with_nonexistent_template_ids
        Account.any_instance.stubs(:solutions_templates_enabled?).returns(true)
        folder_meta = get_folder_meta
        title = Faker::Name.name
        paragraph = Faker::Lorem.paragraph
        post :create, construct_params({ version: 'private', id: folder_meta.id },
                                       title: title, description: paragraph,
                                       status: 1, templates_used: [2311, 1989])
        assert_response 201
        article = Solution::Article.last
        assert_equal 0, article.solution_template_mappings.size
        assert article.draft
        match_json(private_api_solution_article_pattern(article))
      ensure
        Account.any_instance.unstub(:solutions_templates_enabled?)
      end

      def test_create_a_draft_article_with_templates_used_with_invalid_template_ids
        Account.any_instance.stubs(:solutions_templates_enabled?).returns(true)
        folder_meta = get_folder_meta
        title = Faker::Name.name
        paragraph = Faker::Lorem.paragraph
        post :create, construct_params({ version: 'private', id: folder_meta.id },
                                       title: title, description: paragraph,
                                       status: 1, templates_used: ['FZ1', 'FZ2'])
        assert_response 400
        expected = { description: 'Validation failed', errors: [{ field: 'templates_used', message: 'It should contain elements of type Positive Integer only', code: 'datatype_mismatch' }] }
        assert_equal(expected, JSON.parse(response.body, symbolize_names: true))
      ensure
        Account.any_instance.unstub(:solutions_templates_enabled?)
      end

      def test_update_article_with_templates_used
        Account.any_instance.stubs(:solutions_templates_enabled?).returns(true)
        article = get_article_without_draft
        sample_template1 = create_sample_template
        sample_template2 = create_sample_template
        put :update, construct_params({ version: 'private', id: article.parent_id }, status: 2,
                                                                                     templates_used: [sample_template1.id, sample_template2.id])
        assert_response 200
        match_json(private_api_solution_article_pattern(article.reload))
        stm = article.reload.solution_template_mappings
        assert_equal 2, stm.size
        assert_equal article.id, stm[0].article_id
        assert_equal sample_template1.id, stm[0].template_id
        assert_equal 1, stm[0].used_cnt
        assert_equal article.id, stm[1].article_id
        assert_equal sample_template2.id, stm[1].template_id
        assert_equal 1, stm[1].used_cnt
      ensure
        Account.any_instance.unstub(:solutions_templates_enabled?)
        sample_template2.destroy
        sample_template1.destroy
      end

      def test_update_article_with_templates_used_with_non_existent_templates
        Account.any_instance.stubs(:solutions_templates_enabled?).returns(true)
        article = get_article_without_draft
        put :update, construct_params({ version: 'private', id: article.parent_id }, status: 2,
                                                                                     templates_used: [23_111_989])
        assert_response 200
        match_json(private_api_solution_article_pattern(article.reload))
        assert_equal 0, article.solution_template_mappings.size
      ensure
        Account.any_instance.unstub(:solutions_templates_enabled?)
      end

      def test_update_article_as_draft
        sample_article = get_article_without_draft
        paragraph = Faker::Lorem.paragraph
        params_hash = { title: 'new draft title', description: paragraph, status: 1, agent_id: @agent.id }
        put :update, construct_params({ version: 'private', id: sample_article.parent_id }, params_hash)
        assert_response 200
        assert sample_article.reload.draft
        assert sample_article.reload.draft.reload.title == 'new draft title'
        assert sample_article.reload.draft.reload.status == 1
        match_json(private_api_solution_article_pattern(sample_article.reload))
      end

      def test_update_with_base64_description
        sample_article = get_article_without_draft
        base64_content = '<img src="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAUAAAAFCAYAAACNbyblAAAAHElEQVQI12P4//8/w38GIAXDIBKE0DHxgljNBAAO9TXL0Y4OHwAAAABJRU5ErkJggg==" alt="Red dot" />'

        params_hash = { description: base64_content, agent_id: @agent.id }
        put :update, construct_params({ version: 'private', id: sample_article.parent_id }, params_hash)

        assert_response 400
        match_json([bad_request_error_pattern('description', :article_description_base64_error, code: :article_base64_content_error)])
      end

      def test_update_article_and_publish
        sample_article = get_article_without_draft
        paragraph = Faker::Lorem.paragraph
        params_hash = { title: 'new publish title', description: paragraph, status: 2, agent_id: @agent.id }
        put :update, construct_params({ version: 'private', id: sample_article.parent_id }, params_hash)
        assert_response 200
        assert_nil sample_article.reload.draft
        assert sample_article.reload.title == 'new publish title'
        assert sample_article.reload.status == 2
        match_json(private_api_solution_article_pattern(sample_article.reload))
      end

      def test_update_and_publish_a_draft
        sample_article = get_article_with_draft
        paragraph = Faker::Lorem.paragraph
        put :update, construct_params({ version: 'private', id: sample_article.parent_id }, status: 2, title: 'publish draft title', agent_id: @agent.id)
        assert_response 200
        assert_nil sample_article.reload.draft
        assert sample_article.reload.title == 'publish draft title'
        match_json(private_api_solution_article_pattern(sample_article.reload))
      end

      def test_update_and_publish_without_draft
        sample_article = get_article_without_draft
        paragraph = Faker::Lorem.paragraph
        params_hash = { title: 'publish without draft title', description: paragraph, status: 2, agent_id: @agent.id }
        put :update, construct_params({ version: 'private', id: sample_article.parent_id }, params_hash)
        assert_response 200
        assert_nil sample_article.reload.draft
        assert sample_article.reload.title == 'publish without draft title'
        assert sample_article.reload.status == 2
        match_json(private_api_solution_article_pattern(sample_article.reload))
      end

      def test_update_draft_with_invalid_agent
        sample_article = get_article_with_draft
        paragraph = Faker::Lorem.paragraph
        params_hash = { agent_id: 9999, status: 1 }
        put :update, construct_params({ version: 'private', id: sample_article.parent_id }, params_hash)
        assert_response 400
        match_json([bad_request_error_pattern('agent_id', :invalid_agent_id)])
      end

      def test_update_article_with_invalid_agent
        sample_article = get_article_without_draft
        paragraph = Faker::Lorem.paragraph
        params_hash = { agent_id: 9999, status: 2 }
        put :update, construct_params({ version: 'private', id: sample_article.parent_id }, params_hash)
        assert_response 400
        match_json([bad_request_error_pattern('agent_id', :invalid_agent_id)])
      end

      def test_update_article_someone_editing
        sample_article = get_article_with_draft
        Solution::Draft.any_instance.stubs(:locked?).returns(true)
        paragraph = Faker::Lorem.paragraph
        put :update, construct_params({ version: 'private', id: sample_article.parent_id }, status: 1, description: paragraph)
        assert_response 400
        match_json(request_error_pattern_with_info(:draft_locked, {}, user_id: sample_article.draft.user_id))
        Solution::Draft.any_instance.unstub(:locked?)
      end

      def test_update_unavailable_article
        paragraph = Faker::Lorem.paragraph
        params_hash = { title: 'new title', description: paragraph, status: 2 }
        put :update, construct_params({ version: 'private', id: 9999 }, params_hash)
        assert_response :missing
      end

      def test_update_article_with_new_tags
        sample_article = get_article_without_draft
        initial_tag_count = sample_article.tags.count
        tags = Faker::Lorem.words(3).uniq
        tags = tags.map do |tag|
          tag = "#{tag}-#{Time.now.to_i}"
          assert_equal @account.tags.map(&:name).include?(tag), false
          tag
        end
        put :update, construct_params({ version: 'private', id: sample_article.parent_id }, status: 2, tags: tags)
        assert_response 200
        assert_equal sample_article.reload.tags.count, tags.count
        match_json(private_api_solution_article_pattern(sample_article.reload))
      end

      def test_update_article_with_new_tags_without_publish_solution_privilege
        sample_article = get_article_without_draft
        initial_tag_count = sample_article.tags.count
        tags = Faker::Lorem.words(3).uniq
        tags = tags.map do |tag|
          tag = "#{tag}-#{Time.now.to_i}"
          assert_equal @account.tags.map(&:name).include?(tag), false
          tag
        end
        User.any_instance.stubs(:privilege?).with(:publish_approved_solution).returns(true)
        User.any_instance.stubs(:privilege?).with(:create_and_edit_article).returns(true)
        User.any_instance.stubs(:privilege?).with(:admin_tasks).returns(true)
        User.any_instance.stubs(:privilege?).with(:publish_solution).returns(false)
        put :update, construct_params({ version: 'private', id: sample_article.parent_id }, status: 2, tags: tags)
        assert_response 403
        error_info_hash = { details: 'dont have permission to perfom on published article' }
        match_json(request_error_pattern_with_info(:published_article_privilege_error, error_info_hash, error_info_hash))
      ensure
        User.any_instance.unstub(:privilege?)
      end

      def test_update_article_with_existing_tags
        sample_article = get_article_without_draft
        initial_tag_count = sample_article.tags.count
        tags = [Faker::Lorem.word]
        @account.tags.create(name: tags.first) unless @account.tags.map(&:name).include?(tags.first)
        put :update, construct_params({ version: 'private', id: sample_article.parent_id }, status: 2, tags: tags)
        assert_response 200
        assert_equal sample_article.reload.tags.count, tags.count
        match_json(private_api_solution_article_pattern(sample_article.reload))
      end

      def test_update_article_with_existing_tags_without_priviledge
        sample_article = get_article
        initial_tag_count = sample_article.tags.count
        tag = Faker::Lorem.word
        @account.tags.create(name: tag) unless @account.tags.map(&:name).include?(tag)
        User.current.reload
        remove_privilege(User.current, :create_tags)
        put :update, construct_params({ version: 'private', id: sample_article.parent_id }, status: 1, tags: [tag])
        assert_response 200
        assert_equal sample_article.reload.tags.count, 1
        add_privilege(User.current, :create_tags)
      end

      def test_update_article_add_normal_attachment_publish
        sample_article = get_article_without_draft
        att_count = sample_article.attachments.count
        attachment_ids = []
        2.times do
          attachment_ids << create_attachment(attachable_type: 'UserDraft', attachable_id: User.current.id).id
        end
        put :update, construct_params({ version: 'private', id: sample_article.parent_id }, status: 2, attachments_list: attachment_ids)
        assert_response 200
        sample_article.reload
        match_json(private_api_solution_article_pattern(sample_article))
        assert sample_article.attachments.count == att_count + 2
      end

      def test_update_article_add_normal_attachment_draft
        sample_article = get_article_with_draft
        att_count = sample_article.draft.attachments.count
        attachment_ids = []
        2.times do
          attachment_ids << create_attachment(attachable_type: 'UserDraft', attachable_id: User.current.id).id
        end
        put :update, construct_params({ version: 'private', id: sample_article.parent_id }, status: 1, attachments_list: attachment_ids)
        assert_response 200
        sample_article.reload
        match_json(private_api_solution_article_pattern(sample_article))
        assert sample_article.draft.attachments.count == att_count + 2
      end

      def test_update_article_add_cloud_attachment_publish
        sample_article = get_article_without_draft
        att_count = sample_article.cloud_files.count
        app = create_application('dropbox')
        cloud_file_params = [{ name: 'image.jpg', url: CLOUD_FILE_IMAGE_URL, application_id: app.application_id }]
        put :update, construct_params({ version: 'private', id: sample_article.parent_id }, status: 2, cloud_file_attachments: cloud_file_params)
        assert_response 200
        sample_article.reload
        match_json(private_api_solution_article_pattern(sample_article))
        assert sample_article.cloud_files.count == att_count + 1
      end

      def test_update_article_add_cloud_attachment_draft
        sample_article = get_article_with_draft
        att_count = sample_article.draft.cloud_files.count
        app = create_application('dropbox')
        cloud_file_params = [{ name: 'image.jpg', url: CLOUD_FILE_IMAGE_URL, application_id: app.application_id }]
        put :update, construct_params({ version: 'private', id: sample_article.parent_id }, status: 1, cloud_file_attachments: cloud_file_params)
        assert_response 200
        sample_article.reload
        match_json(private_api_solution_article_pattern(sample_article))
        assert sample_article.draft.cloud_files.count == att_count + 1
      end

      def test_update_article_with_html_data_content
        sample_article = get_article_with_draft
        paragraph = '<div data-identifyelement="123"><a data-toggle="tooltip">Click</a></div>'
        put :update, construct_params({ version: 'private', id: sample_article.parent_id }, status: 2, title: 'publish draft title', description: paragraph, agent_id: @agent.id)
        assert_response 200
        match_json(private_api_solution_article_pattern(sample_article.reload))
        assert_equal paragraph, (parse_response @response.body)['description']
      end

      def test_delete_article
        sample_article = get_article
        delete :destroy, construct_params(version: 'private', id: sample_article.parent_id)
        assert_response 204
      end

      def test_delete_unavailable_article
        delete :destroy, construct_params(version: 'private', id: 9999)
        assert_response :missing
      end

      def test_delete_article_with_versioning
        Sidekiq::Testing.inline! do
          enable_article_versioning do
            article_meta = create_article(article_params)
            primary_article = article_meta.primary_article
            3.times do
              create_draft_version_for_article(primary_article)
            end
            no_of_versions = primary_article.reload.solution_article_versions.count
            Solution::ArticleVersionsWorker.expects(:perform_async).times(no_of_versions)
            delete :destroy, construct_params(version: 'private', id: article_meta.id)
            assert_response 204
            assert_equal @account.reload.solution_article_versions.where(article_id: primary_article.id).count, 0
          end
        end
      end

      def test_delete_article_someone_editing
        sample_article = get_article_with_draft
        Solution::Draft.any_instance.stubs(:locked?).returns(true)
        delete :destroy, construct_params(version: 'private', id: sample_article.parent_id)
        assert_response 400
        match_json(request_error_pattern_with_info(:draft_locked, {}, user_id: sample_article.draft.user_id))
        Solution::Draft.any_instance.unstub(:locked?)
      end

      def test_create_without_create_and_edit_article_privilege
        folder_meta = get_folder_meta
        title = Faker::Name.name
        paragraph = Faker::Lorem.paragraph
        User.any_instance.stubs(:privilege?).with(:create_and_edit_article).returns(false)
        User.any_instance.stubs(:privilege?).with(:publish_solution).returns(false)
        post :create, construct_params({ version: 'private', id: folder_meta.id }, title: title, description: paragraph, status: 1)
        assert_response 403
        match_json(request_error_pattern(:access_denied))
        User.any_instance.unstub(:privilege?)
      end

      def test_create_published_article_with_create_and_edit_article_privilege_and_without_publish_solution_privilege
        without_publish_solution_privilege do
          folder_meta = get_folder_meta
          title = Faker::Name.name
          paragraph = Faker::Lorem.paragraph
          post :create, construct_params({ version: 'private', id: folder_meta.id }, title: title, description: paragraph, status: 2)
          assert_response 403
          error_info_hash = { details: 'dont have permission to perfom on published article' }
          match_json(request_error_pattern_with_info(:published_article_privilege_error, error_info_hash, error_info_hash))
        end
      end

      def test_update_draft_state_article_without_publish_solution_privilege
        without_publish_solution_privilege do
          User.any_instance.stubs(:privilege?).with(:publish_approved_solution).returns(true)
          default_category = @account.solution_category_meta.where(is_default: true).first
          default_folder = default_category.solution_folder_meta.first
          article_meta = create_article(folder_meta_id: default_folder.id, status: '1')
          article = article_meta.solution_articles.first
          create_draft(article: article, keep_previous_author: true)
          paragraph = Faker::Lorem.paragraph
          params_hash = { title: 'new draft title', description: paragraph, status: 1, agent_id: @agent.id }
          put :update, construct_params({ version: 'private', id: article.parent_id }, params_hash)
          assert_response 200
          article.reload
          match_json(private_api_solution_article_pattern(article))
          assert_equal Solution::Article::STATUS_KEYS_BY_TOKEN[:draft], article.status
        end
      ensure
        User.any_instance.unstub(:privilege?)
      end

      def test_update_without_publish_solution_privilege
        without_publish_solution_privilege do
          User.any_instance.stubs(:privilege?).with(:publish_approved_solution).returns(true)
          sample_article = get_article_without_draft
          paragraph = Faker::Lorem.paragraph
          params_hash = { title: 'new draft title', description: paragraph, status: 2, agent_id: @agent.id }
          put :update, construct_params({ version: 'private', id: sample_article.parent_id }, params_hash)
          assert_response 403
          error_info_hash = { details: 'dont have permission to perfom on published article' }
          match_json(request_error_pattern_with_info(:published_article_privilege_error, error_info_hash, error_info_hash))
        end
      ensure
        User.any_instance.unstub(:privilege?)
      end

      def test_show_without_view_solution_privilege
        sample_article = get_article_without_draft
        sample_article.reload
        User.any_instance.stubs(:privilege?).with(:view_solutions).returns(false)
        get :show, controller_params(version: 'private', id: sample_article.parent_id)
        assert_response 403
        match_json(request_error_pattern(:access_denied))
        User.any_instance.unstub(:privilege?)
      end

      def test_delete_article_without_delete_solution_privilege
        sample_article = get_article
        User.any_instance.stubs(:privilege?).with(:delete_solution).returns(false)
        delete :destroy, construct_params(version: 'private', id: sample_article.parent_id)
        assert_response 403
        match_json(request_error_pattern(:access_denied))
        User.any_instance.unstub(:privilege?)
      end

      def test_bulk_update_approval_without_approve_article_privilege
        Account.any_instance.stubs(:adv_article_bulk_actions_enabled?).returns(true)
        Account.any_instance.stubs(:article_approval_workflow_enabled?).returns(true)
        folder = @account.solution_folder_meta.where(is_default: false).first
        populate_articles(folder)
        articles = folder.solution_article_meta.pluck(:id)
        User.current.reload
        remove_privilege(User.current, :approve_article)
        put :bulk_update, construct_params({ version: 'private' }, ids: articles, properties: { approval_status: Helpdesk::ApprovalConstants::STATUS_KEYS_BY_TOKEN[:approved] })
        assert_response 400
      ensure
        Account.any_instance.unstub(:adv_article_bulk_actions_enabled?)
        Account.any_instance.unstub(:article_approval_workflow_enabled?)
      end

      def test_bulk_update_approval_with_approve_article_privilege
        Account.any_instance.stubs(:adv_article_bulk_actions_enabled?).returns(true)
        Account.any_instance.stubs(:article_approval_workflow_enabled?).returns(true)
        folder = @account.solution_folder_meta.where(is_default: false).first
        populate_articles(folder)
        articles = folder.solution_article_meta.pluck(:id)
        User.current.reload
        add_privilege(User.current, :approve_article)
        put :bulk_update, construct_params({ version: 'private' }, ids: articles, properties: { approval_status: Helpdesk::ApprovalConstants::STATUS_KEYS_BY_TOKEN[:approved] })
        assert_response 204
      ensure
        Account.any_instance.unstub(:adv_article_bulk_actions_enabled?)
        Account.any_instance.unstub(:article_approval_workflow_enabled?)
        remove_privilege(User.current, :approve_article)
      end

      def test_bulk_update_approval_with_invalid_approval_status
        Account.any_instance.stubs(:adv_article_bulk_actions_enabled?).returns(true)
        Account.any_instance.stubs(:article_approval_workflow_enabled?).returns(true)
        folder = @account.solution_folder_meta.where(is_default: false).first
        populate_articles(folder)
        articles = folder.solution_article_meta.pluck(:id)
        User.current.reload
        add_privilege(User.current, :approve_article)
        put :bulk_update, construct_params({ version: 'private' }, ids: articles, properties: { approval_status: 0 })
        assert_response 400
      ensure
        Account.any_instance.unstub(:adv_article_bulk_actions_enabled?)
        Account.any_instance.unstub(:article_approval_workflow_enabled?)
        remove_privilege(User.current, :approve_article)
      end

      def test_bulk_update_tags_without_feature
        Account.any_instance.stubs(:adv_article_bulk_actions_enabled?).returns(false)
        article = @account.solution_articles.where(language_id: 6).last
        tags = [Faker::Name.name, Faker::Name.name]
        put :bulk_update, construct_params({ version: 'private' }, ids: [article.parent_id], properties: { tags: tags })
        assert_response 403
        match_json(validation_error_pattern(bad_request_error_pattern('properties[:tags]', :require_feature, feature: :adv_article_bulk_actions, code: :access_denied)))
      ensure
        Account.any_instance.unstub(:adv_article_bulk_actions_enabled?)
      end

      def test_bulk_update_tags
        article = @account.solution_articles.where(language_id: 6).last
        tags = [Faker::Name.name, Faker::Name.name]
        put :bulk_update, construct_params({ version: 'private' }, ids: [article.parent_id], properties: { tags: tags })
        assert_response 204
        article.reload
        assert (tags - article.reload.tags.map(&:name)).empty?
      end

      def test_bulk_update_tags_without_tags_privilege
        with_publish_solution_privilege do
          User.any_instance.stubs(:privilege?).with(:create_tags).returns(false)
          article = @account.solution_articles.where(language_id: 6).last
          tags = [Faker::Name.name, Faker::Name.name]
          put :bulk_update, construct_params({ version: 'private' }, ids: [article.parent_id], properties: { tags: tags })
          assert_response 400
        end
      ensure
        User.any_instance.unstub(:privilege?)
      end

      def test_bulk_update_old_tags_without_tags_privilege
        with_publish_solution_privilege do
          User.any_instance.stubs(:privilege?).with(:create_tags).returns(false)
          article = @account.solution_articles.where(language_id: 6).last
          tag = Helpdesk::Tag.where(name: Faker::Name.name, account_id: @account.id).first_or_create
          put :bulk_update, construct_params({ version: 'private' }, ids: [article.parent_id], properties: { tags: [tag.name] })
          assert_response 204
          assert ([tag.name] - article.reload.tags.map(&:name)).empty?
        end
      end

      def test_bulk_update_author_without_feature
        Account.any_instance.stubs(:adv_article_bulk_actions_enabled?).returns(false)
        folder = @account.solution_folder_meta.where(is_default: false).first
        populate_articles(folder)
        articles = folder.solution_article_meta.pluck(:id)
        agent_id = add_test_agent.id
        User.any_instance.stubs(:privilege?).with(:create_and_edit_article).returns(true)
        User.any_instance.stubs(:privilege?).with(:publish_solution).returns(true)
        User.any_instance.stubs(:privilege?).with(:admin_tasks).returns(true)
        put :bulk_update, construct_params({ version: 'private' }, ids: articles, properties: { agent_id: agent_id })
        assert_response 403
        match_json(validation_error_pattern(bad_request_error_pattern('properties[:agent_id]', :require_feature, feature: :adv_article_bulk_actions, code: :access_denied)))
      ensure
        Account.any_instance.unstub(:adv_article_bulk_actions_enabled?)
      end

      def test_bulk_update_author
        with_publish_solution_privilege do
          folder = @account.solution_folder_meta.where(is_default: false).first
          populate_articles(folder)
          articles = folder.solution_article_meta.pluck(:id)
          agent_id = add_test_agent.id
          put :bulk_update, construct_params({ version: 'private' }, ids: articles, properties: { agent_id: agent_id })
          assert_response 204
          assert folder.reload.solution_article_meta.all? { |meta| meta.solution_articles.where(language_id: @account.language_object.id).first.user_id == agent_id }
        end
      end

      def test_bulk_update_author_without_publish_solution
        folder = @account.solution_folder_meta.where(is_default: false).first
        populate_articles(folder)
        articles = folder.solution_article_meta.pluck(:id)
        agent_id = @account.agents.first.id
        User.any_instance.stubs(:privilege?).with(:create_and_edit_article).returns(true)
        User.any_instance.stubs(:privilege?).with(:admin_tasks).returns(true)
        User.any_instance.stubs(:privilege?).with(:publish_solution).returns(false)
        put :bulk_update, construct_params({ version: 'private' }, ids: articles, properties: { agent_id: agent_id })
        assert_response 400
      ensure
        User.any_instance.unstub(:privilege?)
      end

      def test_bulk_update_author_without_admin_tasks
        folder = @account.solution_folder_meta.where(is_default: false).first
        populate_articles(folder)
        articles = folder.solution_article_meta.pluck(:id)
        agent_id = @account.agents.first.id
        User.any_instance.stubs(:privilege?).with(:create_and_edit_article).returns(true)
        User.any_instance.stubs(:privilege?).with(:publish_solution).returns(true)
        User.any_instance.stubs(:privilege?).with(:admin_tasks).returns(false)
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
        put :bulk_update, construct_params({ version: 'private' }, ids: articles, properties: { agent_id: 10_192_910 })
        assert_response 400
        match_json(bulk_validation_error_pattern(:agent_id, :invalid_agent_id))
      end

      def test_bulk_update_invaild_author_datatype
        folder = @account.solution_folder_meta.where(is_default: false).first
        populate_articles(folder)
        articles = folder.solution_article_meta.pluck(:id)
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
        put :bulk_update, construct_params({ version: 'private' }, ids: articles)
        assert_response 400
        match_json(validation_error_pattern(bad_request_error_pattern(:properties, :select_a_field, code: :missing_field)))
      end

      def test_bulk_update_articles_exception
        folder = @account.solution_folder_meta.where(is_default: false).first
        populate_articles(folder)
        articles = folder.solution_article_meta.pluck(:id)
        Solution::ArticleMeta.any_instance.stubs(:save!).raises(StandardError)
        put :bulk_update, construct_params({ version: 'private' }, ids: articles, properties: { folder_id: folder.id })
        assert_response 202
      ensure
        Solution::ArticleMeta.any_instance.unstub(:save!)
      end

      def test_bulk_update_author_with_language_param
        folder = @account.solution_folder_meta.where(is_default: false).first
        populate_articles(folder)
        articles = folder.solution_article_meta.pluck(:id)
        agent_id = add_test_agent.id
        User.any_instance.stubs(:privilege?).with(:create_and_edit_article).returns(true)
        User.any_instance.stubs(:privilege?).with(:publish_solution).returns(true)
        User.any_instance.stubs(:privilege?).with(:admin_tasks).returns(true)
        put :bulk_update, construct_params({ version: 'private', language: @account.language }, ids: articles, properties: { agent_id: agent_id })
        assert_response 204
        assert folder.reload.solution_article_meta.all? { |meta| meta.solution_articles.where(language_id: @account.language_object.id).first.user_id == agent_id }
      ensure
        User.any_instance.unstub(:privilege?)
      end

      def test_bulk_update_author_for_secondary_language
        article_meta = get_article_meta_with_translation
        articles = [article_meta.id]
        agent_id = add_test_agent.id
        article_translations = article_meta.children.pluck(:language_id)
        language = Language.find((article_translations - [Language.find_by_code(@account.language).code]).sample)
        User.any_instance.stubs(:privilege?).with(:create_and_edit_article).returns(true)
        User.any_instance.stubs(:privilege?).with(:publish_solution).returns(true)
        User.any_instance.stubs(:privilege?).with(:admin_tasks).returns(true)
        put :bulk_update, construct_params({ version: 'private', language: language.code }, ids: articles, properties: { agent_id: agent_id })
        assert_response 204
        article_meta.children.where(language_id: language.id).first.user_id = agent_id
      ensure
        User.any_instance.unstub(:privilege?)
      end

      def test_bulk_update_author_for_non_supported_language
        with_publish_solution_privilege do
          User.any_instance.stubs(:privilege?).with(:publish_solution).returns(true)
          User.any_instance.stubs(:privilege?).with(:publish_solution).returns(true)
          User.any_instance.stubs(:privilege?).with(:admin_tasks).returns(true)
          non_supported_language = get_valid_not_supported_language
          put :bulk_update, construct_params({ version: 'private', language: non_supported_language }, ids: [1], properties: { agent_id: 1 })
          assert_response 404
          match_json(request_error_pattern(:language_not_allowed, code: non_supported_language, list: (@account.supported_languages + [@account.language]).sort.join(', ')))
        end
      ensure
        User.any_instance.unstub(:privilege?)
      end

      def test_bulk_update_with_language_without_multilingual_feature
        with_publish_solution_privilege do
          Account.any_instance.stubs(:multilingual?).returns(false)
          put :bulk_update, construct_params({ version: 'private', language: get_valid_not_supported_language }, ids: [1], properties: { agent_id: 1 })
          assert_response 404
          match_json(request_error_pattern(:require_feature, feature: 'MultilingualFeature'))
        end
      ensure
        Account.any_instance.unstub(:multilingual?)
      end

      def test_update_article_unpublish_with_incorrect_credentials
        @controller.stubs(:api_current_user).raises(ActiveSupport::MessageVerifier::InvalidSignature)
        put :update, construct_params(version: 'private', id: 1, status: Solution::Article::STATUS_KEYS_BY_TOKEN[:draft])
        assert_response 401
        assert_equal request_error_pattern(:credentials_required).to_json, response.body
      ensure
        @controller.unstub(:api_current_user)
      end

      def test_update_article_unpublish_without_create_and_edit_article_privilege
        User.any_instance.stubs(:privilege?).with(:create_and_edit_article).returns(false)
        User.any_instance.stubs(:privilege?).with(:publish_solution).returns(false)
        put :update, construct_params(version: 'private', id: 1, status: Solution::Article::STATUS_KEYS_BY_TOKEN[:draft])
        assert_response 403
        match_json(request_error_pattern(:access_denied))
      ensure
        User.any_instance.unstub(:privilege?)
      end

      def test_update_article_unpublish_without_access
        user = add_new_user(@account, active: true)
        login_as(user)
        put :update, construct_params(version: 'private', id: 1, status: Solution::Article::STATUS_KEYS_BY_TOKEN[:draft])
        assert_response 403
        match_json(request_error_pattern(:access_denied))
        @admin = get_admin
        login_as(@admin)
      end

      def test_update_article_unpublish_for_non_existant_article
        put :update, construct_params(version: 'private', id: 0, status: Solution::Article::STATUS_KEYS_BY_TOKEN[:draft])
        assert_response 404
      end

      def test_update_article_unpublish_with_invalid_field
        put :update, construct_params(version: 'private', id: 1, test: 'test', status: Solution::Article::STATUS_KEYS_BY_TOKEN[:draft])
        assert_response 400
        match_json([bad_request_error_pattern('test', :invalid_field)])
      end

      def test_update_article_unpublish
        article = create_article(article_params)
        put :update, construct_params(version: 'private', id: article.id, status: Solution::Article::STATUS_KEYS_BY_TOKEN[:draft])
        assert_response 200
        assert_equal Solution::Article::STATUS_KEYS_BY_TOKEN[:draft], article.reload.primary_article.status
      end

      def test_update_article_unpublish_with_language_without_multilingual_feature
        Account.any_instance.stubs(:multilingual?).returns(false)
        put :update, construct_params(version: 'private', id: 0, status: Solution::Article::STATUS_KEYS_BY_TOKEN[:draft], language: @account.supported_languages.last)
        match_json(request_error_pattern(:require_feature, feature: 'MultilingualFeature'))
        assert_response 404
      ensure
        Account.any_instance.unstub(:multilingual?)
      end

      def test_update_article_unpublish_with_invalid_language
        article = create_article(article_params)
        put :update, construct_params(version: 'private', id: article.id, status: Solution::Article::STATUS_KEYS_BY_TOKEN[:draft], language: 'test')
        assert_response 404
        match_json(request_error_pattern(:language_not_allowed, code: 'test', list: (@account.supported_languages + [@account.language]).sort.join(', ')))
      end

      def test_update_article_unpublish_with_primary_language
        article = create_article(article_params)
        put :update, construct_params(version: 'private', id: article.id, status: Solution::Article::STATUS_KEYS_BY_TOKEN[:draft], language: @account.language)
        assert_response 200
        assert_equal Solution::Article::STATUS_KEYS_BY_TOKEN[:draft], article.reload.primary_article.status
      end

      def test_update_article_unpublish_with_supported_language
        languages = @account.supported_languages + ['primary']
        language = @account.supported_languages.first
        article = create_article(article_params(lang_codes: languages))
        put :update, construct_params(version: 'private', id: article.id, status: Solution::Article::STATUS_KEYS_BY_TOKEN[:draft], language: language)
        assert_response 200
        assert_equal Solution::Article::STATUS_KEYS_BY_TOKEN[:draft], article.reload.safe_send("#{language}_article").status
      end

      def test_reset_ratings_with_incorrect_credentials
        @controller.stubs(:api_current_user).raises(ActiveSupport::MessageVerifier::InvalidSignature)
        put :reset_ratings, construct_params(version: 'private', id: 1)
        assert_response 401
        assert_equal request_error_pattern(:credentials_required).to_json, response.body
      ensure
        @controller.unstub(:api_current_user)
      end

      def test_reset_ratings_without_delete_solution_privilege
        User.any_instance.stubs(:privilege?).with(:delete_solution).returns(false)
        put :reset_ratings, construct_params(version: 'private', id: 1)
        assert_response 403
        match_json(request_error_pattern(:access_denied))
      ensure
        User.any_instance.unstub(:privilege?)
      end

      def test_reset_ratings_without_access
        user = add_new_user(@account, active: true)
        login_as(user)
        put :reset_ratings, construct_params(version: 'private', id: 1)
        assert_response 403
        match_json(request_error_pattern(:access_denied))
        @admin = get_admin
        login_as(@admin)
      end

      def test_reset_ratings_for_non_existant_article
        put :reset_ratings, construct_params(version: 'private', id: 0)
        assert_response 404
      end

      def test_reset_ratings_with_invalid_field
        put :reset_ratings, construct_params(version: 'private', id: 1, test: 'test')
        assert_response 400
        match_json([bad_request_error_pattern('test', :invalid_field)])
      end

      def test_reset_ratings_for_an_article_with_no_ratings
        article = create_article(article_params)
        put :reset_ratings, construct_params(version: 'private', id: article.id)
        assert_response 400
        match_json([bad_request_error_pattern('id', :no_ratings)])
      end

      def test_reset_ratings
        article = create_article(article_params)
        article.primary_article.thumbs_up!
        article.primary_article.thumbs_down!
        put :reset_ratings, construct_params(version: 'private', id: article.id)
        assert_response 204
        article.reload
        assert_equal 0, article.primary_article.thumbs_up
        assert_equal 0, article.primary_article.thumbs_down
      end

      def test_reset_ratings_with_language_without_multilingual_feature_with_default_language
        Account.any_instance.stubs(:multilingual?).returns(false)
        article = create_article(article_params)
        article.primary_article.thumbs_up!
        article.primary_article.thumbs_down!
        put :reset_ratings, construct_params(version: 'private', id: article.id, language: @account.language)
        assert_response 204
        article.reload
        assert_equal 0, article.primary_article.thumbs_up
        assert_equal 0, article.primary_article.thumbs_down
      ensure
        Account.any_instance.unstub(:multilingual?)
      end

      def test_reset_ratings_with_language_without_multilingual_feature
        Account.any_instance.stubs(:multilingual?).returns(false)
        put :reset_ratings, construct_params(version: 'private', id: 0, language: @account.supported_languages.last)
        match_json(request_error_pattern(:require_feature, feature: 'MultilingualFeature'))
        assert_response 404
      ensure
        Account.any_instance.unstub(:multilingual?)
      end

      def test_reset_ratings_with_invalid_language
        put :reset_ratings, construct_params(version: 'private', id: 0, language: 'test')
        assert_response 404
        match_json(request_error_pattern(:language_not_allowed, code: 'test', list: (@account.supported_languages + [@account.language]).sort.join(', ')))
      end

      def test_reset_ratings_with_primary_language
        article = create_article(article_params)
        article.primary_article.thumbs_up!
        article.primary_article.thumbs_down!
        put :reset_ratings, construct_params(version: 'private', id: article.id, language: @account.language)
        assert_response 204
        article.reload
        assert_equal 0, article.primary_article.thumbs_up
        assert_equal 0, article.primary_article.thumbs_down
      end

      def test_reset_ratings_with_supported_language
        languages = @account.supported_languages + ['primary']
        language = @account.supported_languages.first
        article_meta = create_article(article_params(lang_codes: languages))
        article = article_meta.safe_send("#{language}_article")
        article.thumbs_up!
        article.thumbs_down!
        put :reset_ratings, construct_params(version: 'private', id: article_meta.id, language: language)
        assert_response 204
        article.reload
        assert_equal 0, article.thumbs_up
        assert_equal 0, article.thumbs_down
      end

      def test_votes_with_incorrect_credentials
        @controller.stubs(:api_current_user).raises(ActiveSupport::MessageVerifier::InvalidSignature)
        get :votes, controller_params(version: 'private', id: 1)
        assert_response 401
        assert_equal request_error_pattern(:credentials_required).to_json, response.body
      ensure
        @controller.unstub(:api_current_user)
      end

      def test_votes_without_view_solutions_privilege
        User.any_instance.stubs(:privilege?).with(:view_solutions).returns(false)
        get :votes, controller_params(version: 'private', id: 1)
        assert_response 403
        match_json(request_error_pattern(:access_denied))
      ensure
        User.any_instance.unstub(:privilege?)
      end

      def test_votes_without_access
        user = add_new_user(@account, active: true)
        login_as(user)
        get :votes, controller_params(version: 'private', id: 1)
        assert_response 403
        match_json(request_error_pattern(:access_denied))
        @admin = get_admin
        login_as(@admin)
      end

      def test_votes_for_non_existant_article
        get :votes, controller_params(version: 'private', id: 0)
        assert_response 404
      end

      def test_votes
        article = create_article(article_params)
        article.primary_article.thumbs_up!
        article.primary_article.thumbs_down!
        article.reload
        vote = article.primary_article.votes.build(vote: 1, user_id: add_new_user(@account, active: true).id)
        vote.save
        article.primary_article.thumbs_up!
        get :votes, controller_params(version: 'private', id: article.id)
        assert_response 200
        article.reload
        assert_equal votes_pattern(article.primary_article), response.body
      end

      def test_votes_with_language_without_multilingual_feature_with_default_language
        Account.any_instance.stubs(:multilingual?).returns(false)
        article = create_article(article_params)
        article.primary_article.thumbs_up!
        article.primary_article.thumbs_down!
        get :votes, controller_params(version: 'private', id: article.id, language: @account.language)
        assert_response 200
        article.reload
        assert_equal votes_pattern(article.primary_article), response.body
      ensure
        Account.any_instance.unstub(:multilingual?)
      end

      def test_votes_with_language_without_multilingual_feature
        Account.any_instance.stubs(:multilingual?).returns(false)
        get :votes, controller_params(version: 'private', id: 0, language: @account.supported_languages.last)
        match_json(request_error_pattern(:require_feature, feature: 'MultilingualFeature'))
        assert_response 404
      ensure
        Account.any_instance.unstub(:multilingual?)
      end

      def test_votes_with_invalid_language
        get :votes, controller_params(version: 'private', id: 0, language: 'test')
        assert_response 404
        match_json(request_error_pattern(:language_not_allowed, code: 'test', list: (@account.supported_languages + [@account.language]).sort.join(', ')))
      end

      def test_votes_with_primary_language
        article = create_article(article_params)
        article.primary_article.thumbs_up!
        article.primary_article.thumbs_down!
        get :votes, controller_params(version: 'private', id: article.id, language: @account.language)
        assert_response 200
        article.reload
        assert_equal votes_pattern(article.primary_article), response.body
      end

      def test_votes_with_supported_language
        languages = @account.supported_languages + ['primary']
        language = @account.supported_languages.first
        article_meta = create_article(article_params(lang_codes: languages))
        article = article_meta.safe_send("#{language}_article")
        article.thumbs_up!
        article.thumbs_down!
        get :votes, controller_params(version: 'private', id: article_meta.id, language: language)
        assert_response 200
        assert_equal votes_pattern(article.reload), response.body
      end

      def test_article_filters_without_feature
        Account.any_instance.stubs(:article_filters_enabled?).returns(false)
        get :filter, controller_params(version: 'private', portal_id: @portal_id, folder: 1)
        assert_response 403
        match_json(request_error_pattern(:require_feature, feature: :article_filters))
      ensure
        Account.any_instance.unstub(:article_filters_enabled?)
      end

      def test_article_filters_without_feature_with_default_filter_field
        Account.any_instance.stubs(:article_filters_enabled?).returns(false)
        get :filter, controller_params(version: 'private', portal_id: @portal_id)
        assert_response 200
      ensure
        Account.any_instance.unstub(:article_filters_enabled?)
      end

      def test_article_filters_without_mandatory_fields
        get :filter, controller_params(version: 'private', author: '1')
        assert_response 400
        match_json([bad_request_error_pattern('portal_id', 'Mandatory attribute missing', code: :missing_field)])
      end

      def test_filter_without_view_solutions_privilege
        User.any_instance.stubs(:privilege?).with(:view_solutions).returns(false)
        get :filter, controller_params(version: 'private')
        assert_response 403
        match_json(request_error_pattern(:access_denied))
      ensure
        User.any_instance.unstub(:privilege?)
      end

      def test_filter_without_access
        user = add_new_user(@account, active: true)
        login_as(user)
        get :filter, controller_params(version: 'private')
        assert_response 403
        match_json(request_error_pattern(:access_denied))
        @admin = get_admin
        login_as(@admin)
      end

      def test_article_filters_with_invalid_fields
        get :filter, controller_params(version: 'private', portal_id: @portal_id, by_status: '1')
        assert_response 400
        match_json([bad_request_error_pattern('by_status', :invalid_field)])
      end

      def test_article_filters
        get :filter, controller_params(version: 'private', portal_id: @portal_id, language: 'en')
        articles = get_portal_articles(@portal_id, [6]).first(30)
        assert_response 200
        pattern = articles.map { |article| private_api_solution_article_pattern(article, action: :filter) }
        match_json(pattern)
      end

      def test_article_filters_with_deleted_agent_drafts
        author_id = @account.agents.first.id
        article_meta = create_article(user_id: 999_999, folder_meta_id: @@folder_meta.id, status: '1')
        article = article_meta.solution_articles.first
        tag = 'tagnamefordeletedagent' + Random.rand(99_999_999).to_s
        create_tag_use(@account, taggable_type: 'Solution::Article', taggable_id: article.id, name: tag,
                                 allow_skip: true)
        get :filter, controller_params({ version: 'private', portal_id: @portal_id.to_s, status: '1',
                                         author: -1.to_s, category: [@@category_meta.id.to_s], folder: [@@folder_meta.id.to_s],
                                         created_at: { start: '20190101', end: '21190101' }, last_modified: { start: '20190101', end: '21190101' }, tags: [tag] }, false)
        article.reload
        assert_response 200
        pattern = private_api_solution_article_pattern(article, action: :filter)
        match_json([pattern])
      end

      def test_article_filters_with_deleted_agent_published_article
        article_meta = create_article(user_id: 999_998, folder_meta_id: @@folder_meta.id)
        article = article_meta.solution_articles.first
        tag = 'tagfordeletedagent' + Random.rand(99_999_999).to_s
        create_tag_use(@account, taggable_type: 'Solution::Article', taggable_id: article.id, name: tag,
                                 allow_skip: true)
        get :filter, controller_params({ version: 'private', portal_id: @portal_id.to_s,
                                         author: -1.to_s, category: [@@category_meta.id.to_s], folder: [@@folder_meta.id.to_s],
                                         created_at: { start: '20190101', end: '21190101' }, last_modified: { start: '20190101', end: '21190101' }, tags: [tag] }, false)
        article.reload
        assert_response 200
        pattern = private_api_solution_article_pattern(article, action: :filter)
        match_json([pattern])
      end

      def test_article_filters_with_user_deleted_agent_for_published_articles
        user = add_new_user(@account, active: true, deleted: true)
        article_meta = create_article(user_id: user.id, folder_meta_id: @@folder_meta.id)
        article = article_meta.solution_articles.first
        tag = 'tagfordeletedagentname' + Random.rand(99_999_999).to_s
        create_tag_use(@account, taggable_type: 'Solution::Article', taggable_id: article.id, name: tag,
                                 allow_skip: true)
        get :filter, controller_params({ version: 'private', portal_id: @portal_id.to_s,
                                         author: -1.to_s, category: [@@category_meta.id.to_s], folder: [@@folder_meta.id.to_s],
                                         created_at: { start: '20190101', end: '21190101' }, last_modified: { start: '20190101', end: '21190101' }, tags: [tag] }, false)
        article.reload
        assert_response 200
        pattern = private_api_solution_article_pattern(article, action: :filter)
        match_json([pattern])
      end

      def test_article_filters_with_user_deleted_agent_for_draft_articles
        user = add_new_user(@account, active: true, deleted: true)
        article_meta = create_article(user_id: user.id, folder_meta_id: @@folder_meta.id, status: '1')
        article = article_meta.solution_articles.first
        tag = 'tagfordeletedagentname' + Random.rand(99_999_999).to_s
        create_tag_use(@account, taggable_type: 'Solution::Article', taggable_id: article.id, name: tag,
                                 allow_skip: true)
        get :filter, controller_params({ version: 'private', portal_id: @portal_id.to_s,
                                         author: -1.to_s, category: [@@category_meta.id.to_s], folder: [@@folder_meta.id.to_s], status: '1',
                                         created_at: { start: '20190101', end: '21190101' }, last_modified: { start: '20190101', end: '21190101' }, tags: [tag] }, false)
        article.reload
        assert_response 200
        pattern = private_api_solution_article_pattern(article, action: :filter)
        match_json([pattern])
      end

      def test_article_filters_with_invalid_language
        get :filter, controller_params(version: 'private', portal_id: @portal_id, language: 'sample')
        assert_response 404
        match_json(request_error_pattern(:language_not_allowed, code: 'sample', list: (@account.supported_languages + [@account.language]).sort.join(', ')))
      end

      def test_article_filters_all_attributes
        author_id = @account.agents.first.id
        article_meta = create_article(user_id: author_id, folder_meta_id: @@folder_meta.id)
        article = article_meta.solution_articles.first
        tag = Faker::Lorem.characters(7)
        create_tag_use(@account, taggable_type: 'Solution::Article', taggable_id: article.id, name: tag,
                                 allow_skip: true)
        get :filter, controller_params({ version: 'private', portal_id: @portal_id.to_s, status: SolutionConstants::STATUS_FILTER_BY_TOKEN[:published],
                                         author: author_id.to_s, category: [@@category_meta.id.to_s], folder: [@@folder_meta.id.to_s],
                                         created_at: { start: '20190101', end: '21190101' }, last_modified: { start: '20190101', end: '21190101' }, tags: [tag] }, false)
        article.reload
        assert_response 200
        pattern = private_api_solution_article_pattern(article, action: :filter)
        match_json([pattern])
      end

      def test_article_filters_with_created_at_option_today
        author_id = @account.agents.first.id
        article_meta = create_article(user_id: author_id, folder_meta_id: @@folder_meta.id)
        article = article_meta.solution_articles.first
        tag = Faker::Lorem.characters(7)
        create_tag_use(@account, taggable_type: 'Solution::Article', taggable_id: article.id, name: tag,
                                 allow_skip: true)
        get :filter, controller_params({ version: 'private', portal_id: @portal_id.to_s, status: '2',
                                         author: author_id.to_s, category: [@@category_meta.id.to_s], folder: [@@folder_meta.id.to_s],
                                         created_at: 'today', tags: [tag] }, false)
        article.reload
        assert_response 200
        pattern = private_api_solution_article_pattern(article, action: :filter)
        match_json([pattern])
      end

      def test_article_filters_with_created_at_option_30days
        author_id = @account.agents.first.id
        article_meta = create_article(user_id: author_id, folder_meta_id: @@folder_meta.id)
        article = article_meta.solution_articles.first
        tag = Faker::Lorem.characters(7)
        create_tag_use(@account, taggable_type: 'Solution::Article', taggable_id: article.id, name: tag,
                                 allow_skip: true)
        get :filter, controller_params({ version: 'private', portal_id: @portal_id.to_s, status: '2',
                                         author: author_id.to_s, category: [@@category_meta.id.to_s], folder: [@@folder_meta.id.to_s],
                                         created_at: '30days', tags: [tag] }, false)
        article.reload
        assert_response 200
        pattern = private_api_solution_article_pattern(article, action: :filter)
        match_json([pattern])
      end

      def test_article_filters_with_created_at_option_this_week
        author_id = @account.agents.first.id
        article_meta = create_article(user_id: author_id, folder_meta_id: @@folder_meta.id)
        article = article_meta.solution_articles.first
        tag = Faker::Lorem.characters(7)
        create_tag_use(@account, taggable_type: 'Solution::Article', taggable_id: article.id, name: tag,
                                 allow_skip: true)
        get :filter, controller_params({ version: 'private', portal_id: @portal_id.to_s, status: '2',
                                         author: author_id.to_s, category: [@@category_meta.id.to_s], folder: [@@folder_meta.id.to_s],
                                         created_at: 'this_week', tags: [tag] }, false)
        article.reload
        assert_response 200
        pattern = private_api_solution_article_pattern(article, action: :filter)
        match_json([pattern])
      end

      def test_article_filters_with_created_at_option_7days
        author_id = @account.agents.first.id
        article_meta = create_article(user_id: author_id, folder_meta_id: @@folder_meta.id)
        article = article_meta.solution_articles.first
        tag = Faker::Lorem.characters(7)
        create_tag_use(@account, taggable_type: 'Solution::Article', taggable_id: article.id, name: tag,
                                 allow_skip: true)
        get :filter, controller_params({ version: 'private', portal_id: @portal_id.to_s, status: '2',
                                         author: author_id.to_s, category: [@@category_meta.id.to_s], folder: [@@folder_meta.id.to_s],
                                         created_at: '7days', tags: [tag] }, false)
        article.reload
        assert_response 200
        pattern = private_api_solution_article_pattern(article, action: :filter)
        match_json([pattern])
      end

      def test_article_filters_with_created_at_option_this_month
        author_id = @account.agents.first.id
        article_meta = create_article(user_id: author_id, folder_meta_id: @@folder_meta.id)
        article = article_meta.solution_articles.first
        tag = Faker::Lorem.characters(7)
        create_tag_use(@account, taggable_type: 'Solution::Article', taggable_id: article.id, name: tag,
                                 allow_skip: true)
        get :filter, controller_params({ version: 'private', portal_id: @portal_id.to_s, status: '2',
                                         author: author_id.to_s, category: [@@category_meta.id.to_s], folder: [@@folder_meta.id.to_s],
                                         created_at: 'this_month', tags: [tag] }, false)
        article.reload
        assert_response 200
        pattern = private_api_solution_article_pattern(article, action: :filter)
        match_json([pattern])
      end

      def test_article_filters_with_lastmodified_at_option_this_month
        author_id = @account.agents.first.id
        article_meta = create_article(user_id: author_id, folder_meta_id: @@folder_meta.id)
        article = article_meta.solution_articles.first
        tag = Faker::Lorem.characters(7)
        create_tag_use(@account, taggable_type: 'Solution::Article', taggable_id: article.id, name: tag,
                                 allow_skip: true)
        get :filter, controller_params({ version: 'private', portal_id: @portal_id.to_s, status: '2',
                                         author: author_id.to_s, category: [@@category_meta.id.to_s], folder: [@@folder_meta.id.to_s],
                                         last_modified: 'this_month', tags: [tag] }, false)
        article.reload
        assert_response 200
        pattern = private_api_solution_article_pattern(article, action: :filter)
        match_json([pattern])
      end

      def test_article_filters_with_created_at_option_60days
        author_id = @account.agents.first.id
        article_meta = create_article(user_id: author_id, folder_meta_id: @@folder_meta.id)
        article = article_meta.solution_articles.first
        tag = Faker::Lorem.characters(7)
        create_tag_use(@account, taggable_type: 'Solution::Article', taggable_id: article.id, name: tag,
                                 allow_skip: true)
        get :filter, controller_params({ version: 'private', portal_id: @portal_id.to_s, status: '2',
                                         author: author_id.to_s, category: [@@category_meta.id.to_s], folder: [@@folder_meta.id.to_s],
                                         created_at: '60days', tags: [tag] }, false)
        article.reload
        assert_response 200
        pattern = private_api_solution_article_pattern(article, action: :filter)
        match_json([pattern])
      end

      def test_article_filters_with_created_at_option_180days
        author_id = @account.agents.first.id
        article_meta = create_article(user_id: author_id, folder_meta_id: @@folder_meta.id)
        article = article_meta.solution_articles.first
        tag = Faker::Lorem.characters(7)
        create_tag_use(@account, taggable_type: 'Solution::Article', taggable_id: article.id, name: tag,
                                 allow_skip: true)
        get :filter, controller_params({ version: 'private', portal_id: @portal_id.to_s, status: '2',
                                         author: author_id.to_s, category: [@@category_meta.id.to_s], folder: [@@folder_meta.id.to_s],
                                         created_at: '180days', tags: [tag] }, false)
        article.reload
        assert_response 200
        pattern = private_api_solution_article_pattern(article, action: :filter)
        match_json([pattern])
      end

      def test_article_filters_with_last_modified_option
        author_id = @account.agents.first.id
        article_meta = create_article(user_id: author_id, folder_meta_id: @@folder_meta.id)
        article = article_meta.solution_articles.first
        tag = Faker::Lorem.characters(7)
        create_tag_use(@account, taggable_type: 'Solution::Article', taggable_id: article.id, name: tag,
                                 allow_skip: true)
        get :filter, controller_params({ version: 'private', portal_id: @portal_id.to_s, status: '2',
                                         author: author_id.to_s, category: [@@category_meta.id.to_s], folder: [@@folder_meta.id.to_s],
                                         last_modified: '30days', tags: [tag] }, false)
        article.reload
        assert_response 200
        pattern = private_api_solution_article_pattern(article, action: :filter)
        match_json([pattern])
      end

      def test_article_filters_with_createdat_and_lastmodified
        author_id = @account.agents.first.id
        article_meta = create_article(user_id: author_id, folder_meta_id: @@folder_meta.id)
        article = article_meta.solution_articles.first
        tag = Faker::Lorem.characters(7)
        create_tag_use(@account, taggable_type: 'Solution::Article', taggable_id: article.id, name: tag,
                                 allow_skip: true)
        get :filter, controller_params({ version: 'private', portal_id: @portal_id.to_s, status: '2',
                                         author: author_id.to_s, category: [@@category_meta.id.to_s], folder: [@@folder_meta.id.to_s],
                                         created_at: '30days', last_modified: '60days', tags: [tag] }, false)
        article.reload
        assert_response 200
        pattern = private_api_solution_article_pattern(article, action: :filter)
        match_json([pattern])
      end

      def test_article_filters_with_createdat_invalid
        author_id = @account.agents.first.id
        article_meta = create_article(user_id: author_id, folder_meta_id: @@folder_meta.id)
        article = article_meta.solution_articles.first
        tag = Faker::Lorem.characters(7)
        create_tag_use(@account, taggable_type: 'Solution::Article', taggable_id: article.id, name: tag,
                                 allow_skip: true)
        get :filter, controller_params({ version: 'private', portal_id: @portal_id.to_s, status: '2',
                                         author: author_id.to_s, category: [@@category_meta.id.to_s], folder: [@@folder_meta.id.to_s],
                                         created_at: 'invalid', last_modified: '60days', tags: [tag] }, false)
        assert_response 400
      end

      def test_article_filters_with_lastmodified_invalid
        author_id = @account.agents.first.id
        article_meta = create_article(user_id: author_id, folder_meta_id: @@folder_meta.id)
        article = article_meta.solution_articles.first
        tag = Faker::Lorem.characters(7)
        create_tag_use(@account, taggable_type: 'Solution::Article', taggable_id: article.id, name: tag,
                                 allow_skip: true)
        get :filter, controller_params({ version: 'private', portal_id: @portal_id.to_s, status: '2',
                                         author: author_id.to_s, category: [@@category_meta.id.to_s], folder: [@@folder_meta.id.to_s],
                                         last_modified: 'invalid', tags: [tag] }, false)
        assert_response 400
      end

      def test_article_filters_with_no_results
        author_id = @account.agents.first.id
        article_meta = create_article(user_id: author_id, folder_meta_id: @@folder_meta.id)
        article = article_meta.solution_articles.first
        get :filter, controller_params({ version: 'private', portal_id: @portal_id.to_s, status: SolutionConstants::STATUS_FILTER_BY_TOKEN[:published],
                                         author: author_id.to_s, category: [@@category_meta.id.to_s], folder: [@@folder_meta.id.to_s],
                                         created_at: { start: '20190101', end: '21190101' }, last_modified: { start: '20190101', end: '21190101' }, tags: ['sample'] }, false)
        article.reload
        assert_response 200
        match_json([])
      end

      def test_article_filters_with_drafts
        author_id = @account.agents.first.id
        article_meta = create_article(user_id: author_id, folder_meta_id: @@folder_meta.id)
        article = article_meta.solution_articles.first
        new_user = add_test_agent
        create_draft(article: article, user_id: new_user.id, keep_previous_author: true)
        tag = Faker::Lorem.characters(7)
        create_tag_use(@account, taggable_type: 'Solution::Article', taggable_id: article.id, name: tag,
                                 allow_skip: true)
        get :filter, controller_params({ version: 'private', portal_id: @portal_id.to_s, status: SolutionConstants::STATUS_FILTER_BY_TOKEN[:draft],
                                         author: new_user.id.to_s, category: [@@category_meta.id.to_s], folder: [@@folder_meta.id.to_s],
                                         created_at: { start: '20190101', end: '21190101' }, last_modified: { start: '20190101', end: '21190101' }, tags: [tag] }, false)
        article.reload
        assert_response 200
        pattern = private_api_solution_article_pattern(article, action: :filter)
        match_json([pattern])
      end

      def test_article_filters_published_with_drafts
        author_id = @account.agents.first.id
        article_meta = create_article(user_id: author_id, folder_meta_id: @@folder_meta.id)
        article = article_meta.solution_articles.first
        new_user = add_test_agent
        create_draft(article: article, user_id: new_user.id, keep_previous_author: true)
        tag = Faker::Lorem.characters(7)
        create_tag_use(@account, taggable_type: 'Solution::Article', taggable_id: article.id, name: tag,
                                 allow_skip: true)
        get :filter, controller_params({ version: 'private', portal_id: @portal_id.to_s, status: SolutionConstants::STATUS_FILTER_BY_TOKEN[:published],
                                         author: new_user.id.to_s, category: [@@category_meta.id.to_s], folder: [@@folder_meta.id.to_s],
                                         created_at: { start: '20190101', end: '21190101' }, last_modified: { start: '20190101', end: '21190101' }, tags: [tag] }, false)
        article.reload
        assert_response 200
        pattern = private_api_solution_article_pattern(article, action: :filter)
        match_json([pattern])
      end

      def test_article_filter_status_draft_should_not_return_inreview_draft
        Account.any_instance.stubs(:article_approval_workflow_enabled?).returns(true)
        article = get_in_review_article
        tag = 'filterstatusinreview' + Random.rand(99_999_999).to_s
        create_tag_use(@account, taggable_type: 'Solution::Article', taggable_id: article.id, name: tag,
                                 allow_skip: true)
        get :filter, controller_params({ version: 'private', portal_id: @portal_id.to_s, status: SolutionConstants::STATUS_FILTER_BY_TOKEN[:draft], tags: [tag] }, false)
        article.reload
        assert_response 200
        match_json([])
      ensure
        Account.any_instance.unstub(:article_approval_workflow_enabled?)
      end

      def test_article_filter_status_draft_should_not_return_approved_draft
        Account.any_instance.stubs(:article_approval_workflow_enabled?).returns(true)
        article = get_approved_article
        tag = 'filterstatusapproved' + Random.rand(99_999_999).to_s
        create_tag_use(@account, taggable_type: 'Solution::Article', taggable_id: article.id, name: tag,
                                 allow_skip: true)
        get :filter, controller_params({ version: 'private', portal_id: @portal_id.to_s, status: SolutionConstants::STATUS_FILTER_BY_TOKEN[:draft], tags: [tag] }, false)
        article.reload
        assert_response 200
        match_json([])
      ensure
        Account.any_instance.unstub(:article_approval_workflow_enabled?)
      end

      def test_article_filter_with_status_inreview
        user = add_new_user(@account, active: true)
        Account.any_instance.stubs(:article_approval_workflow_enabled?).returns(true)
        approver = add_test_agent
        add_privilege(approver, :approve_article)
        User.current.reload
        remove_privilege(User.current, :publish_solution)
        article = get_in_review_article(Account.current.language_object, user, approver)
        tag = 'filterstatusinreview' + Random.rand(99_999_999).to_s
        create_tag_use(@account, taggable_type: 'Solution::Article', taggable_id: article.id, name: tag,
                                 allow_skip: true)
        get :filter, controller_params({ version: 'private', portal_id: @portal_id.to_s, status: SolutionConstants::STATUS_FILTER_BY_TOKEN[:in_review], tags: [tag] }, false)
        article.reload
        assert_response 200
        pattern = private_api_solution_article_pattern(article, action: :filter)
        match_json([pattern])
      ensure
        Account.any_instance.unstub(:article_approval_workflow_enabled?)
        add_privilege(User.current, :publish_solution)
      end

      def test_article_filters_unpublished_with_diff_user_draft
        author_id = @account.agents.first.id
        article_meta = create_article(user_id: author_id, folder_meta_id: @@folder_meta.id)
        article = article_meta.solution_articles.first
        new_user = add_test_agent
        create_draft(article: article, user_id: new_user.id, keep_previous_author: true)
        tag = Faker::Lorem.characters(7)
        create_tag_use(@account, taggable_type: 'Solution::Article', taggable_id: article.id, name: tag,
                                 allow_skip: true)
        get :filter, controller_params({ version: 'private', portal_id: @portal_id.to_s, status: '1',
                                         author: new_user.id.to_s, category: [@@category_meta.id.to_s], folder: [@@folder_meta.id.to_s],
                                         created_at: { start: '20190101', end: '21190101' }, last_modified: { start: '20190101', end: '21190101' }, tags: [tag] }, false)
        article.reload
        assert_response 200
        pattern = private_api_solution_article_pattern(article, action: :filter)
        match_json([pattern])
      ensure
        Account.any_instance.unstub(:article_approval_workflow_enabled?)
        add_privilege(User.current, :publish_solution)
      end

      def test_article_filter_with_status_approved
        user = add_new_user(@account, active: true)
        Account.any_instance.stubs(:article_approval_workflow_enabled?).returns(true)
        approver = add_test_agent
        add_privilege(approver, :approve_article)
        User.current.reload
        remove_privilege(User.current, :publish_solution)
        article = get_approved_article(Account.current.language_object, user, approver)
        tag = 'filterstatusapproved' + Random.rand(99_999_999).to_s
        create_tag_use(@account, taggable_type: 'Solution::Article', taggable_id: article.id, name: tag,
                                 allow_skip: true)
        get :filter, controller_params({ version: 'private', portal_id: @portal_id.to_s, status: SolutionConstants::STATUS_FILTER_BY_TOKEN[:approved], tags: [tag] }, false)
        article.reload
        assert_response 200
        pattern = private_api_solution_article_pattern(article, action: :filter)
        match_json([pattern])
      ensure
        Account.any_instance.unstub(:article_approval_workflow_enabled?)
        add_privilege(User.current, :publish_solution)
      end

      def test_article_filter_with_status_inreview_and_approver
        user = add_new_user(@account, active: true)
        Account.any_instance.stubs(:article_approval_workflow_enabled?).returns(true)
        approver = add_test_agent
        add_privilege(approver, :approve_article)
        User.current.reload
        remove_privilege(User.current, :publish_solution)
        article = get_in_review_article(Account.current.language_object, user, approver)
        tag = 'filterinreviewapprover' + Random.rand(99_999_999).to_s
        create_tag_use(@account, taggable_type: 'Solution::Article', taggable_id: article.id, name: tag,
                                 allow_skip: true)
        get :filter, controller_params({ version: 'private', portal_id: @portal_id.to_s, status: SolutionConstants::STATUS_FILTER_BY_TOKEN[:in_review], approver: approver.id, tags: [tag] }, false)
        article.reload
        assert_response 200
        pattern = private_api_solution_article_pattern(article, action: :filter)
        match_json([pattern])
      ensure
        Account.any_instance.unstub(:article_approval_workflow_enabled?)
        add_privilege(User.current, :publish_solution)
      end

      def test_article_filter_with_status_approved_and_approver
        user = add_new_user(@account, active: true)
        Account.any_instance.stubs(:article_approval_workflow_enabled?).returns(true)
        approver = add_test_agent
        add_privilege(approver, :approve_article)
        User.current.reload
        remove_privilege(User.current, :publish_solution)
        article = get_approved_article(Account.current.language_object, user, approver)
        tag = 'filterapprovedapprover' + Random.rand(99_999_999).to_s
        create_tag_use(@account, taggable_type: 'Solution::Article', taggable_id: article.id, name: tag,
                                 allow_skip: true)
        get :filter, controller_params({ version: 'private', portal_id: @portal_id.to_s, status: SolutionConstants::STATUS_FILTER_BY_TOKEN[:approved], approver: approver.id, tags: [tag] }, false)
        article.reload
        assert_response 200
        pattern = private_api_solution_article_pattern(article, action: :filter)
        match_json([pattern])
      ensure
        Account.any_instance.unstub(:article_approval_workflow_enabled?)
        add_privilege(User.current, :publish_solution)
      end

      def test_article_filters_with_search_term_status_approved_and_approver_with_es_filter_privilege
        user = add_new_user(@account, active: true)
        Account.any_instance.stubs(:article_approval_workflow_enabled?).returns(true)
        approver = add_test_agent
        add_privilege(approver, :approve_article)
        User.current.reload
        remove_privilege(User.current, :publish_solution)
        article = get_approved_article(Account.current.language_object, user, approver)
        base_struct = Struct.new(:records, :total_entries)
        records_struct = Struct.new(:results)
        result_struct = Struct.new(:id)
        @results = base_struct.new(records_struct.new, 1)
        @results.records['results'] = [result_struct.new(article.id)]
        stub_private_search_response_with_object(@results) do
          get :filter, controller_params(version: 'private', portal_id: @portal_id, status: SolutionConstants::STATUS_FILTER_BY_TOKEN[:approved], approver: approver.id, term: article.title)
        end
        article.reload
        assert_response 200
        pattern = private_api_solution_article_pattern(article, action: :filter)
        match_json([pattern])
      ensure
        Account.any_instance.unstub(:article_approval_workflow_enabled?)
        add_privilege(User.current, :publish_solution)
      end

      def test_article_filters_with_search_term_platforms_with_es_filter_privilege
        Account.any_instance.stubs(:omni_bundle_account?).returns(true)
        Account.current.launch(:kbase_omni_bundle)
        article = get_article_with_platform_mapping
        base_struct = Struct.new(:records, :total_entries)
        records_struct = Struct.new(:results)
        result_struct = Struct.new(:id)
        @results = base_struct.new(records_struct.new, 1)
        @results.records['results'] = [result_struct.new(article.id)]
        stub_private_search_response_with_object(@results) do
          get :filter, controller_params(version: 'private', portal_id: @portal_id, platforms: article.parent.solution_platform_mapping.enabled_platforms, term: article.title)
        end
        article.reload
        assert_response 200
        pattern = private_api_solution_article_pattern(article, action: :filter)
        match_json([pattern])
      ensure
        Account.any_instance.stubs(:omni_bundle_account?).returns(true)
        Account.current.launch(:kbase_omni_bundle)
      end

      def test_article_filters_unpublished_diff_user
        author_id = add_test_agent.id
        article_meta = create_article(user_id: author_id, folder_meta_id: @@folder_meta.id, status: '1')
        article = article_meta.solution_articles.first
        tag = Faker::Lorem.characters(7)
        create_tag_use(@account, taggable_type: 'Solution::Article', taggable_id: article.id, name: tag,
                                 allow_skip: true)
        get :filter, controller_params({ version: 'private', portal_id: @portal_id.to_s, status: SolutionConstants::STATUS_FILTER_BY_TOKEN[:draft],
                                         author: author_id.to_s, category: [@@category_meta.id.to_s], folder: [@@folder_meta.id.to_s],
                                         created_at: { start: '20190101', end: '21190101' }, last_modified: { start: '20190101', end: '21190101' }, tags: [tag] }, false)
        article.reload
        assert_response 200
        pattern = private_api_solution_article_pattern(article, action: :filter)
        match_json([pattern])
      end

      def test_article_filters_unpublished
        author_id = @account.agents.first.id
        article_meta = create_article(user_id: author_id, folder_meta_id: @@folder_meta.id, status: '1')
        article = article_meta.solution_articles.first
        new_user = add_test_agent
        draft = article.draft
        draft.user_id = new_user.id
        draft.keep_previous_author = true
        draft.save
        tag = Faker::Lorem.characters(7)
        create_tag_use(@account, taggable_type: 'Solution::Article', taggable_id: article.id, name: tag,
                                 allow_skip: true)
        get :filter, controller_params({ version: 'private', portal_id: @portal_id.to_s, status: SolutionConstants::STATUS_FILTER_BY_TOKEN[:draft],
                                         author: new_user.id.to_s, category: [@@category_meta.id.to_s], folder: [@@folder_meta.id.to_s],
                                         created_at: { start: '20190101', end: '21190101' }, last_modified: { start: '20190101', end: '21190101' }, tags: [tag] }, false)
        article.reload
        assert_response 200
        pattern = private_api_solution_article_pattern(article, action: :filter)
        match_json([pattern])
      end

      def test_article_filters_modifier
        author_id = @account.agents.first.id
        article_meta = create_article(user_id: author_id, folder_meta_id: @@folder_meta.id)
        article = article_meta.solution_articles.first
        new_user = add_test_agent
        article.modified_by = new_user.id
        article.save
        get :filter, controller_params({ version: 'private', portal_id: @portal_id.to_s, status: SolutionConstants::STATUS_FILTER_BY_TOKEN[:published],
                                         author: new_user.id.to_s, category: [@@category_meta.id.to_s], folder: [@@folder_meta.id.to_s], last_modified: { start: '20190101', end: '21190101' } }, false)
        article.reload
        assert_response 200
        pattern = private_api_solution_article_pattern(article, action: :filter)
        match_json([pattern])
      end

      def test_article_filters_invalid_modifier
        get :filter, controller_params({ version: 'private', portal_id: @portal_id.to_s,
                                         author: Faker::Lorem.characters(12) }, false)
        assert_response 400
      end

      def test_article_filters_with_search_term
        article_title = Faker::Lorem.characters(10)
        article = create_article(article_params(title: article_title)).primary_article
        base_struct = Struct.new(:records, :total_entries)
        records_struct = Struct.new(:results)
        result_struct = Struct.new(:id)
        @results = base_struct.new(records_struct.new(), 1)
        @results.records['results'] = [result_struct.new(article.id)]
        stub_private_search_response_with_object(@results) do
          get :filter, controller_params(version: 'private', portal_id: @portal_id, term: article_title)
        end
        article.reload
        assert_response 200
        pattern = private_api_solution_article_pattern(article, action: :filter)
        match_json([pattern])
      end

      def test_article_filters_with_default_article
        default_category = @account.solution_category_meta.where(is_default: true).first
        default_folder = default_category.solution_folder_meta.first
        article_meta = create_article(folder_meta_id: default_folder.id, status: '1')
        article = article_meta.solution_articles.first
        create_draft(article: article, keep_previous_author: true)
        get :filter, controller_params({ version: 'private', portal_id: @portal_id.to_s, status: SolutionConstants::STATUS_FILTER_BY_TOKEN[:draft],
                                         category: [default_category.id.to_s] }, false)
        article.reload
        assert_response 200
        pattern = private_api_solution_article_pattern(article, action: :filter)
        match_json([pattern])
      end

      def test_article_filters_by_folder
        article_meta = @account.solution_article_meta.where(solution_folder_meta_id: @@folder_meta.id)
        article_meta = create_article(folder_meta_id: @@folder_meta.id) if article_meta.blank?
        articles = get_portal_articles(@portal_id, [@account.language_object.id]).where(parent_id: article_meta.map(&:id)).first(30)
        get :filter, controller_params({ version: 'private', portal_id: @portal_id.to_s, folder: [@@folder_meta.id.to_s] }, false)
        assert_response 200
        pattern = articles.map { |article| private_api_solution_article_pattern(article, action: :filter) }
        match_json(pattern)
      end

      def test_article_filters_by_category_folder
        article_meta = @account.solution_article_meta.where(solution_folder_meta_id: @@folder_meta.id)
        article_meta = create_article(folder_meta_id: @@folder_meta.id) if article_meta.blank?
        articles = get_portal_articles(@portal_id, [@account.language_object.id]).where(parent_id: article_meta.map(&:id)).first(30)
        get :filter, controller_params({ version: 'private', portal_id: @portal_id.to_s, category: [@@category_meta.id.to_s], folder: [@@folder_meta.id.to_s] }, false)
        assert_response 200
        pattern = articles.map { |article| private_api_solution_article_pattern(article, action: :filter) }
        match_json(pattern)
      end

      def test_article_filters_by_category_folder_mismatched
        article_meta = create_article(folder_meta_id: @@folder_meta.id)
        article = article_meta.solution_articles.first
        get :filter, controller_params({ version: 'private', portal_id: @portal_id.to_s, category: [@@category_meta.id.to_s],
                                         folder: ['10101010100000'] }, false)
        assert_response 200
        match_json([])
      end

      def test_article_filters_by_tags
        author_id = @account.agents.first.id
        article_meta = create_article(user_id: author_id, folder_meta_id: @@folder_meta.id)
        article = article_meta.solution_articles.first
        tag = Faker::Lorem.characters(7)
        create_tag_use(@account, taggable_type: 'Solution::Article', taggable_id: article.id, name: tag,
                                 allow_skip: true)
        get :filter, controller_params({ version: 'private', portal_id: @portal_id.to_s, tags: [tag] }, false)
        article.reload
        assert_response 200
        pattern = private_api_solution_article_pattern(article, action: :filter)
        match_json([pattern])
      end

      def test_article_filters_by_tags_distinct_check
        author_id = @account.agents.first.id
        article_meta = create_article(user_id: author_id, folder_meta_id: @@folder_meta.id)
        article = article_meta.solution_articles.first
        tag1 = "#{Faker::Lorem.characters(7)}#{rand(999_999)}"
        create_tag_use(@account, taggable_type: 'Solution::Article', taggable_id: article.id, name: tag1,
                                 allow_skip: true)
        tag2 = "#{Faker::Lorem.characters(7)}#{rand(999_999)}"
        create_tag_use(@account, taggable_type: 'Solution::Article', taggable_id: article.id, name: tag2,
                                 allow_skip: true)
        get :filter, controller_params({ version: 'private', portal_id: @portal_id.to_s, tags: [tag1, tag2] }, false)
        article.reload
        assert_equal article.tags.count, 2
        assert_response 200
        pattern = private_api_solution_article_pattern(article, action: :filter)
        match_json([pattern])
      end

      def test_article_filters_by_status
        articles = get_portal_articles(@portal_id, [6]).where(status: '2').first(30)
        if articles.blank?
          article_meta = create_article(folder_meta_id: @@folder_meta.id)
          articles = article_meta.solution_articles
        end
        get :filter, controller_params({ version: 'private', portal_id: @portal_id.to_s, status: SolutionConstants::STATUS_FILTER_BY_TOKEN[:published] }, false)
        assert_response 200
        pattern = articles.map { |article| private_api_solution_article_pattern(article, action: :filter) }
        match_json(pattern)
      end

      def test_article_filters_by_author_lastmodified
        author_id = add_test_agent.id
        article_meta = create_article(user_id: author_id, folder_meta_id: @@folder_meta.id)
        article = article_meta.solution_articles.first
        get :filter, controller_params({ version: 'private', portal_id: @portal_id.to_s,
                                         author: author_id.to_s, last_modified: { start: '20190101', end: '21190101' } }, false)
        article.reload
        assert_response 200
        pattern = private_api_solution_article_pattern(article, action: :filter)
        match_json([pattern])
      end

      def test_article_filters_by_author_createdat_mismatched
        author_id = add_test_agent.id
        article_meta = create_article(user_id: author_id, folder_meta_id: @@folder_meta.id)
        article = article_meta.solution_articles.first
        start_date = Time.now + 10.days
        end_date = Time.now + 20.days
        get :filter, controller_params({ version: 'private', portal_id: @portal_id.to_s,
                                         author: author_id.to_s, created_at: { start: start_date.to_s, end: end_date.to_s } }, false)
        assert_response 200
        match_json([])
      end

      def test_export_articles_with_filters
        export_params = { portal_id: @portal_id.to_s, author: 1, status: 1, category: ['2'], folder: ['4'], tags: ['Tag1'], article_fields: [{ field_name: 'title', column_name: 'Title' }] }
        post :export, construct_params({ version: 'private' }, export_params)
        assert_response 204
        assert_equal(' ', response.body)
      end

      def test_export_articles_with_created_at_option_filters
        export_params = { portal_id: @portal_id.to_s, author: 1, status: 1, category: ['2'], folder: ['4'], tags: ['Tag1'], created_at: 'this_week', article_fields: [{ field_name: 'title', column_name: 'Title' }] }
        post :export, construct_params({ version: 'private' }, export_params)
        assert_response 204
        assert_equal(' ', response.body)
      end

      def test_export_articles_with_outdated_status
        export_params = { portal_id: @portal_id.to_s, status: SolutionConstants::STATUS_FILTER_BY_TOKEN[:outdated], article_fields: [{ field_name: 'title', column_name: 'Title' }] }
        expected_params = { filter_params: { 'portal_id' => @portal_id.to_s, 'article_fields' => [{ 'field_name' => 'title', 'column_name' => 'Title' }], 'outdated' => true }, lang_id: Account.current.language_object.id, lang_code: Account.current.language, current_user_id: User.current.id, export_fields: { 'title' => 'Title' }, portal_url: Account.current.portals.where(id: @portal_id.to_s).first.portal_url.presence || Account.current.host }
        Export::Article.expects(:enqueue).with(expected_params).once
        post :export, construct_params({ version: 'private' }, export_params)
        assert_response 204
        assert_equal(' ', response.body)
      end

      def test_export_articles_without_article_export_privilege
        User.any_instance.stubs(:privilege?).with(:export_articles).returns(false)
        export_params = { portal_id: @portal_id.to_s, author: 1, status: 1, category: ['2'], folder: ['4'], tags: ['Tag1'], article_fields: [{ field_name: 'title', column_name: 'Title' }] }
        post :export, construct_params({ version: 'private' }, export_params)
        assert_response 403
      ensure
        User.any_instance.unstub(:privilege?)
      end

      def test_export_articles_without_feature
        Account.any_instance.stubs(:article_export_enabled?).returns(false)
        export_params = { portal_id: @portal_id.to_s, author: 1, status: 1, category: ['2'], folder: ['4'], tags: ['Tag1'], article_fields: [{ field_name: 'title', column_name: 'Title' }] }
        post :export, construct_params({ version: 'private' }, export_params)
        assert_response 403
        match_json(request_error_pattern(:require_feature, feature: :article_export))
      ensure
        Account.any_instance.unstub(:article_export_enabled?)
      end

      def test_export_articles_with_export_feature_with_advanced_filters
        Account.any_instance.stubs(:article_filters_enabled?).returns(false)
        export_params = { portal_id: @portal_id.to_s, author: 1, category: ['2'], article_fields: [{ field_name: 'title', column_name: 'Title' }] }
        post :export, construct_params({ version: 'private' }, export_params)
        assert_response 403
      ensure
        Account.any_instance.unstub(:article_filters_enabled?)
      end

      def test_export_articles_with_export_feature_with_default_filters
        Account.any_instance.stubs(:article_filters_enabled?).returns(false)
        export_params = { portal_id: @portal_id.to_s, author: 1, article_fields: [{ field_name: 'title', column_name: 'Title' }] }
        post :export, construct_params({ version: 'private' }, export_params)
        assert_response 204
        assert_equal(' ', response.body)
      ensure
        Account.any_instance.unstub(:article_filters_enabled?)
      end

      def test_export_articles_without_filters
        export_params = { portal_id: @portal_id.to_s, article_fields: [{ field_name: 'title', column_name: 'Title' }] }
        post :export, construct_params({ version: 'private' }, export_params)
        assert_response 204
        assert_equal(' ', response.body)
      end

      def test_export_articles_without_mandatory_fields
        post :export, construct_params({ version: 'private' }, {})
        assert_response 400
        expected = { description: 'Validation failed', errors: [{ field: 'portal_id', message: 'Mandatory attribute missing', code: 'missing_field' }, { field: 'article_fields', message: 'Mandatory attribute missing', code: 'missing_field' }] }
        assert_equal(expected, JSON.parse(response.body, symbolize_names: true))
      end

      def test_export_articles_with_invalid_portalid
        export_params = { portal_id: 1232, article_fields: [{ field_name: 'title', column_name: 'Title' }] }
        post :export, construct_params({ version: 'private' }, export_params)
        assert_response 400
        expected = { description: 'Validation failed', errors: [{ field: 'portal_id', message: 'Value set is of type Integer.It should be a/an String', code: 'datatype_mismatch' }] }
        assert_equal(expected, JSON.parse(response.body, symbolize_names: true))
      end

      def test_export_articles_with_invalid_author
        export_params = { portal_id: @portal_id.to_s, author: 'invalid', article_fields: [{ field_name: 'title', column_name: 'Title' }] }
        post :export, construct_params({ version: 'private' }, export_params)
        assert_response 400
        expected = { description: 'Validation failed', errors: [{ field: 'author', message: 'Value set is of type String.It should be a/an Positive Integer', code: 'datatype_mismatch' }] }
        assert_equal(expected, JSON.parse(response.body, symbolize_names: true))
      end

      def test_export_articles_with_invalid_status
        export_params = { portal_id: @portal_id.to_s, status: 'invalid', article_fields: [{ field_name: 'title', column_name: 'Title' }] }
        post :export, construct_params({ version: 'private' }, export_params)
        assert_response 400
        expected = { description: 'Validation failed', errors: [{ field: 'status', message: "It should be one of these values: '1,2,3,4,5'", code: 'invalid_value' }] }
        assert_equal(expected, JSON.parse(response.body, symbolize_names: true))
      end

      def test_export_articles_with_invalid_category
        export_params = { portal_id: @portal_id.to_s, category: 'invalid', article_fields: [{ field_name: 'title', column_name: 'Title' }] }
        post :export, construct_params({ version: 'private' }, export_params)
        assert_response 400
        expected = { description: 'Validation failed', errors: [{ field: 'category', message: 'Value set is of type String.It should be a/an Array', code: 'datatype_mismatch' }] }
        assert_equal(expected, JSON.parse(response.body, symbolize_names: true))
      end

      def test_export_articles_with_invalid_folder
        export_params = { portal_id: @portal_id.to_s, folder: 'invalid', article_fields: [{ field_name: 'title', column_name: 'Title' }] }
        post :export, construct_params({ version: 'private' }, export_params)
        assert_response 400
        expected = { description: 'Validation failed', errors: [{ field: 'folder', message: 'Value set is of type String.It should be a/an Array', code: 'datatype_mismatch' }] }
        assert_equal(expected, JSON.parse(response.body, symbolize_names: true))
      end

      def test_export_articles_with_invalid_tags
        export_params = { portal_id: @portal_id.to_s, tags: 'invalid', article_fields: [{ field_name: 'title', column_name: 'Title' }] }
        post :export, construct_params({ version: 'private' }, export_params)
        assert_response 400
        expected = { description: 'Validation failed', errors: [{ field: 'tags', message: 'Value set is of type String.It should be a/an Array', code: 'datatype_mismatch' }] }
        assert_equal(expected, JSON.parse(response.body, symbolize_names: true))
      end

      def test_export_articles_with_suggested_column_with_suggested_feature
        export_params = { portal_id: @portal_id.to_s, article_fields: [{ field_name: 'suggested', column_name: 'Suggested' }] }
        post :export, construct_params({ version: 'private' }, export_params)
        assert_response 204
      end

      def test_reorder_without_position
        folder = @account.solution_folder_meta.where(is_default: false).first
        populate_articles(folder)
        put :reorder, construct_params(version: 'private', id: folder.solution_article_meta.first.id)
        assert_response 400
        match_json(validation_error_pattern(bad_request_error_pattern(:position, 'It should be a/an Positive Integer', code: :missing_field)))
      end

      def test_reorder
        folder = @account.solution_folder_meta.where(is_default: false).first
        populate_articles(folder)
        old_id_order = folder.solution_article_meta.pluck(:id)
        put :reorder, construct_params({ version: 'private', id: folder.solution_article_meta.first.id }, position: 10)
        assert_response 204
        new_id_order = folder.solution_article_meta.pluck(:id)
        assert old_id_order.slice(1, 9) == new_id_order.slice(0, 9)
        assert old_id_order[0] == new_id_order[9]
        assert old_id_order.slice(10, old_id_order.size) == new_id_order.slice(10, new_id_order.size)
      end

      def test_reorder_without_privilege
        User.any_instance.stubs(:privilege?).with(:create_and_edit_article).returns(true)
        User.any_instance.stubs(:privilege?).with(:publish_solution).returns(false)
        folder = @account.solution_folder_meta.where(is_default: false).first
        populate_articles(folder)
        folder.reload
        put :reorder, construct_params({ version: 'private' }, id: folder.solution_article_meta.first.id, position: 2)
        assert_response 403
      ensure
        User.any_instance.unstub(:privilege?)
      end

      def test_article_filters_with_secondary_language_nodata
        Account.any_instance.stubs(:supported_languages).returns(['et'])
        Account.any_instance.stubs(:all_language_objects).returns([Language.find_by_code('et')])
        get :filter, controller_params(version: 'private', portal_id: @portal_id, language: 'et')
        assert_response 200
        match_json([])
        Account.any_instance.unstub(:supported_languages)
        Account.any_instance.unstub(:all_language_objects)
      end

      def test_article_filters_with_secondary_language
        languages = @account.supported_languages + ['primary']
        language = @account.supported_languages.first
        articles = get_portal_articles(@portal_id, [Language.find_by_code(language).id]).first(30)
        if articles.blank?
          article_meta = create_article(article_params(lang_codes: languages))
          articles = [article_meta.safe_send("#{language}_article")]
        end
        Account.any_instance.stubs(:all_language_objects).returns([Language.find_by_code(language)])
        get :filter, controller_params(version: 'private', portal_id: @portal_id, language: language)
        assert_response 200
        pattern = articles.map { |article| private_api_solution_article_pattern(article, { action: :filter }, true, nil) }
        match_json(pattern)
        Account.any_instance.unstub(:all_language_objects)
      end

      def test_article_filters_all_attributes_with_secondary_language
        languages = @account.supported_languages + ['primary']
        language = @account.supported_languages.first
        author_id = @account.agents.first.id
        article_meta = create_article(user_id: author_id, folder_meta_id: @@folder_meta.id, lang_codes: languages)
        article = article_meta.safe_send("#{language}_article")
        tag = Faker::Lorem.characters(7)
        create_tag_use(@account, taggable_type: 'Solution::Article', taggable_id: article.id, name: tag, allow_skip: true)
        Account.any_instance.stubs(:all_language_objects).returns([Language.find_by_code(language)])
        get :filter, controller_params({ version: 'private', portal_id: @portal_id.to_s, language: language, status: SolutionConstants::STATUS_FILTER_BY_TOKEN[:published],
                                         author: author_id.to_s, category: [@@category_meta.id.to_s], folder: [@@folder_meta.id.to_s],
                                         created_at: { start: '20190101', end: '21190101' }, last_modified: { start: '20190101', end: '21190101' }, tags: [tag] }, false)
        article.reload
        assert_response 200
        pattern = private_api_solution_article_pattern(article, { action: :filter }, true, nil)
        match_json([pattern])
        Account.any_instance.unstub(:all_language_objects)
      end

      def test_article_filters_with_diff_sec_lang
        author_id = add_test_agent.id
        languages = @account.supported_languages + ['primary']
        language = @account.supported_languages.first
        article_meta = create_article(user_id: author_id, folder_meta_id: @@folder_meta.id, lang_codes: languages)
        Account.any_instance.stubs(:all_language_objects).returns([Language.find_by_code('ru-RU')])
        get :filter, controller_params({ version: 'private', portal_id: @portal_id.to_s, language: 'ru-RU', author: author_id.to_s }, false)
        assert_response 200
        match_json([])
        Account.any_instance.unstub(:all_language_objects)
      end

      def test_article_filters_by_category_folder_with_sec_lang
        languages = @account.supported_languages + ['primary']
        language  = @account.supported_languages.first
        author_id = add_test_agent.id
        article_meta = create_article(user_id: author_id, folder_meta_id: @@folder_meta.id, lang_codes: languages)
        article = article_meta.safe_send("#{language}_article")
        Account.any_instance.stubs(:all_language_objects).returns([Language.find_by_code(language)])
        get :filter, controller_params({ version: 'private', portal_id: @portal_id.to_s, language: language, category: [@@category_meta.id.to_s], folder: [@@folder_meta.id.to_s], author: author_id.to_s }, false)
        article.reload
        assert_response 200
        pattern = private_api_solution_article_pattern(article, { action: :filter }, true, nil)
        match_json([pattern])
        Account.any_instance.unstub(:all_language_objects)
      end

      def test_article_filters_by_category_folder_mismatched_with_sec_lang
        languages = @account.supported_languages + ['primary']
        language  = @account.supported_languages.first
        article_meta = create_article(folder_meta_id: @@folder_meta.id, lang_codes: languages)
        Account.any_instance.stubs(:all_language_objects).returns([Language.find_by_code(language)])
        get :filter, controller_params({ version: 'private', portal_id: @portal_id.to_s, language: language, category: ['10101010100000'], folder: [@@folder_meta.id.to_s] }, false)
        assert_response 200
        match_json([])
        Account.any_instance.unstub(:all_language_objects)
      end

      def test_article_filters_by_status_with_sec_lang
        languages = @account.supported_languages + ['primary']
        language  = @account.supported_languages.first
        articles = get_portal_articles(@portal_id, [8]).where(status: '2').first(30)
        if articles.blank?
          article_meta = create_article(folder_meta_id: @@folder_meta.id, lang_codes: languages)
          articles = [article_meta.safe_send("#{language}_article")]
        end
        Account.any_instance.stubs(:all_language_objects).returns([Language.find_by_code(language)])
        get :filter, controller_params({ version: 'private', portal_id: @portal_id.to_s, language: language, status: SolutionConstants::STATUS_FILTER_BY_TOKEN[:published] }, false)
        assert_response 200
        pattern = articles.map { |article| private_api_solution_article_pattern(article, { action: :filter }, true, nil) }
        match_json(pattern)
        Account.any_instance.unstub(:all_language_objects)
      end

      def test_article_filters_by_status_outdated_with_sec_lang
        languages = @account.supported_languages + ['primary']
        language  = @account.supported_languages.first
        article_meta = create_article(folder_meta_id: @@folder_meta.id, lang_codes: languages)
        article = article_meta.safe_send("#{language}_article")
        article.outdated = true
        article.save
        Account.any_instance.stubs(:all_language_objects).returns([Language.find_by_code(language)])
        get :filter, controller_params({ version: 'private', portal_id: @portal_id.to_s, language: language, status: SolutionConstants::STATUS_FILTER_BY_TOKEN[:outdated] }, false)
        assert_response 200
        pattern = [private_api_solution_article_pattern(article, { action: :filter }, true, nil)]
        match_json(pattern)
        Account.any_instance.unstub(:all_language_objects)
      end

      def test_article_filters_by_author_lastmodified_with_sec_lang
        languages = @account.supported_languages + ['primary']
        language  = @account.supported_languages.first
        author_id = add_test_agent.id
        article_meta = create_article(user_id: author_id, folder_meta_id: @@folder_meta.id, lang_codes: languages)
        article = article_meta.safe_send("#{language}_article")
        Account.any_instance.stubs(:all_language_objects).returns([Language.find_by_code(language)])
        get :filter, controller_params({ version: 'private', portal_id: @portal_id.to_s, language: language, author: author_id.to_s, last_modified: { start: '20190101', end: '21190101' } }, false)
        article.reload
        assert_response 200
        pattern = private_api_solution_article_pattern(article, { action: :filter }, true, nil)
        match_json([pattern])
        Account.any_instance.unstub(:all_language_objects)
      end

      def test_article_filters_by_author_createdat_mismatched_with_sec_lang
        languages = @account.supported_languages + ['primary']
        language  = @account.supported_languages.first
        author_id = add_test_agent.id
        article_meta = create_article(user_id: author_id, folder_meta_id: @@folder_meta.id, lang_codes: languages)
        articles = article_meta.safe_send("#{language}_article")
        start_date = Time.now + 10.days
        end_date = Time.now + 20.days
        Account.any_instance.stubs(:all_language_objects).returns([Language.find_by_code(language)])
        get :filter, controller_params({ version: 'private', portal_id: @portal_id.to_s, language: language,
                                         author: author_id.to_s, created_at: { start: start_date.to_s, end: end_date.to_s } }, false)
        assert_response 200
        match_json([])
        Account.any_instance.unstub(:all_language_objects)
      end

      def test_untranslated_articles_without_portal_id
        get :untranslated_articles, controller_params(version: 'private', language: 'es')
        assert_response 400
        match_json([bad_request_error_pattern('portal_id', 'Mandatory attribute missing', code: :missing_field)])
      end

      def test_untranslated_articles_with_invalid_portal_id
        get :untranslated_articles, controller_params(version: 'private', language: 'es', portal_id: 'test')
        assert_response 400
        match_json([bad_request_error_pattern(:portal_id, :invalid_portal_id)])
      end

      def test_untranslated_articles_without_multilingual_feature
        Account.any_instance.stubs(:multilingual?).returns(false)
        get :untranslated_articles, controller_params(version: 'private', language: 'es', portal_id: @account.main_portal.id)
        match_json(request_error_pattern(:require_feature, feature: 'MultilingualFeature'))
        assert_response 404
      ensure
        Account.any_instance.unstub(:multilingual?)
      end

      def test_untranslated_articles_with_invalid_language
        get :untranslated_articles, controller_params(version: 'private', language: 'test', portal_id: @account.main_portal.id)
        assert_response 404
        match_json(request_error_pattern(:language_not_allowed, code: 'test', list: (@account.supported_languages + [@account.language]).sort.join(', ')))
      end

      def test_untranslated_articles_with_invalid_param
        get :untranslated_articles, controller_params(version: 'private', language: 'es', portal_id: @account.main_portal.id, test: 'test')
        assert_response 400
        match_json([bad_request_error_pattern(:test, :invalid_field)])
      end

      def test_untranslated_articles_without_privilege
        User.any_instance.stubs(:privilege?).with(:view_solutions).returns(false)
        get :untranslated_articles, controller_params(version: 'private', language: 'es', portal_id: @account.main_portal.id)
        assert_response 403
        match_json(request_error_pattern(:access_denied))
      ensure
        User.any_instance.unstub(:privilege?)
      end

      def test_untranslated_articles
        @portal_id = @account.main_portal.id
        @language = Language.find_by_code('es')
        get :untranslated_articles, controller_params(version: 'private', language: @language.code, portal_id: @portal_id)
        assert_response 200
        untranslated_articles = untranslated_language_articles.first(30)
        pattern = untranslated_articles.map { |article| untranslated_article_pattern(article, @language.code) }
        match_json(pattern)
      end

      def test_update_mark_as_outdated
        languages = @account.supported_languages + ['primary']
        language = @account.supported_languages.first
        article_meta = create_article(article_params(lang_codes: languages))
        params_hash = { outdated: true, status: 2 }
        put :update, construct_params({ version: 'private', id: article_meta.parent_id, language: @account.language }, params_hash)
        assert_response 200
        assert article_meta.reload.children.select { |article| !article.is_primary? && !article.outdated }.empty?
      end

      def test_update_mark_as_uptodate
        languages = @account.supported_languages + ['primary']
        language = @account.supported_languages.first
        article_meta = create_article(article_params(lang_codes: languages))
        article = article_meta.safe_send("#{language}_article")
        article.outdated = true
        article.save
        params_hash = { outdated: false, status: 2 }
        put :update, construct_params({ version: 'private', id: article_meta.parent_id, language: language }, params_hash)
        assert_response 200
        assert !article_meta.reload.safe_send("#{language}_article").outdated
      end

      def test_update_mark_as_outdated_shouldnot_clear_approvals
        Account.any_instance.stubs(:article_approval_workflow_enabled?).returns(true)
        article = get_in_review_article
        params_hash = { outdated: true, status: 1 }
        put :update, construct_params({ version: 'private', id: article.parent_id, language: article.language_code }, params_hash)
        assert_response 200
        assert article.solution_article_meta.reload.children.select { |art| !art.is_primary? && !art.outdated }.empty?
        assert_in_review(article)
      ensure
        Account.any_instance.unstub(:article_approval_workflow_enabled?)
      end

      def test_update_mark_as_outdated_with_only_create_and_update_article
        Account.any_instance.stubs(:article_approval_workflow_enabled?).returns(true)
        User.any_instance.stubs(:privilege?).with(:create_and_edit_article).returns(true)
        User.any_instance.stubs(:privilege?).with(:publish_solution).returns(false)
        User.any_instance.stubs(:privilege?).with(:publish_approved_solution).returns(false)
        User.any_instance.stubs(:privilege?).with(:admin_tasks).returns(false)
        article = get_in_review_article
        params_hash = { outdated: true, status: 1 }
        put :update, construct_params({ version: 'private', id: article.parent_id, language: @account.language }, params_hash)
        assert_response 200
        assert article.solution_article_meta.reload.children.select { |art| !art.is_primary? && !art.outdated }.empty?
        assert_in_review(article)
      ensure
        Account.any_instance.unstub(:article_approval_workflow_enabled?)
        User.any_instance.unstub(:privilege?)
      end

      def test_update_mark_as_uptodate_for_primary_article
        languages = @account.supported_languages + ['primary']
        language = @account.supported_languages.first
        article_meta = create_article(article_params(lang_codes: languages))
        article = article_meta.safe_send("#{language}_article")
        article.outdated = true
        article.save
        params_hash = { outdated: false, status: 2 }
        put :update, construct_params({ version: 'private', id: article_meta.parent_id, language: @account.language }, params_hash)
        assert_response 400
        match_json([bad_request_error_pattern('outdated', :cannot_mark_primary_as_uptodate, code: :invalid_value)])
      end

      def test_bulk_update_publish_without_feature
        Account.any_instance.stubs(:adv_article_bulk_actions_enabled?).returns(false)
        draft = @account.solution_drafts.last
        put :bulk_update, construct_params({ version: 'private' }, ids: [draft.article.parent_id], properties: { status: 2 })
        assert_response 403
        match_json(validation_error_pattern(bad_request_error_pattern('properties[:status]', :require_feature, feature: :adv_article_bulk_actions, code: :access_denied)))
      ensure
        Account.any_instance.unstub(:adv_article_bulk_actions_enabled?)
      end

      def test_bulk_update_publish
        User.any_instance.stubs(:privilege?).with(:publish_approved_solution).returns(true)
        User.any_instance.stubs(:privilege?).with(:create_and_edit_article).returns(true)
        User.any_instance.stubs(:privilege?).with(:publish_solution).returns(true)
        draft = @account.solution_drafts.last
        put :bulk_update, construct_params({ version: 'private' }, ids: [draft.article.parent_id], properties: { status: 2 })
        assert_response 204
        assert_equal draft.article.status, 2
      ensure
        User.any_instance.unstub(:privilege?)
      end

      def test_bulk_update_publish_without_publish_privilege
        User.any_instance.stubs(:privilege?).with(:publish_approved_solution).returns(false)
        User.any_instance.stubs(:privilege?).with(:create_and_edit_article).returns(true)
        User.any_instance.stubs(:privilege?).with(:publish_solution).returns(false)
        draft = @account.solution_drafts.last
        put :bulk_update, construct_params({ version: 'private' }, ids: [draft.article.parent_id], properties: { status: 2 })
        assert_response 400
      ensure
        User.any_instance.unstub(:privilege?)
      end

      def test_bulk_update_publish_without_multilingual_feature
        Account.any_instance.stubs(:multilingual?).returns(false)
        User.any_instance.stubs(:privilege?).with(:create_and_edit_article).returns(true)
        User.any_instance.stubs(:privilege?).with(:publish_solution).returns(true)
        User.any_instance.stubs(:privilege?).with(:publish_approved_solution).returns(true)
        article_title1 = Faker::Lorem.characters(10)
        article_meta1 = create_article(article_params(title: article_title1, status: 1))
        sample_article1 = article_meta1.safe_send('primary_article')
        create_draft(article: sample_article1)
        draft1 = sample_article1.draft
        article_title2 = Faker::Lorem.characters(10)
        article_meta2 = create_article(article_params(title: article_title2, status: 1))
        sample_article2 = article_meta2.safe_send('primary_article')
        create_draft(article: sample_article2)
        draft2 = sample_article2.draft
        put :bulk_update, construct_params({ version: 'private' }, ids: [draft1.article.parent_id, draft2.article.parent_id], properties: { status: 2 })
        assert_response 204
        assert_equal draft1.article.reload.status, 2
        assert_equal draft2.article.reload.status, 2
      ensure
        Account.any_instance.unstub(:multilingual?)
        User.any_instance.unstub(:privilege?)
      end

      def test_bulk_update_publish_with_multilingual_feature
        Account.any_instance.stubs(:multilingual?).returns(true)
        User.any_instance.stubs(:privilege?).with(:create_and_edit_article).returns(true)
        User.any_instance.stubs(:privilege?).with(:publish_solution).returns(true)
        User.any_instance.stubs(:privilege?).with(:publish_approved_solution).returns(true)
        languages = @account.supported_languages + ['primary']
        language  = @account.supported_languages.first
        article_title = Faker::Lorem.characters(10)
        article_meta = create_article(article_params(title: article_title, lang_codes: languages, status: 1))
        sample_article = article_meta.safe_send("#{language}_article")
        create_draft(article: sample_article)
        draft = sample_article.draft
        put :bulk_update, construct_params({ version: 'private', language: language }, ids: [draft.article.parent_id], properties: { status: 2 })
        assert_response 204
        assert_equal draft.article.reload.status, 2
      ensure
        Account.any_instance.unstub(:multilingual?)
        User.any_instance.unstub(:privilege?)
      end

      def test_bulk_update_publish_for_unsupported_language
        Account.any_instance.stubs(:multilingual?).returns(true)
        User.any_instance.stubs(:privilege?).with(:create_and_edit_article).returns(true)
        languages = @account.supported_languages + ['primary']
        unsupported_languages = Language.all.map(&:code).reject { |language| languages.include?(language) }
        language = unsupported_languages.first
        draft = @account.solution_drafts.last
        put :bulk_update, construct_params({ version: 'private', language: language }, ids: [draft.article.parent_id], properties: { status: 2 })
        assert_response 404
      ensure
        Account.any_instance.unstub(:multilingual?)
        User.any_instance.unstub(:privilege?)
      end

      def test_bulk_update_publish_with_invalid_status
        User.any_instance.stubs(:privilege?).with(:create_and_edit_article).returns(true)
        User.any_instance.stubs(:privilege?).with(:publish_solution).returns(true)
        draft = @account.solution_drafts.last
        put :bulk_update, construct_params({ version: 'private' }, ids: [draft.article.parent_id], properties: { status: 1 })
        assert_response 400
      ensure
        User.any_instance.unstub(:privilege?)
      end

      def test_bulk_update_publish_for_article_with_no_draft
        User.any_instance.stubs(:privilege?).with(:create_and_edit_article).returns(true)
        User.any_instance.stubs(:privilege?).with(:publish_solution).returns(true)
        article_title = Faker::Lorem.characters(10)
        article_meta = create_article(article_params(title: article_title, status: 1))
        sample_article = article_meta.safe_send('primary_article')
        sample_article.draft.destroy if sample_article.draft.present?
        put :bulk_update, construct_params({ version: 'private' }, ids: [sample_article.parent_id], properties: { status: 2 })
        assert_response 202
        sample_article.destroy
        article_meta.destroy
      ensure
        User.any_instance.unstub(:privilege?)
      end

      def test_bulk_update_publish_for_article_with_draft_locked
        User.any_instance.stubs(:privilege?).with(:create_and_edit_article).returns(true)
        User.any_instance.stubs(:privilege?).with(:publish_solution).returns(true)
        article_title = Faker::Lorem.characters(10)
        article_meta = create_article(article_params(title: article_title, status: 1))
        sample_article = article_meta.safe_send('primary_article')
        create_draft(article: sample_article)
        draft = sample_article.draft
        Solution::Draft.any_instance.stubs(:locked?).returns(true)
        put :bulk_update, construct_params({ version: 'private' }, ids: [sample_article.parent_id], properties: { status: 2 })
        assert_response 202
        article_meta.destroy
      ensure
        User.any_instance.unstub(:privilege?)
        Solution::Draft.any_instance.unstub(:locked?)
      end

      def test_bulk_update_mark_as_upto_date
        Account.any_instance.stubs(:adv_article_bulk_actions_enabled?).returns(true)
        User.any_instance.stubs(:privilege?).with(:create_and_edit_article).returns(true)
        languages = @account.supported_languages + ['primary']
        language = @account.supported_languages.first
        article_meta = create_article(article_params(lang_codes: languages))
        article = article_meta.safe_send("#{language}_article")
        article.outdated = true
        article.save
        put :bulk_update, construct_params({ version: 'private', language: language }, ids: [article_meta.parent_id], properties: { outdated: false })
        assert_response 204
        assert !article_meta.reload.safe_send("#{language}_article").outdated
      ensure
        Account.any_instance.unstub(:adv_article_bulk_actions_enabled?)
        User.any_instance.unstub(:privilege?)
      end

      def test_bulk_update_mark_as_upto_date_without_adv_article_bulk_actions_feature
        Account.any_instance.stubs(:adv_article_bulk_actions_enabled?).returns(false)
        languages = @account.supported_languages + ['primary']
        language = @account.supported_languages.first
        article_meta = create_article(article_params(lang_codes: languages))
        article = article_meta.safe_send("#{language}_article")
        article.outdated = true
        article.save
        put :bulk_update, construct_params({ version: 'private', language: language }, ids: [article_meta.parent_id], properties: { outdated: false })
        assert_response 403
        match_json(validation_error_pattern(bad_request_error_pattern('properties[:outdated]', :require_feature, feature: :adv_article_bulk_actions, code: :access_denied)))
      ensure
        Account.any_instance.unstub(:adv_article_bulk_actions_enabled?)
      end

      def test_bulk_update_mark_as_upto_date_without_privilege
        Account.any_instance.stubs(:adv_article_bulk_actions_enabled?).returns(true)
        User.any_instance.stubs(:privilege?).with(:create_and_edit_article).returns(false)
        User.any_instance.stubs(:privilege?).with(:approve_article).returns(false)
        languages = @account.supported_languages + ['primary']
        language = @account.supported_languages.first
        article_meta = create_article(article_params(lang_codes: languages))
        article = article_meta.safe_send("#{language}_article")
        article.outdated = true
        article.save
        put :bulk_update, construct_params({ version: 'private', language: language }, ids: [article_meta.parent_id], properties: { outdated: false })
        assert_response 403
      ensure
        Account.any_instance.unstub(:adv_article_bulk_actions_enabled?)
        User.any_instance.unstub(:privilege?)
      end

      def test_bulk_update_mark_as_upto_date_with_wrong_parameters
        Account.any_instance.stubs(:adv_article_bulk_actions_enabled?).returns(true)
        User.any_instance.stubs(:privilege?).with(:create_and_edit_article).returns(true)
        languages = @account.supported_languages + ['primary']
        language = @account.supported_languages.first
        article_meta = create_article(article_params(lang_codes: languages))
        article = article_meta.safe_send("#{language}_article")
        article.outdated = true
        article.save
        put :bulk_update, construct_params({ version: 'private', language: language }, ids: [article_meta.parent_id], properties: { outdated: true })
        assert_response 400
      ensure
        Account.any_instance.unstub(:adv_article_bulk_actions_enabled?)
        User.any_instance.unstub(:privilege?)
      end

      def test_bulk_update_mark_as_upto_date_already_upto_date_articles
        Account.any_instance.stubs(:adv_article_bulk_actions_enabled?).returns(true)
        User.any_instance.stubs(:privilege?).with(:create_and_edit_article).returns(true)
        languages = @account.supported_languages + ['primary']
        language = @account.supported_languages.first
        article_meta = create_article(article_params(lang_codes: languages))
        article = article_meta.safe_send("#{language}_article")
        article.save
        put :bulk_update, construct_params({ version: 'private', language: language }, ids: [article_meta.parent_id], properties: { outdated: false })
        assert_response 204
      ensure
        Account.any_instance.unstub(:adv_article_bulk_actions_enabled?)
        User.any_instance.unstub(:privilege?)
      end

      def test_create_article_with_emoji_content_in_description_and_title_with_encode_emoji_enabled
        Account.current.launch(:encode_emoji_in_solutions)
        folder_meta = get_folder_meta
        title = '<span> hey 👋 there ⛺️😅💁🏿‍♀️👨‍👨‍👧‍👧this is title with emoji </span>'
        paragraph = '<span> hey 👋 there ⛺️😅💁🏿‍♀️👨‍👨‍👧‍👧this is line after emoji </span>'
        post :create, construct_params({ version: 'private', id: folder_meta.id }, title: title, description: paragraph, status: 2)
        paragraph_with_emoji_enabled = UnicodeSanitizer.utf84b_html_c(paragraph)
        paragraph_with_emoji_disabled = UnicodeSanitizer.remove_4byte_chars(paragraph)
        paragraph_desc_un_html = Helpdesk::HTMLSanitizer.plain(paragraph_with_emoji_disabled)
        assert_equal Solution::Article.last.description, paragraph_with_emoji_enabled
        assert_equal Solution::Article.last.desc_un_html, paragraph_desc_un_html
        assert_response 201
        match_json(private_api_solution_article_pattern(Solution::Article.last))
      ensure
        Account.current.rollback(:encode_emoji_in_solutions)
      end

      def test_update_article_with_emoji_content_in_description_and_title_with_encode_emoji_enabled
        Account.current.launch(:encode_emoji_in_solutions)
        sample_article = get_article_without_draft
        title = '<span> hey 👋 there ⛺️😅💁🏿‍♀️👨‍👨‍👧‍👧this is title with emoji </span>'
        paragraph = '<span> hey 👋 there ⛺️😅💁🏿‍♀️👨‍👨‍👧‍👧this is line after emoji </span>'
        params_hash = { title: title, description: paragraph, status: 2 }
        put :update, construct_params({ version: 'private', id: sample_article.parent_id }, params_hash)
        paragraph_with_emoji_enabled = UnicodeSanitizer.utf84b_html_c(paragraph)
        paragraph_with_emoji_disabled = UnicodeSanitizer.remove_4byte_chars(paragraph)
        paragraph_desc_un_html = Helpdesk::HTMLSanitizer.plain(paragraph_with_emoji_disabled)
        assert_equal sample_article.reload.description, paragraph_with_emoji_enabled
        assert_equal sample_article.reload.desc_un_html, paragraph_desc_un_html
        assert_response 200
        match_json(private_api_solution_article_pattern(sample_article.reload))
      ensure
        Account.current.rollback(:encode_emoji_in_solutions)
      end

      def test_create_draft_with_emoji_content_in_description_and_title_with_encode_emoji_enabled
        Account.current.launch(:encode_emoji_in_solutions)
        folder_meta = get_folder_meta
        title = '<span> hey 👋 there ⛺️😅💁🏿‍♀️👨‍👨‍👧‍👧this is title with emoji </span>'
        paragraph = '<span> hey 👋 there ⛺️😅💁🏿‍♀️👨‍👨‍👧‍👧this is line after emoji </span>'
        post :create, construct_params({ version: 'private', id: folder_meta.id }, title: title, description: paragraph, status: 1)
        paragraph_with_emoji_enabled = UnicodeSanitizer.utf84b_html_c(paragraph)
        assert_equal Solution::Article.last.draft.description, paragraph_with_emoji_enabled
        assert_response 201
        match_json(private_api_solution_article_pattern(Solution::Article.last))
      ensure
        Account.current.rollback(:encode_emoji_in_solutions)
      end

      def test_update_draft_with_emoji_content_in_description_and_title_with_encode_emoji_enabled
        Account.current.launch(:encode_emoji_in_solutions)
        sample_article = get_article_without_draft
        title = '<span> hey 👋 there ⛺️😅💁🏿‍♀️👨‍👨‍👧‍👧this is title with emoji </span>'
        paragraph = '<span> hey 👋 there ⛺️😅💁🏿‍♀️👨‍👨‍👧‍👧this is line after emoji </span>'
        params_hash = { title: title, description: paragraph, status: 1 }
        put :update, construct_params({ version: 'private', id: sample_article.parent_id }, params_hash)
        paragraph_with_emoji_enabled = UnicodeSanitizer.utf84b_html_c(paragraph)
        assert_equal sample_article.reload.draft.description, paragraph_with_emoji_enabled
        assert_response 200
        match_json(private_api_solution_article_pattern(sample_article.reload))
      ensure
        Account.current.rollback(:encode_emoji_in_solutions)
      end

      def test_create_article_with_emoji_content_in_description_and_title_with_encode_emoji_disabled
        Account.current.rollback(:encode_emoji_in_solutions)
        folder_meta = get_folder_meta
        title = '<span> hey 👋 there ⛺️😅💁🏿‍♀️👨‍👨‍👧‍👧this is title with emoji </span>'
        paragraph = '<span> hey 👋 there ⛺️😅💁🏿‍♀️👨‍👨‍👧‍👧this is line after emoji </span>'
        post :create, construct_params({ version: 'private', id: folder_meta.id }, title: title, description: paragraph, status: 2)
        paragraph_with_emoji_disabled = UnicodeSanitizer.remove_4byte_chars(paragraph)
        paragraph_desc_un_html = Helpdesk::HTMLSanitizer.plain(paragraph_with_emoji_disabled)
        assert_equal Solution::Article.last.description, paragraph_with_emoji_disabled
        assert_equal Solution::Article.last.desc_un_html, paragraph_desc_un_html
        assert_response 201
        match_json(private_api_solution_article_pattern(Solution::Article.last))
      end

      def test_update_article_with_emoji_content_in_description_and_title_with_encode_emoji_disabled
        Account.current.rollback(:encode_emoji_in_solutions)
        sample_article = get_article_without_draft
        title = '<span> hey 👋 there ⛺️😅💁🏿‍♀️👨‍👨‍👧‍👧this is title with emoji </span>'
        paragraph = '<span> hey 👋 there ⛺️😅💁🏿‍♀️👨‍👨‍👧‍👧this is line after emoji </span>'
        params_hash = { title: title, description: paragraph, status: 2 }
        put :update, construct_params({ version: 'private', id: sample_article.parent_id }, params_hash)
        paragraph_with_emoji_disabled = UnicodeSanitizer.remove_4byte_chars(paragraph)
        paragraph_desc_un_html = Helpdesk::HTMLSanitizer.plain(paragraph_with_emoji_disabled)
        assert_equal sample_article.reload.description, paragraph_with_emoji_disabled
        assert_equal sample_article.reload.desc_un_html, paragraph_desc_un_html
        assert_response 200
        match_json(private_api_solution_article_pattern(sample_article.reload))
      end

      def test_create_draft_with_emoji_content_in_description_and_title_with_encode_emoji_disabled
        Account.current.rollback(:encode_emoji_in_solutions)
        folder_meta = get_folder_meta
        title = '<span> hey 👋 there ⛺️😅💁🏿‍♀️👨‍👨‍👧‍👧this is title with emoji </span>'
        paragraph = '<span> hey 👋 there ⛺️😅💁🏿‍♀️👨‍👨‍👧‍👧this is line after emoji </span>'
        post :create, construct_params({ version: 'private', id: folder_meta.id }, title: title, description: paragraph, status: 1)
        paragraph_with_emoji_disabled = UnicodeSanitizer.remove_4byte_chars(paragraph)
        assert_equal Solution::Article.last.draft.description, paragraph_with_emoji_disabled
        assert_response 201
        match_json(private_api_solution_article_pattern(Solution::Article.last))
      end

      def test_update_draft_with_emoji_content_in_description_and_title_with_encode_emoji_disabled
        Account.current.rollback(:encode_emoji_in_solutions)
        sample_article = get_article_without_draft
        title = '<span> hey 👋 there ⛺️😅💁🏿‍♀️👨‍👨‍👧‍👧this is title with emoji </span>'
        paragraph = '<span> hey 👋 there ⛺️😅💁🏿‍♀️👨‍👨‍👧‍👧this is line after emoji </span>'
        params_hash = { title: title, description: paragraph, status: 1 }
        put :update, construct_params({ version: 'private', id: sample_article.parent_id }, params_hash)
        paragraph_with_emoji_disabled = UnicodeSanitizer.remove_4byte_chars(paragraph)
        assert_equal sample_article.reload.draft.description, paragraph_with_emoji_disabled
        assert_response 200
        match_json(private_api_solution_article_pattern(sample_article.reload))
      end

      def test_article_sanitization_in_drafts
        folder_meta = get_folder_meta
        title = Faker::Name.name
        paragraph = '<span> This is a paragraph </span><script>alert(ALERT!)</script>'
        post :create, construct_params({ version: 'private', id: folder_meta.id }, title: title, description: paragraph, status: 1)
        paragraph = '<span> This is a paragraph </span>'
        assert_equal Solution::Article.last.draft.description, paragraph
        assert_response 201
        match_json(private_api_solution_article_pattern(Solution::Article.last))
      end

      def test_article_sanitization_in_articles
        folder_meta = get_folder_meta
        title = Faker::Name.name
        paragraph = '<span> This is a paragraph </span><script>alert(ALERT!)</script>'
        post :create, construct_params({ version: 'private', id: folder_meta.id }, title: title, description: paragraph, status: 2)
        paragraph = '<span> This is a paragraph </span>'
        assert_equal Solution::Article.last.description, paragraph
        assert_response 201
        match_json(private_api_solution_article_pattern(Solution::Article.last))
      end

      def test_create_article_review_record
        Account.any_instance.stubs(:article_approval_workflow_enabled?).returns(true)
        sample_article = get_article_with_draft
        approver = add_test_agent
        add_privilege(approver, :approve_article)
        User.current.reload
        remove_privilege(User.current, :publish_solution)
        Solution::Article.any_instance.expects(:approval_callback).once
        post :send_for_review, construct_params({ version: 'private', id: sample_article.parent_id }, approver_id: approver.id)
        assert_response 204
        approval_record = approval_record(sample_article)
        approver_mapping = approver_record(sample_article)
        assert approval_record
        assert approver_mapping
        assert_equal approval_record.approval_status, Helpdesk::ApprovalConstants::STATUS_KEYS_BY_TOKEN[:in_review]
        assert_equal approval_record.approvable_id, sample_article.id
        assert_equal approval_record.approvable_type, 'Solution::Article'
        assert_equal approval_record.user_id, User.current.id
        assert_equal approval_record.account_id, Account.current.id
        assert_equal approver_mapping.approver_id, approver.id
        assert_equal approver_mapping.approval_status, Helpdesk::ApprovalConstants::STATUS_KEYS_BY_TOKEN[:in_review]
        assert_equal approver_mapping.account_id, Account.current.id
        assert_equal approver_mapping.approval_id, approval_record.id
      ensure
        Account.any_instance.unstub(:article_approval_workflow_enabled?)
        add_privilege(User.current, :publish_solution)
      end

      def test_send_for_review_sends_notification
        Account.any_instance.stubs(:article_approval_workflow_enabled?).returns(true)
        sample_article = get_article_with_draft
        approver = add_test_agent
        add_privilege(approver, :approve_article)
        User.current.reload
        Solution::ApprovalNotificationWorker.expects(:perform_async).once
        post :send_for_review, construct_params({ version: 'private', id: sample_article.parent_id }, approver_id: approver.id)
        assert_response 204
      ensure
        Account.any_instance.unstub(:article_approval_workflow_enabled?)
      end

      def test_create_article_review_record_without_create_article_permission
        Account.any_instance.stubs(:article_approval_workflow_enabled?).returns(true)
        sample_article = get_article_with_draft
        approver = add_test_agent
        # add_privilege(approver, :approve_article)
        # remove_privilege(User.current, :create_and_edit_article)
        User.any_instance.stubs(:privilege?).with(:create_and_edit_article).returns(false)
        User.any_instance.stubs(:privilege?).with(:approve_article).returns(true)
        User.current.reload
        post :send_for_review, construct_params({ version: 'private', id: sample_article.parent_id }, approver_id: approver.id)
        User.any_instance.unstub(:privilege?)
        assert_response 403
      ensure
        Account.any_instance.unstub(:article_approval_workflow_enabled?)
        add_privilege(User.current, :create_and_edit_article)
      end

      def test_create_article_review_record_without_approval_permission
        Account.any_instance.stubs(:article_approval_workflow_enabled?).returns(true)
        sample_article = get_article_with_draft
        approver = add_test_agent
        remove_privilege(approver, :approve_article)
        User.current.reload
        remove_privilege(User.current, :publish_solution)
        post :send_for_review, construct_params({ version: 'private', id: sample_article.parent_id }, approver_id: approver.id)
        assert_response 400
      ensure
        Account.any_instance.unstub(:article_approval_workflow_enabled?)
        add_privilege(User.current, :publish_solution)
      end

      def test_create_article_review_record_for_published_article
        Account.any_instance.stubs(:article_approval_workflow_enabled?).returns(true)
        sample_article = get_article_without_draft
        approver = add_test_agent
        add_privilege(approver, :approve_article)
        User.current.reload
        remove_privilege(User.current, :publish_solution)
        post :send_for_review, construct_params({ version: 'private', id: sample_article.parent_id }, approver_id: approver.id)
        assert_response 400
      ensure
        Account.any_instance.unstub(:article_approval_workflow_enabled?)
        add_privilege(User.current, :publish_solution)
      end

      def test_create_article_review_record_without_feature
        Account.any_instance.stubs(:article_approval_workflow_enabled?).returns(false)
        sample_article = get_article_with_draft
        approver = add_test_agent
        add_privilege(approver, :approve_article)
        User.current.reload
        remove_privilege(User.current, :publish_solution)
        post :send_for_review, construct_params({ version: 'private', id: sample_article.parent_id }, approver_id: approver.id)
        assert_response 403
      ensure
        Account.any_instance.unstub(:article_approval_workflow_enabled?)
        add_privilege(User.current, :publish_solution)
      end

      def test_update_article_review_record
        Account.any_instance.stubs(:article_approval_workflow_enabled?).returns(true)
        sample_article = get_article_with_draft
        approver = add_test_agent
        add_privilege(approver, :approve_article)
        User.current.reload
        remove_privilege(User.current, :publish_solution)
        post :send_for_review, construct_params({ version: 'private', id: sample_article.parent_id }, approver_id: approver.id)
        assert_response 204
        approval_record = approval_record(sample_article)
        approver_mapping = approver_record(sample_article)
        assert approval_record
        assert approver_mapping
        assert_equal approver_mapping.approver_id, approver.id
      ensure
        Account.any_instance.unstub(:article_approval_workflow_enabled?)
        add_privilege(User.current, :publish_solution)
      end

      def test_create_article_review_record_with_not_supported_language
        Account.any_instance.stubs(:article_approval_workflow_enabled?).returns(false)
        sample_article = get_article_with_draft
        approver = add_test_agent
        add_privilege(approver, :approve_article)
        non_supported_language = get_valid_not_supported_language
        post :send_for_review, construct_params({ version: 'private', id: sample_article.id, language: non_supported_language }, approver_id: approver.id)
        match_json(request_error_pattern(:language_not_allowed, code: non_supported_language, list: (@account.supported_languages + [@account.language]).sort.join(', ')))
        assert_response 404
      ensure
        Account.any_instance.unstub(:article_approval_workflow_enabled?)
      end

      def test_create_article_review_record_with_invalid_language
        Account.any_instance.stubs(:article_approval_workflow_enabled?).returns(false)
        sample_article = get_article_with_draft
        approver = add_test_agent
        add_privilege(approver, :approve_article)
        post :send_for_review, construct_params({ version: 'private', id: sample_article.id, language: 'demo' }, approver_id: approver.id)
        assert_response 404
      ensure
        Account.any_instance.unstub(:article_approval_workflow_enabled?)
      end

      def test_create_article_review_record_when_someone_is_editing
        Account.any_instance.stubs(:article_approval_workflow_enabled?).returns(true)
        Solution::Draft.any_instance.stubs(:locked?).returns(true)
        sample_article = get_article_with_draft
        approver = add_test_agent
        add_privilege(approver, :approve_article)
        User.current.reload
        remove_privilege(User.current, :publish_solution)
        post :send_for_review, construct_params({ version: 'private', id: sample_article.parent_id }, approver_id: approver.id)
        assert_response 400
      ensure
        Account.any_instance.unstub(:article_approval_workflow_enabled?)
        Solution::Draft.any_instance.unstub(:locked?)
        add_privilege(User.current, :publish_solution)
      end

      def test_approve_without_approve_privilege
        Account.any_instance.stubs(:article_approval_workflow_enabled?).returns(true)
        sample_article = get_article_with_draft
        approver = add_test_agent
        # remove_privilege(User.current, :approve_article)
        # User.current.reload
        User.any_instance.stubs(:privilege?).with(:approve_article).returns(false)
        post :approve, controller_params(version: 'private', id: sample_article.parent_id)
        assert_response 403, response.body
        User.any_instance.unstub(:privilege?)
        match_json(request_error_pattern(:access_denied))
      ensure
        Account.any_instance.unstub(:article_approval_workflow_enabled?)
      end

      def test_approve_without_feature
        Account.any_instance.stubs(:article_approval_workflow_enabled?).returns(false)
        sample_article = get_article_with_draft
        approver = add_test_agent
        add_privilege(User.current, :approve_article)
        User.current.reload
        post :approve, controller_params(version: 'private', id: sample_article.parent_id)
        assert_response 403
      ensure
        Account.any_instance.unstub(:article_approval_workflow_enabled?)
      end

      def test_approve_with_not_supported_language
        Account.any_instance.stubs(:article_approval_workflow_enabled?).returns(false)
        sample_article = get_article_with_draft
        approver = add_test_agent
        add_privilege(User.current, :approve_article)
        User.current.reload
        non_supported_language = get_valid_not_supported_language
        post :approve, controller_params(version: 'private', id: sample_article.parent_id, language: non_supported_language)
        match_json(request_error_pattern(:language_not_allowed, code: non_supported_language, list: (@account.supported_languages + [@account.language]).sort.join(', ')))
        assert_response 404
      ensure
        Account.any_instance.unstub(:article_approval_workflow_enabled?)
      end

      def test_approve_with_invalid_langauge
        Account.any_instance.stubs(:article_approval_workflow_enabled?).returns(false)
        sample_article = get_article_with_draft
        approver = add_test_agent
        add_privilege(User.current, :approve_article)
        User.current.reload
        post :approve, controller_params(version: 'private', id: sample_article.parent_id, language: 'demo')
        assert_response 404
      ensure
        Account.any_instance.unstub(:article_approval_workflow_enabled?)
      end

      def test_approve_article
        Account.any_instance.stubs(:article_approval_workflow_enabled?).returns(true)
        approver = add_test_agent
        add_privilege(User.current, :approve_article)
        User.current.reload
        sample_article = get_in_review_article
        Solution::Article.any_instance.expects(:approval_callback).once
        post :approve, controller_params(version: 'private', id: sample_article.parent_id)
        assert_response 204
        assert sample_article.helpdesk_approval.approval_status == Helpdesk::ApprovalConstants::STATUS_KEYS_BY_TOKEN[:approved]
        assert sample_article.helpdesk_approval.approved?
      ensure
        Account.any_instance.unstub(:article_approval_workflow_enabled?)
      end

      def test_approve_article_triggers_notification
        Account.any_instance.stubs(:article_approval_workflow_enabled?).returns(true)
        approver = add_test_agent
        add_privilege(User.current, :approve_article)
        User.current.reload
        sample_article = get_in_review_article
        Solution::ApprovalNotificationWorker.expects(:perform_async).once
        post :approve, controller_params(version: 'private', id: sample_article.parent_id)
        assert_response 204
      ensure
        Account.any_instance.unstub(:article_approval_workflow_enabled?)
      end

      def test_approve_article_with_language_code
        Account.any_instance.stubs(:article_approval_workflow_enabled?).returns(true)
        approver = add_test_agent
        add_privilege(User.current, :approve_article)
        User.current.reload
        sample_article = get_in_review_article(Account.current.language_object)
        post :approve, controller_params(version: 'private', id: sample_article.parent_id, language: Account.current.language_object.code)
        assert_response 204
        assert sample_article.helpdesk_approval.approval_status == Helpdesk::ApprovalConstants::STATUS_KEYS_BY_TOKEN[:approved]
        assert sample_article.helpdesk_approval.approved?
      ensure
        Account.any_instance.unstub(:article_approval_workflow_enabled?)
      end

      def test_approve_article_without_approval_record
        article = create_article(article_params)
        Account.any_instance.stubs(:article_approval_workflow_enabled?).returns(true)
        approver = add_test_agent
        add_privilege(User.current, :approve_article)
        User.current.reload
        post :approve, controller_params(version: 'private', id: article.id, language: Account.current.language_object.code)
        assert_response 404
      ensure
        Account.any_instance.unstub(:article_approval_workflow_enabled?)
      end

      def test_create_article_review_record_with_invalid_user
        Account.any_instance.stubs(:article_approval_workflow_enabled?).returns(true)
        sample_article = get_article_with_draft
        User.current.reload
        remove_privilege(User.current, :publish_solution)
        post :send_for_review, construct_params({ version: 'private', id: sample_article.parent_id }, approver_id: 9999)
        assert_response 400
      ensure
        Account.any_instance.unstub(:article_approval_workflow_enabled?)
        add_privilege(User.current, :publish_solution)
      end

      # agent without publish solution privileges tests

      def test_approve_with_invalid_language
        Account.any_instance.stubs(:article_approval_workflow_enabled?).returns(false)
        sample_article = get_article_with_draft
        approver = add_test_agent
        add_privilege(User.current, :approve_article)
        User.current.reload
        post :approve, controller_params(version: 'private', id: sample_article.parent_id, language: 'demo')
        assert_response 404
      ensure
        Account.any_instance.unstub(:article_approval_workflow_enabled?)
      end

      def test_update_draft_article_folder_with_approval_record
        Account.any_instance.stubs(:article_approval_workflow_enabled?).returns(true)
        sample_article = get_unpublished_approved_article
        lang_hash = { lang_codes: all_account_languages }
        category = create_category({ portal_id: Account.current.main_portal.id }.merge(lang_hash))
        new_folder_id = create_folder({ visibility: Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:anyone], category_id: category.id }.merge(lang_hash)).id
        params_hash = { status: 1, folder_id: new_folder_id }
        put :update, construct_params({ version: 'private', id: sample_article.parent_id }, params_hash)
        assert_response 200
        sample_article.reload
        match_json(private_api_solution_article_pattern(sample_article))
        assert_no_approval sample_article
      ensure
        Account.any_instance.unstub(:article_approval_workflow_enabled?)
      end

      def test_approve_article
        Account.any_instance.stubs(:article_approval_workflow_enabled?).returns(true)
        approver = add_test_agent
        add_privilege(User.current, :approve_article)
        User.current.reload
        sample_article = get_in_review_article
        post :approve, controller_params(version: 'private', id: sample_article.parent_id)
        assert_response 204
        assert sample_article.helpdesk_approval.approval_status == Helpdesk::ApprovalConstants::STATUS_KEYS_BY_TOKEN[:approved]
        assert sample_article.helpdesk_approval.approved?
      ensure
        Account.any_instance.unstub(:article_approval_workflow_enabled?)
      end

      def test_approve_article_with_language_code
        Account.any_instance.stubs(:article_approval_workflow_enabled?).returns(true)
        approver = add_test_agent
        add_privilege(User.current, :approve_article)
        User.current.reload
        sample_article = get_in_review_article(Account.current.language_object)
        post :approve, controller_params(version: 'private', id: sample_article.parent_id, language: Account.current.language_object.code)
        assert_response 204
        assert sample_article.helpdesk_approval.approval_status == Helpdesk::ApprovalConstants::STATUS_KEYS_BY_TOKEN[:approved]
        assert sample_article.helpdesk_approval.approved?
      ensure
        Account.any_instance.unstub(:article_approval_workflow_enabled?)
      end

      def test_approve_article_without_approval_record
        article = create_article(article_params)
        Account.any_instance.stubs(:article_approval_workflow_enabled?).returns(true)
        approver = add_test_agent
        add_privilege(User.current, :approve_article)
        User.current.reload
        post :approve, controller_params(version: 'private', id: article.id, language: Account.current.language_object.code)
        assert_response 404
      ensure
        Account.any_instance.unstub(:article_approval_workflow_enabled?)
      end

      # agent without publish solution privileges tests
      def test_update_draft_article_folder_without_publish_solution_privilege
        without_publish_solution_privilege do
          User.any_instance.stubs(:privilege?).with(:publish_approved_solution).returns(true)
          sample_article = create_article(article_params(lang_codes: all_account_languages).merge(status: 1)).primary_article
          lang_hash = { lang_codes: all_account_languages }
          category = create_category({ portal_id: Account.current.main_portal.id }.merge(lang_hash))
          new_folder_id = create_folder({ visibility: Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:anyone], category_id: category.id }.merge(lang_hash)).id
          params_hash = { status: 1, folder_id: new_folder_id }
          put :update, construct_params({ version: 'private', id: sample_article.parent_id }, params_hash)
          assert_response 200
          sample_article.reload
          match_json(private_api_solution_article_pattern(sample_article))
        end
      ensure
        User.any_instance.unstub(:privilege?)
      end

      def test_update_published_article_folder_without_publish_solution_privilege
        without_publish_solution_privilege do
          User.any_instance.stubs(:privilege?).with(:publish_approved_solution).returns(true)
          sample_article = create_article(article_params(lang_codes: all_account_languages).merge(status: 2)).primary_article
          lang_hash = { lang_codes: all_account_languages }
          category = create_category({ portal_id: Account.current.main_portal.id }.merge(lang_hash))
          new_folder_id = create_folder({ visibility: Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:anyone], category_id: category.id }.merge(lang_hash)).id
          params_hash = { status: 1, folder_id: new_folder_id }
          put :update, construct_params({ version: 'private', id: sample_article.parent_id }, params_hash)
          assert_response 403
          error_info_hash = { details: 'dont have permission to perfom on published article' }
          match_json(request_error_pattern_with_info(:published_article_privilege_error, error_info_hash, error_info_hash))
        end
      ensure
        User.any_instance.unstub(:privilege?)
      end

      def test_update_draft_article_tags_without_publish_solution_privilege
        without_publish_solution_privilege do
          User.any_instance.stubs(:privilege?).with(:publish_approved_solution).returns(true)
          User.any_instance.stubs(:privilege?).with(:create_tags).returns(true)
          sample_article = create_article(article_params(lang_codes: all_account_languages).merge(status: 1)).primary_article
          params_hash = { status: 1, tags: ['sample tag1', 'sample tag2'] }
          put :update, construct_params({ version: 'private', id: sample_article.parent_id }, params_hash)
          assert_response 200
          sample_article.reload
          match_json(private_api_solution_article_pattern(sample_article))
        end
      ensure
        User.any_instance.unstub(:privilege?)
      end

      def test_update_published_article_tags_without_publish_solution_privilege
        without_publish_solution_privilege do
          User.any_instance.stubs(:privilege?).with(:create_tags).returns(true)
          User.any_instance.stubs(:privilege?).with(:publish_approved_solution).returns(true)
          sample_article = create_article(article_params(lang_codes: all_account_languages).merge(status: 2)).primary_article
          params_hash = { status: 1, tags: ['sample tag1', 'sample tag2'] }
          put :update, construct_params({ version: 'private', id: sample_article.parent_id }, params_hash)
          assert_response 403
          error_info_hash = { details: 'dont have permission to perfom on published article' }
          match_json(request_error_pattern_with_info(:published_article_privilege_error, error_info_hash, error_info_hash))
        end
      ensure
        User.any_instance.unstub(:privilege?)
      end

      def test_unpublish_a_published_article_without_publish_solution_privilege
        without_publish_solution_privilege do
          User.any_instance.stubs(:privilege?).with(:publish_approved_solution).returns(true)
          sample_article = create_article(article_params(lang_codes: all_account_languages).merge(status: 2)).primary_article
          params_hash = { status: 1 }
          put :update, construct_params({ version: 'private', id: sample_article.parent_id }, params_hash)
          assert_response 403
          error_info_hash = { details: 'dont have permission to perfom on published article' }
          match_json(request_error_pattern_with_info(:published_article_privilege_error, error_info_hash, error_info_hash))
        end
      ensure
        User.any_instance.unstub(:privilege?)
      end

      def test_create_and_publish_article_without_publish_solution_privilege
        without_publish_solution_privilege do
          folder_meta = get_folder_meta
          title = Faker::Name.name
          paragraph = Faker::Lorem.paragraph
          post :create, construct_params({ version: 'private', id: folder_meta.id }, title: title, description: paragraph, status: 2)
          assert_response 403
          error_info_hash = { details: 'dont have permission to perfom on published article' }
          match_json(request_error_pattern_with_info(:published_article_privilege_error, error_info_hash, error_info_hash))
        end
      end

      def test_create_a_draft_article_without_publish_solution_privilege
        without_publish_solution_privilege do
          folder_meta = get_folder_meta
          title = Faker::Name.name
          paragraph = Faker::Lorem.paragraph
          post :create, construct_params({ version: 'private', id: folder_meta.id }, title: title, description: paragraph, status: 1)
          assert_response 201
          assert Solution::Article.last.draft
          match_json(private_api_solution_article_pattern(Solution::Article.last))
        end
      end

      def test_update_draft_article_author_without_publish_solution_privilege
        without_publish_solution_privilege do
          User.any_instance.stubs(:privilege?).with(:publish_approved_solution).returns(true)
          sample_article = create_article(article_params(lang_codes: all_account_languages).merge(status: 1)).primary_article
          params_hash = { title: 'publish without draft title', status: 1, agent_id: @agent.id }
          put :update, construct_params({ version: 'private', id: sample_article.parent_id, agent_id: @agent.id }, params_hash)
          assert_response 200
          sample_article.reload
          match_json(private_api_solution_article_pattern(sample_article))
        end
      ensure
        User.any_instance.unstub(:privilege?)
      end

      def test_update_published_article_author_without_publish_solution_privilege
        without_publish_solution_privilege do
          User.any_instance.stubs(:privilege?).with(:publish_approved_solution).returns(true)
          sample_article = get_article_with_draft
          params_hash = { title: 'publish without draft title', status: 2, agent_id: @agent.id }
          put :update, construct_params({ version: 'private', id: sample_article.parent_id, agent_id: @agent.id }, params_hash)
          assert_response 403
          error_info_hash = { details: 'dont have permission to perfom on published article' }
          match_json(request_error_pattern_with_info(:published_article_privilege_error, error_info_hash, error_info_hash))
        end
      ensure
        User.any_instance.unstub(:privilege?)
      end

      def test_save_on_draft_without_dirty_changes_should_unlock_draft
        sample_article = get_article_with_draft
        params_hash = { status: 1, unlock: true }
        put :update, construct_params({ version: 'private', id: sample_article.parent_id }, params_hash)
        assert_response 200
        add_test_agent.make_current
        assert_equal sample_article.reload.draft.locked?, false
      end

      def test_save_on_article_without_dirty_changes_should_unlock_draft
        sample_article = get_article_without_draft
        params_hash = { status: 1, unlock: true }
        put :update, construct_params({ version: 'private', id: sample_article.parent_id }, params_hash)
        assert_response 200
        add_test_agent.make_current
        assert_equal sample_article.reload.draft.locked?, false
      end

      def test_save_on_new_draft_without_dirty_changes_should_unlock_draft
        meta_article = create_article(article_params(lang_codes: all_account_languages, status: 1))
        article = meta_article.primary_article
        draft = create_draft(article: article)
        params_hash = { status: 1, unlock: true }
        put :update, construct_params({ version: 'private', id: article.parent_id }, params_hash)
        assert_response 200
        add_test_agent.make_current
        assert_equal article.reload.draft.locked?, false
      end

      def test_update_publish_reviewed_article_with_publish_approved_solution
        without_publish_solution_privilege do
          Account.any_instance.stubs(:article_approval_workflow_enabled?).returns(true)
          User.any_instance.stubs(:privilege?).with(:publish_approved_solution).returns(true)
          sample_article = get_unpublished_approved_article
          params_hash = { status: 2 }
          put :update, construct_params({ version: 'private', id: sample_article.parent_id }, params_hash)
          assert_response 200
          sample_article.reload
          match_json(private_api_solution_article_pattern(sample_article))
          assert sample_article.published?
          assert !sample_article.draft_present?
        end
      ensure
        Account.any_instance.unstub(:article_approval_workflow_enabled?)
      end

      def test_update_publish_reviewed_article_without_publish_approved_solution
        without_publish_solution_privilege do
          Account.any_instance.stubs(:article_approval_workflow_enabled?).returns(true)
          User.any_instance.stubs(:privilege?).with(:publish_approved_solution).returns(false)
          sample_article = get_unpublished_approved_article
          params_hash = { status: 2 }
          put :update, construct_params({ version: 'private', id: sample_article.parent_id, agent_id: @agent.id }, params_hash)
          assert_response 403
          error_info_hash = { details: 'dont have permission to perfom on published article' }
          match_json(request_error_pattern_with_info(:published_article_privilege_error, error_info_hash, error_info_hash))
        end
      ensure
        Account.any_instance.unstub(:article_approval_workflow_enabled?)
      end

      def test_bulk_update_send_for_review_without_bulk_feature
        Account.any_instance.stubs(:adv_article_bulk_actions_enabled?).returns(false)
        Account.any_instance.stubs(:article_approval_workflow_enabled?).returns(true)
        draft = @account.solution_drafts.last
        approver = add_test_agent
        add_privilege(approver, :approve_article)
        put :bulk_update, construct_params({ version: 'private' }, ids: [draft.article.parent_id], properties: { approval_status: 1, approver_id: approver.id })
        assert_response 403
        match_json(validation_error_pattern(bad_request_error_pattern('properties[:approval_status]', :require_feature, feature: :adv_article_bulk_actions, code: :access_denied)))
      ensure
        Account.any_instance.unstub(:adv_article_bulk_actions_enabled?)
        Account.any_instance.unstub(:article_approval_workflow_enabled?)
      end

      def test_bulk_update_send_for_review_without_approval_workflow
        Account.any_instance.stubs(:adv_article_bulk_actions_enabled?).returns(true)
        Account.any_instance.stubs(:article_approval_workflow_enabled?).returns(false)
        draft = @account.solution_drafts.last
        approver = add_test_agent
        add_privilege(approver, :approve_article)
        put :bulk_update, construct_params({ version: 'private' }, ids: [draft.article.parent_id], properties: { approval_status: 1, approver_id: approver.id })
        assert_response 403
        match_json(validation_error_pattern(bad_request_error_pattern('properties', :require_feature, feature: :article_approval_workflow, code: :access_denied)))
      ensure
        Account.any_instance.unstub(:adv_article_bulk_actions_enabled?)
        Account.any_instance.unstub(:article_approval_workflow_enabled?)
      end

      def test_bulk_update_send_for_review_with_invalid_status
        Account.any_instance.stubs(:adv_article_bulk_actions_enabled?).returns(true)
        Account.any_instance.stubs(:article_approval_workflow_enabled?).returns(true)
        draft = @account.solution_drafts.last
        approver = add_test_agent
        add_privilege(approver, :approve_article)
        put :bulk_update, construct_params({ version: 'private' }, ids: [draft.article.parent_id], properties: { approval_status: 999, approver_id: approver.id })
        assert_response 400
        match_json(validation_error_pattern(bad_request_error_pattern_with_nested_field('properties', 'approval_data', :approval_data_invalid, code: :approval_data_invalid)))
      ensure
        Account.any_instance.unstub(:adv_article_bulk_actions_enabled?)
        Account.any_instance.unstub(:article_approval_workflow_enabled?)
      end

      def test_bulk_update_send_for_review_with_invalid_approver_id
        Account.any_instance.stubs(:adv_article_bulk_actions_enabled?).returns(true)
        Account.any_instance.stubs(:article_approval_workflow_enabled?).returns(true)
        draft = @account.solution_drafts.last
        put :bulk_update, construct_params({ version: 'private' }, ids: [draft.article.parent_id], properties: { approval_status: 1, approver_id: 'test' })
        assert_response 400
        match_json(validation_error_pattern(bad_request_error_pattern_with_nested_field('properties', 'approver_id', :datatype_mismatch, expected_data_type: 'Integer', given_data_type: 'String', code: :datatype_mismatch)))
      ensure
        Account.any_instance.unstub(:adv_article_bulk_actions_enabled?)
        Account.any_instance.unstub(:article_approval_workflow_enabled?)
      end

      def test_bulk_update_send_for_review_without_create_or_edit_privilege
        Account.any_instance.stubs(:adv_article_bulk_actions_enabled?).returns(true)
        Account.any_instance.stubs(:article_approval_workflow_enabled?).returns(true)
        User.current.reload
        remove_privilege(User.current, :create_and_edit_article)
        add_privilege(User.current, :approve_article)
        draft = @account.solution_drafts.last
        approver = add_test_agent
        add_privilege(approver, :approve_article)
        put :bulk_update, construct_params({ version: 'private' }, ids: [draft.article.parent_id], properties: { approval_status: 1, approver_id: approver.id })
        assert_response 400
        match_json(validation_error_pattern(bad_request_error_pattern_with_nested_field('properties', 'create_and_edit_article', :no_create_and_edit_article_privilege, code: :no_create_and_edit_article_privilege)))
      ensure
        Account.any_instance.unstub(:adv_article_bulk_actions_enabled?)
        Account.any_instance.unstub(:article_approval_workflow_enabled?)
        add_privilege(User.current, :create_and_edit_article)
        remove_privilege(User.current, :approve_article)
      end

      def test_bulk_update_send_for_review_without_approval_privilege
        Account.any_instance.stubs(:adv_article_bulk_actions_enabled?).returns(true)
        Account.any_instance.stubs(:article_approval_workflow_enabled?).returns(true)
        draft = @account.solution_drafts.last
        approver = add_test_agent
        remove_privilege(approver, :approve_article)
        put :bulk_update, construct_params({ version: 'private' }, ids: [draft.article.parent_id], properties: { approval_status: 1, approver_id: approver.id })
        assert_response 400
        match_json(validation_error_pattern(bad_request_error_pattern_with_nested_field('properties', 'approve_privilege', :no_approve_article_privilege, code: :no_approve_article_privilege)))
      ensure
        Account.any_instance.unstub(:adv_article_bulk_actions_enabled?)
        Account.any_instance.unstub(:article_approval_workflow_enabled?)
      end

      def test_bulk_update_send_for_review_for_article_without_draft
        Account.any_instance.stubs(:adv_article_bulk_actions_enabled?).returns(true)
        Account.any_instance.stubs(:article_approval_workflow_enabled?).returns(true)
        article = get_article_without_draft
        approver = add_test_agent
        add_privilege(approver, :approve_article)
        put :bulk_update, construct_params({ version: 'private' }, ids: [article.parent_id], properties: { approval_status: 1, approver_id: approver.id })
        assert_response 202
        expected = { succeeded: [], failed: [{ id: article.parent_id, errors: [] }] }
        assert_equal(expected, JSON.parse(response.body, symbolize_names: true))
      ensure
        Account.any_instance.unstub(:adv_article_bulk_actions_enabled?)
        Account.any_instance.unstub(:article_approval_workflow_enabled?)
      end

      def test_bulk_update_send_for_review_for_locked_draft
        Account.any_instance.stubs(:adv_article_bulk_actions_enabled?).returns(true)
        Account.any_instance.stubs(:article_approval_workflow_enabled?).returns(true)
        Solution::Draft.any_instance.stubs(:locked?).returns(true)
        draft = @account.solution_drafts.last
        approver = add_test_agent
        add_privilege(approver, :approve_article)
        put :bulk_update, construct_params({ version: 'private' }, ids: [draft.article.parent_id], properties: { approval_status: 1, approver_id: approver.id })
        assert_response 202
        expected = { succeeded: [], failed: [{ id: draft.article.parent_id, errors: [] }] }
        assert_equal(expected, JSON.parse(response.body, symbolize_names: true))
      ensure
        Account.any_instance.unstub(:adv_article_bulk_actions_enabled?)
        Account.any_instance.unstub(:article_approval_workflow_enabled?)
        Solution::Draft.any_instance.unstub(:locked?)
      end

      def test_bulk_update_send_for_review
        Account.any_instance.stubs(:adv_article_bulk_actions_enabled?).returns(true)
        Account.any_instance.stubs(:article_approval_workflow_enabled?).returns(true)
        add_privilege(User.current, :create_and_edit_article)
        User.current.reload
        sample_article = @account.solution_articles.where(language_id: 6).first
        create_draft(article: sample_article)
        draft = sample_article.draft
        approver = add_test_agent
        add_privilege(approver, :approve_article)
        put :bulk_update, construct_params({ version: 'private' }, ids: [draft.article.parent_id], properties: { approval_status: 1, approver_id: approver.id })
        assert_response 204
        approval_record = approval_record(draft.article)
        approver_mapping = approver_record(draft.article)
        assert approval_record
        assert approver_mapping
        assert_equal approval_record.approval_status, Helpdesk::ApprovalConstants::STATUS_KEYS_BY_TOKEN[:in_review]
        assert_equal approver_mapping.approver_id, approver.id
      ensure
        Account.any_instance.unstub(:adv_article_bulk_actions_enabled?)
        Account.any_instance.unstub(:article_approval_workflow_enabled?)
      end

      # Activity tests
      def test_activity_record_for_article_create
        folder_meta = get_folder_meta
        params_hash = { title: Faker::Lorem.name, description: Faker::Lorem.paragraph, status: 2 }
        activities_count = Helpdesk::Activity.count
        post :create, construct_params({ version: 'private', id: folder_meta.id }, params_hash)
        assert_response 201
        activity_record = Helpdesk::Activity.last
        action_name = activity_record.description.split('.')[2]
        assert_equal Helpdesk::Activity.count, activities_count + 1
        assert_equal activity_record.activity_data[:title], params_hash[:title]
        assert_equal action_name, 'new_article'
      end

      def test_activity_record_for_article_publish
        sample_article = get_article_with_draft
        title = sample_article.draft.name
        params_hash = { status: 2 }
        activities_count = Helpdesk::Activity.count
        put :update, construct_params({ version: 'private', id: sample_article.parent_id }, params_hash)
        assert_response 200
        activity_record = Helpdesk::Activity.last
        action_name = activity_record.description.split('.')[2]
        assert_equal Helpdesk::Activity.count, activities_count + 1
        assert_equal activity_record.activity_data[:title], title
        assert_equal action_name, 'published_article'
      end

      def test_activity_record_for_article_delete
        activities_count = Helpdesk::Activity.count
        sample_article = get_article
        title = sample_article.name
        delete :destroy, construct_params(version: 'private', id: sample_article.parent_id)
        assert_response 204
        activity_record = Helpdesk::Activity.last
        action_name = activity_record.description.split('.')[2]
        assert_equal Helpdesk::Activity.count, activities_count + 1
        assert_equal activity_record.activity_data[:title], title
        assert_equal action_name, 'delete_article'
      end

      # Omni related test cases

      def test_create_with_chat_platform_enabled_omni
        enable_omni_bundle do
          folder_meta = get_folder_meta_with_platform_mapping
          title = Faker::Name.name
          paragraph = Faker::Lorem.paragraph

          platform_obj = { platforms: chat_platform_params(web: true) }
          params = { title: title, description: paragraph, status: 1 }
          params.merge!(platform_obj)

          post :create, construct_params({ version: 'private', id: folder_meta.id }, params)
          assert_response 201
          match_json(private_api_solution_article_pattern(Solution::Article.last, platform_obj))
        end
      end

      def test_create_with_chat_platform_disabled_omni
        Account.any_instance.stubs(:omni_bundle_account?).returns(false)

        folder_meta = get_folder_meta_with_platform_mapping
        title = Faker::Name.name
        paragraph = Faker::Lorem.paragraph

        params = { title: title, description: paragraph, status: 1 }
        params.merge!(platforms: chat_platform_params(web: true))

        post :create, construct_params({ version: 'private', id: folder_meta.id }, params)
        assert_response 403
        match_json(validation_error_pattern(omni_bundle_required_error_for_platforms))
      ensure
        Account.any_instance.unstub(:omni_bundle_account?)
      end

      def test_create_for_folder_without_chat_platform
        enable_omni_bundle do
          folder_meta = get_folder_meta_without_platform_mapping
          title = Faker::Name.name
          paragraph = Faker::Lorem.paragraph

          params = { title: title, description: paragraph, status: 1 }
          params.merge!(platforms: chat_platform_params(web: true))

          post :create, construct_params({ version: 'private', id: folder_meta.id }, params)
          assert_response 201
        end
      end

      def test_update_with_platform_values_with_omni_feature
        enable_omni_bundle do
          sample_article = get_article_with_platform_mapping(web: false)
          platform_values = { platforms: chat_platform_params(web: true) }

          put :update, construct_params({ version: 'private', id: sample_article.parent_id }, platform_values)
          assert_response 200
          match_json(private_api_solution_article_pattern(sample_article, platform_values))
        end
      end

      def test_update_with_platform_values_without_omni_feature
        Account.any_instance.stubs(:omni_bundle_account?).returns(false)

        sample_article = get_article_with_platform_mapping
        platform_values = { platforms: chat_platform_params(web: false) }

        put :update, construct_params({ version: 'private', id: sample_article.parent_id }, platform_values)
        assert_response 403
        match_json(validation_error_pattern(omni_bundle_required_error_for_platforms))
      ensure
        Account.any_instance.unstub(:omni_bundle_account?)
      end

      def test_update_platform_values_mismatch_folder_platforms
        enable_omni_bundle do
          sample_article = get_article_with_platform_mapping(web: false)
          folder_meta = sample_article.parent.solution_folder_meta
          update_platform_values(folder_meta, web: false)

          platform_values = { platforms: { web: true } }
          put :update, construct_params({ version: 'private', id: sample_article.parent_id }, platform_values)
          assert_response 200
          sample_article.reload
          assert_equal sample_article.parent.solution_platform_mapping.web, false
        end
      end

      def test_update_folder_platform_mismatch_enabled_platforms
        enable_omni_bundle do
          sample_folder = get_folder_meta_with_platform_mapping(web: false)
          params_hash = { folder_id: sample_folder.id }

          sample_article = get_article_with_platform_mapping
          put :update, construct_params({ version: 'private', id: sample_article.parent_id }, params_hash)
          assert_response 200
          sample_article.reload
          assert_equal sample_article.parent.solution_folder_meta_id, sample_folder.id
          assert_equal sample_article.parent.solution_platform_mapping.web, false
        end
      end

      def test_update_folder_and_platform_values
        enable_omni_bundle do
          sample_folder = get_folder_meta_with_platform_mapping(web: true)
          sample_article = get_article_with_platform_mapping(web: false)

          params_hash = { folder_id: sample_folder.id }
          platform_values = { platforms: chat_platform_params(web: true) }

          put :update, construct_params({ version: 'private', id: sample_article.parent_id }, params_hash.merge!(platform_values))
          assert_response 200
          match_json(private_api_solution_article_pattern(sample_article, params_hash))
        end
      end

      def test_update_folder_and_platform_values_mismatch_enabled_platforms
        enable_omni_bundle do
          sample_folder = get_folder_meta_with_platform_mapping(web: false)
          sample_article = get_article_with_platform_mapping(web: false)

          params_hash = { folder_id: sample_folder.id }
          platform_values = { platforms: { web: true } }
          put :update, construct_params({ version: 'private', id: sample_article.parent_id }, params_hash.merge!(platform_values))
          assert_response 200
          sample_article.reload
          assert_equal sample_article.parent.solution_folder_meta_id, sample_folder.id
          assert_equal sample_article.parent.solution_platform_mapping.web, false
        end
      end

      def test_update_with_platform_values_with_publish_solution_privilege
        enable_omni_bundle do
          with_publish_solution_privilege do
            sample_article = get_article_with_platform_mapping(web: false)
            platform_values = { platforms: chat_platform_params(web: true) }

            put :update, construct_params({ version: 'private', id: sample_article.parent_id }, platform_values)
            assert_response 200
            match_json(private_api_solution_article_pattern(sample_article, platform_values))
          end
        end
      end

      def test_update_with_platform_values_without_publish_solution_privilege
        enable_omni_bundle do
          without_publish_solution_privilege do
            User.any_instance.stubs(:privilege?).with(:publish_approved_solution).returns(true)
            sample_article = get_article_with_platform_mapping(web: false)
            platform_values = { platforms: chat_platform_params(web: true) }

            put :update, construct_params({ version: 'private', id: sample_article.parent_id }, platform_values)
            assert_response 403

            error_info_hash = { details: 'dont have permission to perfom on published article' }
            match_json(request_error_pattern_with_info(:published_article_privilege_error, error_info_hash, error_info_hash))
          end
        end
      ensure
        User.any_instance.unstub(:privilege?)
      end

      def test_update_with_platform_values_with_article_in_review
        enable_omni_bundle do
          Account.any_instance.stubs(:article_approval_workflow_enabled?).returns(true)
          sample_article = get_article_with_platform_mapping(web: false)
          platform_values = { platforms: chat_platform_params(web: true) }

          put :update, construct_params({ version: 'private', id: sample_article.parent_id }, platform_values)
          assert_response 200
          match_json(private_api_solution_article_pattern(sample_article, platform_values))
          assert_no_approval(sample_article)
        end
      ensure
        Account.any_instance.unstub(:article_approval_workflow_enabled?)
      end

      def test_bulk_update_folder_with_platforms_enabled
        enable_omni_bundle do
          sample_folder = get_folder_meta_with_platform_mapping(web: false)
          sample_article = get_article_with_platform_mapping

          put :bulk_update, construct_params({ version: 'private' }, ids: [sample_article.parent.id], properties: { folder_id: sample_folder.id })
          assert_response 204
          sample_article.reload
          assert_equal sample_article.parent.solution_folder_meta_id, sample_folder.id
          assert_equal sample_article.parent.solution_platform_mapping.web, false
        end
      end

      def test_article_filters_by_platforms_with_omni_bundle_enabled
        enable_omni_bundle do
          get_article_with_platform_mapping

          platform_types = ['web', 'ios']
          count = get_articles_enabled_in_platforms_count(platform_types)
          get :filter, controller_params({ version: 'private', portal_id: @portal_id.to_s, platforms: platform_types }, false)

          assert_response 200
          assert_equal count, (parse_response @response.body).size
        end
      end

      def test_article_filters_by_platforms_without_omni_bundle
        Account.any_instance.stubs(:omni_bundle_account?).returns(false)

        get_article_with_platform_mapping
        platform_types = ['web', 'ios']
        get :filter, controller_params({ version: 'private', portal_id: @portal_id.to_s, platforms: platform_types }, false)

        assert_response 403
        match_json(validation_error_pattern(omni_bundle_required_error_for_platforms))
      ensure
        Account.any_instance.unstub(:omni_bundle_account?)
      end

      private

        def version
          'private'
        end

        def article_pattern(article, expected_output = {}, user = nil)
          private_api_solution_article_pattern(article, expected_output.merge(request_language: true), true, user)
        end

        def article_draft_pattern(article, _draft)
          private_api_solution_article_pattern(article, request_language: true)
        end

        def article_pattern_index(article)
          private_api_solution_article_pattern(article, exclude_description: true, exclude_attachments: true, exclude_tags: true, request_language: true, exclude_translation_summary: true)
        end

        def get_portal_articles(portal_id, language_ids)
          Solution::Article.portal_articles(portal_id, language_ids).joins('LEFT JOIN solution_drafts as drafts ON drafts.article_id = solution_articles.id').order('IFNULL(drafts.modified_at, solution_articles.modified_at) desc')
        end

        def get_article_meta_with_translation
          @account.solution_category_meta.where(is_default: false).collect(&:solution_article_meta).flatten.map { |x| x if x.children.count > 1 }.flatten.reject(&:blank?).first
        end

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

        def untranslated_language_articles
          translated_ids = @account.solution_articles.portal_articles(@portal_id, @language.id).pluck(:parent_id)
          get_portal_articles(@portal_id, [@account.language_object.id]).where('parent_id NOT IN (?)', (translated_ids.presence || ''))
        end
    end

    class ArticlesControllerVersionsTest < ActionController::TestCase
      include SolutionsArticleVersionsTestHelper
      include SolutionsArticlesTestHelper
      include SolutionsTestHelper
      include SolutionsHelper
      include SolutionBuilderHelper
      include InstalledApplicationsTestHelper
      include AttachmentsTestHelper
      include PrivilegesHelper
      tests Ember::Solutions::ArticlesController

      def setup
        super
        @account = Account.first
        Account.stubs(:current).returns(@account)
        setup_multilingual
        before_all
        @account.add_feature(:article_versioning)
        @account.launch(:article_versioning_redis_lock)
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

      def wrap_cname(params)
        { article: params }
      end

      def test_update_article_without_article_versioning
        disable_article_versioning do
          sample_article = get_article_without_draft
          should_not_create_version(sample_article) do
            paragraph = Faker::Lorem.paragraph
            params_hash = { title: 'publish without draft title', description: paragraph, status: 2, agent_id: @agent.id }
            put :update, construct_params({ version: 'private', id: sample_article.parent_id }, params_hash)
            assert_response 200
          end
        end
      end

      def test_update_article_with_article_versioning
        sample_article = get_article_without_draft
        should_create_version(sample_article) do
          paragraph = Faker::Lorem.paragraph
          params_hash = { title: 'publish without draft title', description: paragraph, status: 2, agent_id: @agent.id }
          put :update, construct_params({ version: 'private', id: sample_article.parent_id }, params_hash)
          assert_response 200
        end
      end

      # save actions
      def test_draft_autosave_save
        sample_article = create_article(article_params(lang_codes: all_account_languages).merge(status: 1)).primary_article
        draft_version = create_draft_version_for_article(sample_article)
        assert !sample_article.draft.nil?
        session = 'lorem-ipsum'
        should_not_create_version(sample_article) do
          stub_version_session(session) do
            params_hash = { status: 1, unlock: true, session: session }
            put :update, construct_params({ version: 'private', id: sample_article.parent_id }, params_hash)
            assert_response 200
            latest_version = get_latest_version(sample_article)
            assert_equal latest_version.id, draft_version.id
            assert_version_draft(latest_version)
          end
        end
      end

      def test_draft_save
        sample_article = create_article(article_params(lang_codes: all_account_languages).merge(status: 1)).primary_article
        assert sample_article.status == 1
        should_create_version(sample_article) do
          params_hash = { status: 1, unlock: true, session: nil }
          put :update, construct_params({ version: 'private', id: sample_article.parent_id }, params_hash)
          assert_response 200
          latest_version = get_latest_version(sample_article)
          assert_version_draft(latest_version)
        end
      end

      def test_draft_without_redislock
        sample_article = create_article(article_params(lang_codes: all_account_languages).merge(status: 1)).primary_article
        assert sample_article.status == 1
        @account.rollback(:article_versioning_redis_lock)
        Redis::Redlock.expects(:acquire_lock_and_run).times(0)
        should_create_version(sample_article) do
          params_hash = { status: 1, unlock: true, session: nil }
          put :update, construct_params({ version: 'private', id: sample_article.parent_id }, params_hash)
          assert_response 200
          latest_version = get_latest_version(sample_article)
          assert_version_draft(latest_version)
        end
      end

      def test_draft_edit_save
        sample_article = create_article(article_params(lang_codes: all_account_languages).merge(status: 1)).primary_article
        assert sample_article.status == 1
        should_create_version(sample_article) do
          description = Faker::Lorem.paragraph
          params_hash = { status: 1, session: nil, description: description }
          put :update, construct_params({ version: 'private', id: sample_article.parent_id }, params_hash)
          assert_response 200
          latest_version = get_latest_version(sample_article)
          assert_version_draft(latest_version)
          assert_equal sample_article.draft.description, description
        end
      end

      def test_published_autosave_save
        sample_article = create_article(article_params(lang_codes: all_account_languages).merge(status: 2)).primary_article
        assert sample_article.draft.nil?
        draft_version = create_draft_version_for_article(sample_article)
        session = 'lorem-ipsum'
        should_not_create_version(sample_article) do
          stub_version_session(session) do
            params_hash = { status: 1, unlock: true, session: session }
            put :update, construct_params({ version: 'private', id: sample_article.parent_id }, params_hash)
            assert_response 200
            latest_version = get_latest_version(sample_article)
            assert_equal latest_version.id, draft_version.id
            assert_version_draft(latest_version)
          end
        end
      end

      def test_published_save
        sample_article = create_article(article_params(lang_codes: all_account_languages).merge(status: 2)).primary_article
        assert sample_article.draft.nil?
        should_create_version(sample_article) do
          params_hash = { status: 1, session: nil }
          put :update, construct_params({ version: 'private', id: sample_article.parent_id }, params_hash)
          assert_response 200
          latest_version = get_latest_version(sample_article)
          assert_version_draft(latest_version)
        end
      end

      def test_published_edit_save
        sample_article = create_article(article_params(lang_codes: all_account_languages).merge(status: 2)).primary_article
        assert sample_article.draft.nil?
        should_create_version(sample_article) do
          description = Faker::Lorem.paragraph
          params_hash = { status: 1, session: nil, description: description }
          put :update, construct_params({ version: 'private', id: sample_article.parent_id }, params_hash)
          assert_response 200
          latest_version = get_latest_version(sample_article)
          assert_version_draft(latest_version)
          assert_equal sample_article.draft.description, description
        end
      end

      def test_published_draft_save
        sample_article = create_article(article_params(lang_codes: all_account_languages).merge(status: 2)).primary_article
        assert sample_article.draft.nil?
        draft_version = create_draft_version_for_article(sample_article)
        assert !sample_article.draft.nil?
        should_create_version(sample_article) do
          params_hash = { status: 1, unlock: true, session: nil }
          put :update, construct_params({ version: 'private', id: sample_article.parent_id }, params_hash)
          assert_response 200
          latest_version = get_latest_version(sample_article)
          assert_version_draft(latest_version)
        end
      end

      def test_published_draft_edit_save
        sample_article = create_article(article_params(lang_codes: all_account_languages).merge(status: 2)).primary_article
        assert sample_article.draft.nil?
        draft_version = create_draft_version_for_article(sample_article)
        should_create_version(sample_article) do
          description = Faker::Lorem.paragraph
          params_hash = { status: 1, session: nil, description: description }
          put :update, construct_params({ version: 'private', id: sample_article.parent_id }, params_hash)
          assert_response 200
          latest_version = get_latest_version(sample_article)
          assert_version_draft(latest_version)
          assert_equal sample_article.draft.description, description
        end
      end

      # publish actions
      def test_draft_autosave_publish
        sample_article = create_article(article_params(lang_codes: all_account_languages).merge(status: 1)).primary_article
        draft_version = create_draft_version_for_article(sample_article)
        assert !sample_article.draft.nil?
        session = 'lorem-ipsum'
        should_not_create_version(sample_article) do
          stub_version_session(session) do
            params_hash = { status: 2, session: session }
            put :update, construct_params({ version: 'private', id: sample_article.parent_id }, params_hash)
            assert_response 200
            latest_version = get_latest_version(sample_article)
            assert_equal latest_version.id, draft_version.id
            assert_version_published(latest_version)
            assert_version_live(latest_version)
          end
        end
      end

      def test_draft_publish
        sample_article = create_article(article_params(lang_codes: all_account_languages).merge(status: 1)).primary_article
        assert sample_article.status == 1
        should_create_version(sample_article) do
          params_hash = { status: 2, session: nil }
          put :update, construct_params({ version: 'private', id: sample_article.parent_id }, params_hash)
          assert_response 200
          latest_version = get_latest_version(sample_article)
          assert_version_published(latest_version)
          assert_version_live(latest_version)
        end
      end

      def test_draft_edit_publish
        sample_article = create_article(article_params(lang_codes: all_account_languages).merge(status: 1)).primary_article
        assert sample_article.status == 1
        should_create_version(sample_article) do
          description = Faker::Lorem.paragraph
          params_hash = { status: 2, session: nil, description: description }
          put :update, construct_params({ version: 'private', id: sample_article.parent_id }, params_hash)
          assert_response 200
          latest_version = get_latest_version(sample_article)
          assert_version_published(latest_version)
          assert_version_live(latest_version)
          assert_equal sample_article.description, description
        end
      end

      def test_published_publish
        sample_article = create_article(article_params(lang_codes: all_account_languages).merge(status: 2)).primary_article
        assert sample_article.status == 2
        should_not_create_version(sample_article) do
          params_hash = { status: 2, session: nil }
          put :update, construct_params({ version: 'private', id: sample_article.parent_id }, params_hash)
          assert_response 200
          latest_version = get_latest_version(sample_article)
          assert_version_published(latest_version)
          assert_version_live(latest_version)
        end
      end

      def test_published_edit_publish
        sample_article = create_article(article_params(lang_codes: all_account_languages).merge(status: 2)).primary_article
        assert sample_article.status == 2
        should_create_version(sample_article) do
          description = Faker::Lorem.paragraph
          params_hash = { status: 2, session: nil, description: description }
          put :update, construct_params({ version: 'private', id: sample_article.parent_id }, params_hash)
          assert_response 200
          latest_version = get_latest_version(sample_article)
          assert_version_published(latest_version)
          assert_version_live(latest_version)
          assert_equal sample_article.description, description
        end
      end

      def test_published_autosave_publish
        sample_article = create_article(article_params(lang_codes: all_account_languages).merge(status: 2)).primary_article
        assert sample_article.draft.nil?
        draft_version = create_draft_version_for_article(sample_article)
        session = 'lorem-ipsum'
        should_not_create_version(sample_article) do
          stub_version_session(session) do
            params_hash = { status: 2, session: session }
            put :update, construct_params({ version: 'private', id: sample_article.parent_id }, params_hash)
            assert_response 200
            latest_version = get_latest_version(sample_article)
            assert_equal latest_version.id, draft_version.id
            assert_version_published(latest_version)
            assert_version_live(latest_version)
          end
        end
      end

      def test_published_draft_publish
        sample_article = create_article(article_params(lang_codes: all_account_languages).merge(status: 2)).primary_article
        assert sample_article.draft.nil?
        draft_version = create_draft_version_for_article(sample_article)
        assert !sample_article.draft.nil?
        should_create_version(sample_article) do
          params_hash = { status: 2, session: nil }
          put :update, construct_params({ version: 'private', id: sample_article.parent_id }, params_hash)
          assert_response 200
          latest_version = get_latest_version(sample_article)
          assert_version_published(latest_version)
          assert_version_live(latest_version)
        end
      end

      def test_published_draft_autosave_publish
        sample_article = create_article(article_params(lang_codes: all_account_languages).merge(status: 2)).primary_article
        assert sample_article.draft.nil?
        draft_version = create_draft_version_for_article(sample_article)
        session = 'lorem-ipsum'
        should_not_create_version(sample_article) do
          stub_version_session(session) do
            params_hash = { status: 2, session: session }
            put :update, construct_params({ version: 'private', id: sample_article.parent_id }, params_hash)
            assert_response 200
            latest_version = get_latest_version(sample_article)
            assert_equal latest_version.id, draft_version.id
            assert_version_published(latest_version)
          end
        end
      end

      def test_published_draft_edit_publish
        sample_article = create_article(article_params(lang_codes: all_account_languages).merge(status: 2)).primary_article
        assert sample_article.draft.nil?
        draft_version = create_draft_version_for_article(sample_article)
        should_create_version(sample_article) do
          description = Faker::Lorem.paragraph
          params_hash = { status: 2, session: nil, description: description }
          put :update, construct_params({ version: 'private', id: sample_article.parent_id }, params_hash)
          assert_response 200
          latest_version = get_latest_version(sample_article)
          assert_version_published(latest_version)
          assert_equal sample_article.description, description
        end
      end

      # unpublish actions
      def test_published_unpublish
        sample_article = create_article(article_params(lang_codes: all_account_languages).merge(status: 2)).primary_article
        assert sample_article.draft.nil?
        should_create_version(sample_article) do
          params_hash = { status: 1, session: nil }
          put :update, construct_params({ version: 'private', id: sample_article.parent_id }, params_hash)
          assert_response 200
          latest_version = get_latest_version(sample_article)
          assert_version_draft(latest_version)
          assert !sample_article.reload.draft.nil?
          assert sample_article.solution_article_versions.where(live: true).empty?
        end
      end

      def test_published_draft_autosave_unpublish
        sample_article = create_article(article_params(lang_codes: all_account_languages).merge(status: 2)).primary_article
        assert sample_article.draft.nil?
        draft_version = create_draft_version_for_article(sample_article)
        session = 'lorem-ipsum'
        should_not_create_version(sample_article) do
          stub_version_session(session) do
            params_hash = { status: 1, session: session }
            put :update, construct_params({ version: 'private', id: sample_article.parent_id }, params_hash)
            assert_response 200
            latest_version = get_latest_version(sample_article)
            assert_equal latest_version.id, draft_version.id
            assert_version_draft(latest_version)
          end
        end
      end

      def test_published_draft_unpublish
        sample_article = create_article(article_params(lang_codes: all_account_languages).merge(status: 2)).primary_article
        assert sample_article.draft.nil?
        draft_version = create_draft_version_for_article(sample_article)
        should_create_version(sample_article) do
          params_hash = { status: 1, session: nil }
          put :update, construct_params({ version: 'private', id: sample_article.parent_id }, params_hash)
          assert_response 200
          latest_version = get_latest_version(sample_article)
          assert_version_draft(latest_version)
          assert !sample_article.reload.draft.nil?
          assert sample_article.solution_article_versions.where(live: true).empty?
        end
      end

      def test_version_ratings_with_primary_language
        meta_article = create_article(article_params.merge(status: 2))
        article = meta_article.primary_article
        draft = create_draft(article: article)
        assert_equal 2, versions_count(article)
        10.times do
          article.thumbs_up!
        end
        15.times do
          article.thumbs_down!
        end
        article.reload
        assert_equal article.thumbs_up, versions_thumbs_up_count(article)
        assert_equal article.thumbs_down, versions_thumbs_down_count(article)
      end

      def test_version_ratings_with_supported_language
        meta_article = create_article(article_params(lang_codes: all_account_languages, status: 2))
        article = meta_article.primary_article
        draft = create_draft(article: article)
        assert_equal 2, versions_count(article)
        12.times do
          article.thumbs_up!
        end
        8.times do
          article.thumbs_down!
        end
        article.reload
        assert_equal article.thumbs_up, versions_thumbs_up_count(article)
        assert_equal article.thumbs_down, versions_thumbs_down_count(article)
      end

      def test_version_reset_ratings_with_primary_language
        Sidekiq::Testing.inline! do
          meta_article = create_article(article_params.merge(status: 2))
          article = meta_article.primary_article
          draft = create_draft(article: article)
          assert_equal 2, versions_count(article)
          10.times do
            article.thumbs_up!
          end
          3.times do
            article.thumbs_down!
          end
          article.reload
          assert_equal article.thumbs_up, versions_thumbs_up_count(article)
          assert_equal article.thumbs_down, versions_thumbs_down_count(article)
          put :reset_ratings, construct_params(version: 'private', id: meta_article.id)
          assert_response 204
          article.reload
          assert_equal 0, article.thumbs_up
          assert_equal 0, article.thumbs_down
          assert_equal article.thumbs_up, versions_thumbs_up_count(article)
          assert_equal article.thumbs_down, versions_thumbs_down_count(article)
        end
      end

      def test_version_reset_ratings_with_supported_language
        Sidekiq::Testing.inline! do
          meta_article = create_article(article_params(lang_codes: all_account_languages, status: 2))
          article = meta_article.primary_article
          draft = create_draft(article: article)
          assert_equal 2, versions_count(article)
          15.times do
            article.thumbs_up!
          end
          5.times do
            article.thumbs_down!
          end
          article.reload
          assert_equal article.thumbs_up, versions_thumbs_up_count(article)
          assert_equal article.thumbs_down, versions_thumbs_down_count(article)
          put :reset_ratings, construct_params(version: 'private', id: meta_article.id)
          assert_response 204
          article.reload
          assert_equal 0, article.thumbs_up
          assert_equal 0, article.thumbs_down
          assert_equal article.thumbs_up, versions_thumbs_up_count(article)
          assert_equal article.thumbs_down, versions_thumbs_down_count(article)
        end
      end

      def test_version_hits
        article = create_article(article_params(lang_codes: all_account_languages).merge(status: 2)).primary_article
        assert article.draft.nil?
        create_draft_version_for_article(article)
        105.times do
          article.hit!
        end
        article.reload
        assert_equal 100, article.read_attribute(:hits)
        assert_equal article.read_attribute(:hits), article.live_version.hits
      end

      def test_flush_hits_article_publish
        # Published article with hits/views count
        article = create_article(article_params(lang_codes: all_account_languages).merge(status: 2)).primary_article
        assert article.draft.nil?
        create_draft_version_for_article(article)
        105.times do
          article.hit!
        end
        article.reload
        old_live_version = article.live_version
        assert_equal article.read_attribute(:hits), old_live_version.hits

        # Publishing article should flush hits/views count
        should_create_version(article) do
          description = Faker::Lorem.paragraph
          params_hash = { status: 2, session: nil, description: description }
          put :update, construct_params({ version: 'private', id: article.parent_id }, params_hash)
          assert_response 200
        end
        article.reload
        old_live_version.reload
        assert_equal 105, article.read_attribute(:hits)
        assert_equal 105, old_live_version.hits
      end

      def test_publish_with_cloud_attachments
        sample_article = create_article(article_params(lang_codes: all_account_languages).merge(status: 2)).primary_article
        app = create_application('dropbox')
        cloud_file_params = [{ name: 'image.jpg', url: CLOUD_FILE_IMAGE_URL, application_id: app.application_id }]
        should_create_version(sample_article) do
          put :update, construct_params({ version: 'private', id: sample_article.parent_id }, status: 2, cloud_file_attachments: cloud_file_params, session: nil)
          assert_response 200
          latest_version = get_latest_version(sample_article)
          match_json(private_api_solution_article_pattern(sample_article))
          assert_equal sample_article.cloud_files.count, 1
          assert_equal latest_version[:meta][:cloud_files].length, 1
          latest_version[:meta][:cloud_files].each do |file|
            assert !file[:id].nil?
          end
        end
      end

      def test_draft_autosave_send_for_review
        Account.any_instance.stubs(:article_approval_workflow_enabled?).returns(true)
        sample_article = create_article(article_params(lang_codes: all_account_languages).merge(status: 1)).primary_article
        draft_version = create_draft_version_for_article(sample_article)
        assert sample_article.status == 1
        approver = add_test_agent
        session = 'lorem-ipsum'
        add_privilege(approver, :approve_article)
        should_not_create_version(sample_article) do
          post :send_for_review, construct_params({ version: 'private', id: sample_article.parent_id }, approver_id: approver.id)
          assert_response 204
          latest_version = get_latest_version(sample_article)
          assert_equal latest_version.id, draft_version.id
          assert_version_draft(latest_version)
        end
      ensure
        Account.any_instance.unstub(:article_approval_workflow_enabled?)
      end

      def test_bulk_update_publish_should_not_create_multiple_versions
        Account.any_instance.stubs(:adv_article_bulk_actions_enabled?).returns(true)
        User.any_instance.stubs(:privilege?).with(:create_and_edit_article).returns(true)
        User.any_instance.stubs(:privilege?).with(:publish_solution).returns(true)
        User.any_instance.stubs(:privilege?).with(:publish_approved_solution).returns(true)
        sample_article = create_article(article_params(lang_codes: all_account_languages).merge(status: 1)).primary_article
        should_create_version(sample_article) do
          put :bulk_update, construct_params({ version: 'private' }, ids: [sample_article.parent_id], properties: { status: 2 })
          sample_article.reload
          assert_response 204
          assert_equal sample_article.status, 2
        end
      ensure
        Account.any_instance.unstub(:adv_article_bulk_actions_enabled?)
        User.any_instance.unstub(:privilege?)
      end

      def test_bulk_update_publish_should_not_create_multiple_versions_in_secondary_language
        Account.any_instance.stubs(:adv_article_bulk_actions_enabled?).returns(true)
        User.any_instance.stubs(:privilege?).with(:create_and_edit_article).returns(true)
        User.any_instance.stubs(:privilege?).with(:publish_solution).returns(true)
        User.any_instance.stubs(:privilege?).with(:publish_approved_solution).returns(true)
        languages = @account.supported_languages + ['primary']
        language  = @account.supported_languages.first
        article_meta = create_article(article_params(lang_codes: languages).merge(status: 1))
        sample_article = article_meta.safe_send("#{language}_article")
        should_create_version(sample_article) do
          put :bulk_update, construct_params({ version: 'private', language: language }, ids: [sample_article.parent_id], properties: { status: 2 })
          sample_article.reload
          assert_response 204
          assert_equal sample_article.status, 2
        end
      ensure
        Account.any_instance.unstub(:adv_article_bulk_actions_enabled?)
        User.any_instance.unstub(:privilege?)
      end

      def test_suggested
        article = create_article(article_params).primary_article
        article_id = article.id
        article_meta_id = article.parent.id
        language = article.language.code
        suggested = article.suggested

        articles_suggested = [{ language: language, article_id: article_meta_id }]
        params_hash = { articles_suggested: articles_suggested }

        put :suggested, construct_params({ version: 'private' }, params_hash)
        assert_response 204

        article = Solution::Article.find_by_id(article_id)
        assert_equal (suggested + 1), article.suggested
      end

      def test_suggested_invalid_format_langcode
        article = create_article(article_params).primary_article
        article_id = article.id
        article_meta_id = article.parent.id

        language = Faker::Lorem.characters(10)
        articles_suggested = [{ language: language, article_id: article_meta_id }]
        params_hash = { articles_suggested: articles_suggested }

        put :suggested, construct_params({ version: 'private' }, params_hash)
        assert_response 400
      end

      def test_suggested_negative_article_id
        article = create_article(article_params).primary_article
        article_id = article.id
        article_meta_id = article.parent.id
        language = article.language.code

        articles_suggested = [{ language: language, article_id: -1 }]
        params_hash = { articles_suggested: articles_suggested }

        put :suggested, construct_params({ version: 'private' }, params_hash)
        assert_response 400
      end

      def test_suggested_article_id_zero
        article = create_article(article_params).primary_article
        article_id = article.id
        article_meta_id = article.parent.id
        language = article.language.code

        articles_suggested = [{ language: language, article_id: 0 }]
        params_hash = { articles_suggested: articles_suggested }

        put :suggested, construct_params({ version: 'private' }, params_hash)
        assert_response 400
      end

      def test_suggested_text_article_id
        article = create_article(article_params).primary_article
        article_id = article.id
        article_meta_id = article.parent.id
        language = article.language.code

        articles_suggested = [{ language: language, article_id: 'id' }]
        params_hash = { articles_suggested: articles_suggested }

        put :suggested, construct_params({ version: 'private' }, params_hash)
        assert_response 400
      end

      def test_suggested_invalid_article_language
        article = create_article(article_params).primary_article
        article_id = article.id
        article_meta_id = article.parent.id
        suggested = article.suggested

        language = article.language.code == 'en' ? 'fr' : 'en'
        articles_suggested = [{ language: language, article_id: article_meta_id }]
        params_hash = { articles_suggested: articles_suggested }

        put :suggested, construct_params({ version: 'private' }, params_hash)
        assert_response 204

        article = Solution::Article.find_by_id(article_id)
        assert_equal suggested, article.suggested
      end

      def test_suggested_invalid_article_meta_id
        article = create_article(article_params).primary_article
        article_id = article.id
        article_meta_id = article.parent.id
        language = article.language.code
        suggested = article.suggested

        articles_suggested = [{ language: language, article_id: article_meta_id + 1 }]
        params_hash = { articles_suggested: articles_suggested }

        put :suggested, construct_params({ version: 'private' }, params_hash)
        assert_response 204

        article = Solution::Article.find_by_id(article_id)
        assert_equal suggested, article.suggested
      end

      def test_suggested_without_suggested_feature
        Account.any_instance.stubs(:suggested_articles_count_enabled?).returns(false)
        article = create_article(article_params).primary_article
        article_meta_id = article.parent.id
        language = article.language.code

        articles_suggested = [{ language: language, article_id: article_meta_id }]
        params_hash = { articles_suggested: articles_suggested }

        put :suggested, construct_params({ version: 'private' }, params_hash)
        assert_response 403
      ensure
        Account.any_instance.unstub(:suggested_articles_count_enabled?)
      end

      def test_export_articles_with_suggested_column_without_suggested_feature
        Account.any_instance.stubs(:suggested_articles_count_enabled?).returns(false)
        export_params = { portal_id: @portal_id.to_s, article_fields: [{ field_name: 'suggested', column_name: 'Suggested' }] }
        post :export, construct_params({ version: 'private' }, export_params)
        assert_response 400
      ensure
        Account.any_instance.unstub(:suggested_articles_count_enabled?)
      end

      def test_kb_increased_file_limit_feature_with_valid_file_size
        cumulative_attachment_limit = 100
        Account.any_instance.stubs(:kb_increased_file_limit_enabled?).returns(true)
        AccountAdditionalSettings.any_instance.stubs(:additional_settings).returns(kb_cumulative_attachment_limit: cumulative_attachment_limit)

        attachment_id = create_file_ticket_field_attachment(attachable_type: 'UserDraft', attachable_id: User.current.id, content_file_size: cumulative_attachment_limit.megabyte).id

        title = Faker::Name.name
        paragraph = Faker::Lorem.paragraph
        folder_meta = get_folder_meta

        post :create, construct_params({ version: 'private', id: folder_meta.id }, title: title, description: paragraph, status: 2, attachments_list: [attachment_id])
        assert_response 201
      ensure
        Account.any_instance.unstub(:kb_increased_file_limit_enabled?)
        AccountAdditionalSettings.any_instance.unstub(:additional_settings)
      end

      def test_kb_increased_file_limit_feature_with_invalid_file_size
        cumulative_attachment_limit = 100
        file_size = cumulative_attachment_limit + 1

        Account.any_instance.stubs(:kb_increased_file_limit_enabled?).returns(true)
        AccountAdditionalSettings.any_instance.stubs(:additional_settings).returns(kb_cumulative_attachment_limit: cumulative_attachment_limit)

        attachment_id = create_file_ticket_field_attachment(attachable_type: 'UserDraft', attachable_id: User.current.id, content_file_size: file_size.megabyte).id

        title = Faker::Name.name
        paragraph = Faker::Lorem.paragraph
        folder_meta = get_folder_meta

        post :create, construct_params({ version: 'private', id: folder_meta.id }, title: title, description: paragraph, status: 2, attachments_list: [attachment_id])
        assert_response 400
        match_json(cumulative_attachment_size_validation_error_pattern(file_size, cumulative_attachment_limit))
      ensure
        Account.any_instance.unstub(:kb_increased_file_limit_enabled?)
        AccountAdditionalSettings.any_instance.unstub(:additional_settings)
      end

      def test_kb_increased_file_limit_feature_without_keys_in_additional_settings
        Account.any_instance.stubs(:kb_increased_file_limit_enabled?).returns(true)

        file_size = 100
        attachment_id = create_file_ticket_field_attachment(attachable_type: 'UserDraft', attachable_id: User.current.id, content_file_size: file_size.megabyte).id

        title = Faker::Name.name
        paragraph = Faker::Lorem.paragraph
        folder_meta = get_folder_meta

        post :create, construct_params({ version: 'private', id: folder_meta.id }, title: title, description: paragraph, status: 2, attachments_list: [attachment_id])
        assert_response 400
        match_json(cumulative_attachment_size_validation_error_pattern(file_size, Account.current.attachment_limit))
      ensure
        Account.any_instance.unstub(:kb_increased_file_limit_enabled?)
      end

      def test_should_trigger_kbservice_clear_cache_on_create_and_publish_article
        Account.any_instance.stubs(:omni_bundle_account?).returns(true)
        Account.current.launch(:kbase_omni_bundle)
        Solution::KbserviceClearCacheWorker.expects(:perform_async).once
        folder_meta = get_folder_meta
        title = Faker::Name.name
        paragraph = Faker::Lorem.paragraph
        post :create, construct_params({ version: 'private', id: folder_meta.id }, title: title, description: paragraph, status: 2)
        assert_response 201
        assert_nil Solution::Article.last.draft
        match_json(private_api_solution_article_pattern(Solution::Article.last))
      ensure
        Account.any_instance.unstub(:omni_bundle_account?)
        Account.current.rollback :kbase_omni_bundle
      end

      def test_should_not_trigger_kbservice_clear_cache_on_create_a_draft_article
        Account.any_instance.stubs(:omni_bundle_account?).returns(true)
        Account.current.launch(:kbase_omni_bundle)
        folder_meta = get_folder_meta
        title = Faker::Name.name
        paragraph = Faker::Lorem.paragraph
        post :create, construct_params({ version: 'private', id: folder_meta.id }, title: title, description: paragraph, status: 1)
        assert_response 201
        assert Solution::Article.last.draft
        match_json(private_api_solution_article_pattern(Solution::Article.last))
        Solution::KbserviceClearCacheWorker.expects(:perform_async).never
      ensure
        Account.any_instance.unstub(:omni_bundle_account?)
        Account.current.rollback :kbase_omni_bundle
      end

      def test_should_not_trigger_kbservice_clear_cache_on_update_article_as_draft
        Account.any_instance.stubs(:omni_bundle_account?).returns(true)
        Account.current.launch(:kbase_omni_bundle)
        sample_article = get_article_without_draft
        paragraph = Faker::Lorem.paragraph
        params_hash = { title: 'new draft title 2', description: paragraph, status: 1, agent_id: @agent.id }
        put :update, construct_params({ version: 'private', id: sample_article.parent_id }, params_hash)
        assert_response 200
        assert sample_article.reload.draft
        assert sample_article.reload.draft.reload.title == 'new draft title 2'
        assert sample_article.reload.draft.reload.status == 1
        match_json(private_api_solution_article_pattern(sample_article.reload))
        Solution::KbserviceClearCacheWorker.expects(:perform_async).never
      ensure
        Account.any_instance.unstub(:omni_bundle_account?)
        Account.current.rollback :kbase_omni_bundle
      end

      def test_should_trigger_kbservice_clear_cache_on_update_article_and_publish
        Account.any_instance.stubs(:omni_bundle_account?).returns(true)
        Account.current.launch(:kbase_omni_bundle)
        sample_article = get_article_without_draft
        paragraph = Faker::Lorem.paragraph
        params_hash = { title: 'new publish title 2', description: paragraph, status: 2, agent_id: @agent.id }
        put :update, construct_params({ version: 'private', id: sample_article.parent_id }, params_hash)
        assert_response 200
        assert_nil sample_article.reload.draft
        assert sample_article.reload.title == 'new publish title 2'
        assert sample_article.reload.status == 2
        match_json(private_api_solution_article_pattern(sample_article.reload))
      ensure
        Account.any_instance.unstub(:omni_bundle_account?)
        Account.current.rollback :kbase_omni_bundle
      end

      def test_should_trigger_kbservice_clear_cache_on_update_and_publish_a_draft
        Account.any_instance.stubs(:omni_bundle_account?).returns(true)
        Account.current.launch(:kbase_omni_bundle)
        sample_article = get_article_with_draft
        paragraph = Faker::Lorem.paragraph
        Solution::KbserviceClearCacheWorker.expects(:perform_async).once
        put :update, construct_params({ version: 'private', id: sample_article.parent_id }, status: 2, title: 'publish draft title', agent_id: @agent.id)
        assert_response 200
        assert_nil sample_article.reload.draft
        assert sample_article.reload.title == 'publish draft title'
        match_json(private_api_solution_article_pattern(sample_article.reload))
      ensure
        Account.any_instance.unstub(:omni_bundle_account?)
        Account.current.rollback :kbase_omni_bundle
      end

      def test_should_trigger_kbservice_clear_cache_on_bulk_update_tags
        Account.any_instance.stubs(:omni_bundle_account?).returns(true)
        Account.current.launch(:kbase_omni_bundle)
        article = @account.solution_articles.where(language_id: 6).first
        tags = [Faker::Name.name, Faker::Name.name]
        Solution::KbserviceClearCacheWorker.expects(:perform_async).at_least_once
        put :bulk_update, construct_params({ version: 'private' }, ids: [article.parent_id], properties: { tags: tags })
        assert_response 204
        article.reload
        assert (tags - article.reload.tags.map(&:name)).empty?
      ensure
        Account.any_instance.unstub(:omni_bundle_account?)
        Account.current.rollback :kbase_omni_bundle
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
