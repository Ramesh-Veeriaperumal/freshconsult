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

      def setup
        super
        initial_setup
        @account.reload
      end

      @@initial_setup_run = false

      def initial_setup
        @portal_id = Account.current.main_portal.id
        return if @@initial_setup_run
        MixpanelWrapper.stubs(:send_to_mixpanel).returns(true)
        Account.stubs(:current).returns(@account)
        $redis_others.perform_redis_op('set', 'ARTICLE_SPAM_REGEX', '(gmail|kindle|face.?book|apple|microsoft|google|aol|hotmail|aim|mozilla|quickbooks|norton).*(support|phone|number)')
        $redis_others.perform_redis_op('set', 'PHONE_NUMBER_SPAM_REGEX', '(1|I)..?8(1|I)8..?85(0|O)..?78(0|O)6|(1|I)..?877..?345..?3847|(1|I)..?877..?37(0|O)..?3(1|I)89|(1|I)..?8(0|O)(0|O)..?79(0|O)..?9(1|I)86|(1|I)..?8(0|O)(0|O)..?436..?(0|O)259|(1|I)..?8(0|O)(0|O)..?969..?(1|I)649|(1|I)..?844..?922..?7448|(1|I)..?8(0|O)(0|O)..?75(0|O)..?6584|(1|I)..?8(0|O)(0|O)..?6(0|O)4..?(1|I)88(0|O)|(1|I)..?877..?242..?364(1|I)|(1|I)..?844..?782..?8(0|O)96|(1|I)..?844..?895..?(0|O)4(1|I)(0|O)|(1|I)..?844..?2(0|O)4..?9294|(1|I)..?8(0|O)(0|O)..?2(1|I)3..?2(1|I)7(1|I)|(1|I)..?855..?58(0|O)..?(1|I)8(0|O)8|(1|I)..?877..?424..?6647|(1|I)..?877..?37(0|O)..?3(1|I)89|(1|I)..?844..?83(0|O)..?8555|(1|I)..?8(0|O)(0|O)..?6(1|I)(1|I)..?5(0|O)(0|O)7|(1|I)..?8(0|O)(0|O)..?584..?46(1|I)(1|I)|(1|I)..?844..?389..?5696|(1|I)..?844..?483..?(0|O)332|(1|I)..?844..?78(0|O)..?675(1|I)|(1|I)..?8(0|O)(0|O)..?596..?(1|I)(0|O)65|(1|I)..?888..?573..?5222|(1|I)..?855..?4(0|O)9..?(1|I)555|(1|I)..?844..?436..?(1|I)893|(1|I)..?8(0|O)(0|O)..?89(1|I)..?4(0|O)(0|O)8|(1|I)..?855..?662..?4436')
        $redis_others.perform_redis_op('set', 'CONTENT_SPAM_CHAR_REGEX', 'ℴ|ℕ|ℓ|ℳ|ℱ|ℋ|ℝ|ⅈ|ℯ|ℂ|○|ℬ|ℂ|ℙ|ℹ|ℒ|ⅉ|ℐ')
        additional = @account.account_additional_settings
        additional.supported_languages = ['es', 'ru-RU'] # dont remove it.
        additional.save
        @account.features.enable_multilingual.create
        subscription = @account.subscription
        subscription.state = 'active'
        subscription.save

        @account.add_feature(:article_filters)
        @account.add_feature(:adv_article_bulk_actions)

        @account.reload
        setup_articles
        @@initial_setup_run = true
        MixpanelWrapper.unstub(:send_to_mixpanel)
        Account.unstub(:current)
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

        create_draft

        @category = Solution::Category.new
        @category.name = "es category #{Time.now}"
        @category.description = "es cat description"
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

      def get_article
        @account.solution_category_meta.where(is_default: false).collect(&:solution_folder_meta).flatten.map { |x| x unless x.is_default }.collect(&:solution_article_meta).flatten.collect(&:children).flatten.first
      end

      def get_article_without_draft
        article = @account.solution_category_meta.where(is_default: false).collect(&:solution_folder_meta).flatten.map { |x| x unless x.is_default }.collect(&:solution_article_meta).flatten.collect(&:children).flatten.first
        article.draft.publish! if article.draft.present?
        article.reload
      end

      def get_article_with_draft
        article = @account.solution_category_meta.where(is_default: false).collect(&:solution_folder_meta).flatten.map { |x| x unless x.is_default }.collect(&:solution_article_meta).flatten.collect(&:children).flatten.first
        if article.draft.blank?
          draft = article.build_draft_from_article
          draft.title = 'Sample'
          draft.save
        end
        article.reload
      end

      def get_folder_meta
        @account.solution_category_meta.where(is_default: false).collect(&:solution_folder_meta).flatten.map { |x| x unless x.is_default }.first
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
        pattern = articles.map { |article| private_api_solution_article_pattern(article) }
        match_json(pattern)
      end

      def test_index_with_valid_ids_array
        article_ids = []
        article_ids = @account.solution_articles.where(language_id: 6).limit(10).collect(&:parent_id)
        get :index, controller_params(version: 'private', ids: article_ids, language: 'en')
        articles = @account.solution_articles.where(parent_id: article_ids, language_id: 6).first(10)
        assert_response 200
        pattern = articles.map { |article| private_api_solution_article_pattern(article) }
        match_json(pattern)
      end

      def test_index_with_valid_ids_and_different_language
        article_ids = []
        article_ids = @account.solution_articles.where(language_id: 8).map(&:parent_id)
        Account.any_instance.stubs(:all_portal_language_objects).returns([Language.find_by_code('es')])
        get :index, controller_params(version: 'private', ids: article_ids, language: 'es')
        articles = @account.solution_articles.where(parent_id: article_ids, language_id: 8).first(10)
        assert_response 200
        pattern = articles.map { |article| private_api_solution_article_pattern(article) }
        match_json(pattern)
        Account.any_instance.unstub(:all_portal_language_objects)
      end

      def test_index_with_additional_params
        article_ids = []
        article_ids = @account.solution_articles.where(language_id: 6).limit(10).collect(&:parent_id)
        get :index, controller_params(version: 'private', ids: article_ids.join(','), language: 'en', test: 2)
        articles = @account.solution_articles.where(parent_id: article_ids, language_id: 6).first(10)
        assert_response 400
        match_json([bad_request_error_pattern('test', :invalid_field)])
      end

      def test_index_with_invalid_language_id
        article_ids = []
        article_ids = @account.solution_articles.limit(10).collect(&:parent_id)
        get :index, controller_params(version: 'private', ids: article_ids.join(','), language: '1000')
        assert_response 400
        match_json([bad_request_error_pattern('language', :not_included, list: @account.all_portal_language_objects.map(&:code))])
      end

      def test_index_with_valid_ids_and_user_id
        article_ids = []
        article_ids = @account.solution_articles.where(language_id: 6).limit(10).collect(&:parent_id)
        get :index, controller_params(version: 'private', ids: article_ids.join(','), user_id: @agent.id, language: 'en')
        articles = @account.solution_articles.where(parent_id: article_ids, language_id: 6).first(10)
        assert_response 200
        pattern = articles.map { |article| private_api_solution_article_pattern(article, {}, true, @agent) }
        match_json(pattern)
      end

      def test_index_with_both_draft_and_article
        draft = @account.solution_drafts.last
        get :index, controller_params(version: 'private', ids: draft.article.parent_id, language: 'en')
        response_body = JSON.parse(response.body).last
        assert_response 200
        response_body.must_match_json_expression private_api_solution_article_pattern(draft.article)
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

      def test_article_content_with_different_language
        Account.any_instance.stubs(:all_portal_language_objects).returns([Language.find_by_code('es')])
        article = @account.solution_articles.where(language_id: 8).last
        get :article_content, controller_params(version: 'private', id: article.parent_id, language: 'es')
        assert_response 200
        match_json(article_content_pattern(article))
        Account.any_instance.unstub(:all_portal_language_objects)
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
        get :article_content, controller_params(version: 'private', id: draft.article.parent_id, language: 'en')
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
        match_json(private_api_solution_article_pattern(sample_article, {}, true, nil, sample_article.draft))
        assert_response 200
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
        match_json(private_api_solution_article_pattern(Solution::Article.last, {}, true, nil, Solution::Article.last.draft))
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

      def test_create_article_with_seo_data
        folder_meta = get_folder_meta
        title = Faker::Name.name
        seo_title = Faker::Name.name
        paragraph = Faker::Lorem.paragraph
        post :create, construct_params({ version: 'private', id: folder_meta.id }, title: title, description: paragraph, status: 2, seo_data: { meta_title: seo_title, meta_keywords: ['tag3','tag4','tag4'] })
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

      def test_update_article_as_draft
        sample_article = get_article_without_draft
        paragraph = Faker::Lorem.paragraph
        params_hash = { title: 'new draft title', description: paragraph, status: 1, agent_id: @agent.id }
        put :update, construct_params({ version: 'private', id: sample_article.parent_id }, params_hash)
        assert_response 200
        assert sample_article.reload.draft
        assert sample_article.reload.draft.reload.title == 'new draft title'
        assert sample_article.reload.draft.reload.status == 1
        match_json(private_api_solution_article_pattern(sample_article.reload, {}, true, nil, sample_article.reload.draft))
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
          tag = "#{tag}#{Time.now.to_i}"
          assert_equal @account.tags.map(&:name).include?(tag), false
          tag
        end
        put :update, construct_params({ version: 'private', id: sample_article.parent_id }, status: 2, tags: tags)
        assert_response 200
        assert_equal sample_article.reload.tags.count, tags.count
        match_json(private_api_solution_article_pattern(sample_article.reload))
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

      def test_update_article_with_new_tags_without_priviledge
        sample_article = get_article
        initial_tag_count = sample_article.tags.count
        tags = Faker::Lorem.words(3).uniq
        tags = tags.map do |tag|
          tag = "#{tag}#{Time.now.to_i}"
          assert_equal @account.tags.map(&:name).include?(tag), false
          tag
        end
        remove_privilege(User.current, :create_tags)
        User.current.reload
        put :update, construct_params({ version: 'private', id: sample_article.parent_id }, status: 1, tags: tags)
        assert_response 400
        match_json([bad_request_error_pattern(:tags, :cannot_create_new_tag, tags: tags.first)])
        assert_equal sample_article.reload.tags.count, initial_tag_count
        add_privilege(User.current, :create_tags)
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
        match_json(private_api_solution_article_pattern(sample_article, {}, true, nil, sample_article.draft))
        assert sample_article.draft.attachments.count == att_count + 2
      end

      def test_update_article_add_cloud_attachment_publish
        sample_article = get_article_without_draft
        att_count = sample_article.cloud_files.count
        app = create_application('dropbox')
        cloud_file_params = [{ name: 'image.jpg', url: CLOUD_FILE_IMAGE_URL, application_id: app.first.application_id }]
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
        cloud_file_params = [{ name: 'image.jpg', url: CLOUD_FILE_IMAGE_URL, application_id: app.first.application_id }]
        put :update, construct_params({ version: 'private', id: sample_article.parent_id }, status: 1, cloud_file_attachments: cloud_file_params)
        assert_response 200
        sample_article.reload
        match_json(private_api_solution_article_pattern(sample_article, {}, true, nil, sample_article.draft))
        assert sample_article.draft.cloud_files.count == att_count + 1
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

      def test_delete_article_someone_editing
        sample_article = get_article_with_draft
        Solution::Draft.any_instance.stubs(:locked?).returns(true)
        delete :destroy, construct_params(version: 'private', id: sample_article.parent_id)
        assert_response 400
        match_json(request_error_pattern_with_info(:draft_locked, {}, user_id: sample_article.draft.user_id))
        Solution::Draft.any_instance.unstub(:locked?)
      end

      def test_create_without_publish_solution_privilege
        folder_meta = get_folder_meta
        title = Faker::Name.name
        paragraph = Faker::Lorem.paragraph
        User.any_instance.stubs(:privilege?).with(:publish_solution).returns(false)
        post :create, construct_params({ version: 'private', id: folder_meta.id }, title: title, description: paragraph, status: 1)
        assert_response 403
        match_json(request_error_pattern(:access_denied))
        User.any_instance.unstub(:privilege?)
      end

      def test_update_without_publish_solution_privilege
        sample_article = get_article_without_draft
        paragraph = Faker::Lorem.paragraph
        params_hash = { title: 'new draft title', description: paragraph, status: 1, agent_id: @agent.id }
        User.any_instance.stubs(:privilege?).with(:publish_solution).returns(false)
        put :update, construct_params({ version: 'private', id: sample_article.parent_id }, params_hash)
        assert_response 403
        match_json(request_error_pattern(:access_denied))
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
        User.any_instance.stubs(:privilege?).with(:create_tags).returns(false)
        User.any_instance.stubs(:privilege?).with(:publish_solution).returns(true)
        article = @account.solution_articles.where(language_id: 6).last
        tags = [Faker::Name.name, Faker::Name.name]
        put :bulk_update, construct_params({ version: 'private' }, ids: [article.parent_id], properties: { tags: tags })
        assert_response 400
      ensure
        User.any_instance.unstub(:privilege?)
      end

      def test_bulk_update_old_tags_without_tags_privilege
        User.any_instance.stubs(:privilege?).with(:create_tags).returns(false)
        User.any_instance.stubs(:privilege?).with(:publish_solution).returns(true)
        article = @account.solution_articles.where(language_id: 6).last
        tag = Helpdesk::Tag.where(name: Faker::Name.name, account_id: @account.id).first_or_create
        put :bulk_update, construct_params({ version: 'private' }, ids: [article.parent_id], properties: { tags: [tag.name] })
        assert_response 204
        assert ([tag.name] - article.reload.tags.map(&:name)).empty?
      ensure
        User.any_instance.unstub(:privilege?)
      end

      def test_bulk_update_author_without_feature
        Account.any_instance.stubs(:adv_article_bulk_actions_enabled?).returns(false)
        folder = @account.solution_folder_meta.where(is_default: false).first
        populate_articles(folder)
        articles = folder.solution_article_meta.pluck(:id)
        agent_id = add_test_agent.id
        User.any_instance.stubs(:privilege?).with(:publish_solution).returns(true)
        User.any_instance.stubs(:privilege?).with(:admin_tasks).returns(true)
        put :bulk_update, construct_params({ version: 'private' }, ids: articles, properties: { agent_id: agent_id })
        assert_response 403
        match_json(validation_error_pattern(bad_request_error_pattern('properties[:agent_id]', :require_feature, feature: :adv_article_bulk_actions, code: :access_denied)))
      ensure
        Account.any_instance.unstub(:adv_article_bulk_actions_enabled?)
      end

      def test_bulk_update_author
        folder = @account.solution_folder_meta.where(is_default: false).first
        populate_articles(folder)
        articles = folder.solution_article_meta.pluck(:id)
        agent_id = add_test_agent.id
        User.any_instance.stubs(:privilege?).with(:publish_solution).returns(true)
        User.any_instance.stubs(:privilege?).with(:admin_tasks).returns(true)
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
        User.any_instance.stubs(:privilege?).with(:publish_solution).returns(true)
        User.any_instance.stubs(:privilege?).with(:admin_tasks).returns(true)
        put :bulk_update, construct_params({ version: 'private', language: language.code }, ids: articles, properties: { agent_id: agent_id })
        assert_response 204
        article_meta.children.where(language_id: language.id).first.user_id = agent_id
      ensure
        User.any_instance.unstub(:privilege?)
      end

      def test_bulk_update_author_for_non_supported_language
        User.any_instance.stubs(:privilege?).with(:publish_solution).returns(true)
        User.any_instance.stubs(:privilege?).with(:admin_tasks).returns(true)
        non_supported_language = get_valid_not_supported_language
        put :bulk_update, construct_params({ version: 'private', language: non_supported_language }, ids: [1], properties: { agent_id: 1 })
        assert_response 404
        match_json(request_error_pattern(:language_not_allowed, code: non_supported_language, list: (@account.supported_languages + [@account.language]).sort.join(', ')))
      ensure
        User.any_instance.unstub(:privilege?)
      end

      def test_bulk_update_with_language_without_multilingual_feature
        Account.any_instance.stubs(:multilingual?).returns(false)
        User.any_instance.stubs(:privilege?).with(:publish_solution).returns(true)
        User.any_instance.stubs(:privilege?).with(:admin_tasks).returns(true)
        put :bulk_update, construct_params({ version: 'private', language: get_valid_not_supported_language }, ids: [1], properties: { agent_id: 1 })
        assert_response 404
        match_json(request_error_pattern(:require_feature, feature: 'MultilingualFeature'))
      ensure
        Account.any_instance.unstub(:multilingual?)
        User.any_instance.unstub(:privilege?)
      end

      def test_update_article_unpublish_with_incorrect_credentials
        @controller.stubs(:api_current_user).raises(ActiveSupport::MessageVerifier::InvalidSignature)
        put :update, construct_params(version: 'private', id: 1, status: Solution::Article::STATUS_KEYS_BY_TOKEN[:draft])
        assert_response 401
        assert_equal request_error_pattern(:credentials_required).to_json, response.body
      ensure
        @controller.unstub(:api_current_user)
      end

      def test_update_article_unpublish_without_publish_solution_privilege
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
        assert_equal Solution::Article::STATUS_KEYS_BY_TOKEN[:draft], article.primary_article.status
      end

      def test_update_article_unpublish_with_language_without_multilingual_feature
        allowed_features = Account.first.features.where(' type not in (?) ', ['EnableMultilingualFeature'])
        Account.any_instance.stubs(:features).returns(allowed_features)
        put :update, construct_params(version: 'private', id: 0, status: Solution::Article::STATUS_KEYS_BY_TOKEN[:draft], language: @account.language)
        match_json(request_error_pattern(:require_feature, feature: 'MultilingualFeature'))
        assert_response 404
      ensure
        Account.any_instance.unstub(:features)
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
        assert_equal Solution::Article::STATUS_KEYS_BY_TOKEN[:draft], article.primary_article.status
      end

      def test_update_article_unpublish_with_supported_language
        languages = @account.supported_languages + ['primary']
        language = @account.supported_languages.first
        article = create_article(article_params(lang_codes: languages))
        put :update, construct_params(version: 'private', id: article.id, status: Solution::Article::STATUS_KEYS_BY_TOKEN[:draft], language: language)
        assert_response 200
        assert_equal Solution::Article::STATUS_KEYS_BY_TOKEN[:draft], article.safe_send("#{language}_article").status
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

      def test_reset_ratings_with_language_without_multilingual_feature
        allowed_features = Account.first.features.where(' type not in (?) ', ['EnableMultilingualFeature'])
        Account.any_instance.stubs(:features).returns(allowed_features)
        put :reset_ratings, construct_params(version: 'private', id: 0, language: @account.language)
        match_json(request_error_pattern(:require_feature, feature: 'MultilingualFeature'))
        assert_response 404
      ensure
        Account.any_instance.unstub(:features)
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

      def test_votes_with_language_without_multilingual_feature
        allowed_features = Account.first.features.where(' type not in (?) ', ['EnableMultilingualFeature'])
        Account.any_instance.stubs(:features).returns(allowed_features)
        get :votes, controller_params(version: 'private', id: 0, language: @account.language)
        match_json(request_error_pattern(:require_feature, feature: 'MultilingualFeature'))
        assert_response 404
      ensure
        Account.any_instance.unstub(:features)
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
        get :filter, controller_params(version: 'private', :author=>"1")
        assert_response 400
        match_json([bad_request_error_pattern('portal_id', "Mandatory attribute missing", code: :missing_field)])
      end

      def test_filter_without_view_solutions_privilege
        User.any_instance.stubs(:privilege?).with(:view_solutions).returns(false)
        get :filter, controller_params(version: 'private')
        assert_response 403
        match_json(request_error_pattern(:access_denied))
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
        get :filter, controller_params(version: 'private', :portal_id=>@portal_id, :by_status=>"1")
        assert_response 400
        match_json([bad_request_error_pattern('by_status', :invalid_field)])
      end

      def test_article_filters
        article_ids = []
        article_ids = @account.solution_articles.where(language_id: 6).collect(&:parent_id)
        get :filter, controller_params(version: 'private', portal_id: @portal_id, language: 'en')
        articles = @account.solution_articles.where(parent_id: article_ids, language_id: 6).first(10)
        assert_response 200
        pattern = articles.map { |article| private_api_solution_article_pattern(article, {action: :filter}, true, nil, article.draft) }
        match_json(pattern)
      end

      def test_article_filters_with_invalid_language
        get :filter, controller_params(version: 'private', portal_id: @portal_id, language: 'sample')
        assert_response 404
        match_json(request_error_pattern(:language_not_allowed, code: 'sample', list: (@account.supported_languages + [@account.language]).sort.join(', ')))
      end

      def test_article_filters_all_attributes
        author_id = @account.agents.first.id
        article_meta = create_article({:user_id=>author_id, :folder_meta_id=>@@folder_meta.id})
        article = article_meta.solution_articles.first
        tag = Faker::Lorem.characters(7)
        create_tag_use(@account, {:taggable_type=>"Solution::Article", :taggable_id=>article.id, :name=>tag, 
          :allow_skip => true})
        get :filter, controller_params({version: 'private', :portal_id=>"#{@portal_id}", :status=>"2", 
              :author=> "#{author_id}", :category => ["#{@@category_meta.id}"], :folder => ["#{@@folder_meta.id}"], 
              :created_at => {:start=>"20190101",:end=>"21190101"}, :last_modified => {:start=>"20190101",:end=>"21190101"}, :tags => [tag]},false)
        article.reload
        assert_response 200
        pattern = private_api_solution_article_pattern(article, {action: :filter}, true, nil, article.draft)
        match_json([pattern])
      end

      def test_article_filters_with_no_results
        author_id = @account.agents.first.id
        article_meta = create_article({:user_id=>author_id, :folder_meta_id=>@@folder_meta.id})
        article = article_meta.solution_articles.first
        get :filter, controller_params({version: 'private', :portal_id=>"#{@portal_id}", :status=>"2", 
              :author=> "#{author_id}", :category => ["#{@@category_meta.id}"], :folder => ["#{@@folder_meta.id}"], 
              :created_at => {:start=>"20190101",:end=>"21190101"}, :last_modified => {:start=>"20190101",:end=>"21190101"}, :tags => ["sample"]},false)
        article.reload
        assert_response 200
        match_json([])
      end

      def test_article_filters_with_drafts
        author_id = @account.agents.first.id
        article_meta = create_article({:user_id=>author_id, :folder_meta_id=>@@folder_meta.id})
        article = article_meta.solution_articles.first
        new_user = add_test_agent
        create_draft({:article=>article, :user_id => new_user.id, :keep_previous_author => true})
        tag = Faker::Lorem.characters(7)
        create_tag_use(@account, {:taggable_type=>"Solution::Article", :taggable_id=>article.id, :name=>tag, 
          :allow_skip => true})
        get :filter, controller_params({version: 'private', :portal_id=>"#{@portal_id}", :status=>"1", 
              :author=> "#{new_user.id}", :category => ["#{@@category_meta.id}"], :folder => ["#{@@folder_meta.id}"], 
              :created_at => {:start=>"20190101",:end=>"21190101"}, :last_modified => {:start=>"20190101",:end=>"21190101"}, :tags => [tag]},false)
        article.reload
        assert_response 200
        pattern = private_api_solution_article_pattern(article, {action: :filter}, true, nil, article.draft)
        match_json([pattern])
      end

      def test_article_filters_published_with_drafts
        author_id = @account.agents.first.id
        article_meta = create_article({:user_id=>author_id, :folder_meta_id=>@@folder_meta.id})
        article = article_meta.solution_articles.first
        new_user = add_test_agent
        create_draft({:article=>article, :user_id => new_user.id, :keep_previous_author => true})
        tag = Faker::Lorem.characters(7)
        create_tag_use(@account, {:taggable_type=>"Solution::Article", :taggable_id=>article.id, :name=>tag, 
          :allow_skip => true})
        get :filter, controller_params({version: 'private', :portal_id=>"#{@portal_id}", :status=>"2", 
              :author=> "#{new_user.id}", :category => ["#{@@category_meta.id}"], :folder => ["#{@@folder_meta.id}"],
              :created_at => {:start=>"20190101",:end=>"21190101"}, :last_modified => {:start=>"20190101",:end=>"21190101"}, :tags => [tag]},false)
        article.reload
        assert_response 200
        pattern = private_api_solution_article_pattern(article, {action: :filter}, true, nil, article.draft)
        match_json([pattern])
      end

      def test_article_filters_unpublished_diff_user
        author_id = add_test_agent.id
        article_meta = create_article({:user_id=>author_id, :folder_meta_id=>@@folder_meta.id, :status=>"1"})
        article = article_meta.solution_articles.first
        tag = Faker::Lorem.characters(7)
        create_tag_use(@account, {:taggable_type=>"Solution::Article", :taggable_id=>article.id, :name=>tag, 
          :allow_skip => true})
        get :filter, controller_params({version: 'private', :portal_id=>"#{@portal_id}", :status=>"1", 
              :author=> "#{author_id}", :category => ["#{@@category_meta.id}"], :folder => ["#{@@folder_meta.id}"], 
              :created_at => {:start=>"20190101",:end=>"21190101"}, :last_modified => {:start=>"20190101",:end=>"21190101"}, :tags => [tag]},false)
        assert_response 200
        match_json([])
      end

      def test_article_filters_unpublished
        author_id = @account.agents.first.id
        article_meta = create_article({:user_id=>author_id, :folder_meta_id=>@@folder_meta.id, :status=>"1"})
        article = article_meta.solution_articles.first
        new_user = add_test_agent
        draft = article.draft
        draft.user_id = new_user.id
        draft.keep_previous_author = true
        draft.save
        tag = Faker::Lorem.characters(7)
        create_tag_use(@account, {:taggable_type=>"Solution::Article", :taggable_id=>article.id, :name=>tag, 
          :allow_skip => true})
        get :filter, controller_params({version: 'private', :portal_id=>"#{@portal_id}", :status=>"1", 
              :author=> "#{new_user.id}", :category => ["#{@@category_meta.id}"], :folder => ["#{@@folder_meta.id}"],
              :created_at => {:start=>"20190101",:end=>"21190101"}, :last_modified => {:start=>"20190101",:end=>"21190101"}, :tags => [tag]},false)
        article.reload
        assert_response 200
        pattern = private_api_solution_article_pattern(article, {action: :filter}, true, nil, article.draft)
        match_json([pattern])
      end

      def test_article_filters_modifier
        author_id = @account.agents.first.id
        article_meta = create_article({:user_id=>author_id, :folder_meta_id=>@@folder_meta.id})
        article = article_meta.solution_articles.first
        new_user = add_test_agent
        article.modified_by = new_user.id
        article.save
        get :filter, controller_params({version: 'private', :portal_id=>"#{@portal_id}", :status=>"2", 
              :author=> "#{new_user.id}", :category => ["#{@@category_meta.id}"], :folder => ["#{@@folder_meta.id}"], :last_modified => {:start=>"20190101",:end=>"21190101"}},false)
        article.reload
        assert_response 200
        pattern = private_api_solution_article_pattern(article, {action: :filter}, true, nil, article.draft)
        match_json([pattern])
      end

      def test_article_filters_invalid_modifier
        get :filter, controller_params({version: 'private', :portal_id=>"#{@portal_id}", 
            :author=> Faker::Lorem.characters(4)},false)
        assert_response 400
      end

      def test_article_filters_with_search_term
        article_title = Faker::Lorem.characters(10)
        article = create_article(article_params({title: article_title})).primary_article
        stub_private_search_response([article]) do
          get :filter, controller_params(version: 'private', :portal_id=>@portal_id, term: article_title)
        end
        article.reload
        assert_response 200
        pattern = private_api_solution_article_pattern(article, {action: :filter}, true, nil, article.draft)
        match_json([pattern])
      end

      def test_article_filters_with_default_article
        default_category = @account.solution_category_meta.where(:is_default => true).first
        default_folder = default_category.solution_folder_meta.first
        article_meta = create_article({:folder_meta_id=>default_folder.id, :status=>"1"})
        article = article_meta.solution_articles.first
        create_draft({:article=>article, :keep_previous_author => true})
        get :filter, controller_params({version: 'private', :portal_id=>"#{@portal_id}", :status=>"1", 
                      :category => ["#{default_category.id}"]},false)
        article.reload
        assert_response 200
        pattern = private_api_solution_article_pattern(article, {action: :filter}, true, nil, article.draft)
        match_json([pattern])
      end

      def test_article_filters_by_folder
        article_meta = @account.solution_article_meta.where(solution_folder_meta_id: @@folder_meta.id)
        if article_meta.blank?
          article_meta = create_article({:folder_meta_id=>@@folder_meta.id})
          articles = article_meta.solution_articles.first
        else
          articles = article_meta.map(&:primary_article).flatten
        end
        get :filter, controller_params({version: 'private', :portal_id=>"#{@portal_id}", :folder => ["#{@@folder_meta.id}"]},false)
        assert_response 200
        pattern = articles.map { |article| private_api_solution_article_pattern(article, {action: :filter}, true, nil, article.draft) }
        match_json(pattern)
      end

      def test_article_filters_by_category_folder
        article_meta = @account.solution_article_meta.where(solution_folder_meta_id: @@folder_meta.id)
        if article_meta.blank?
          article_meta = create_article({:folder_meta_id=>@@folder_meta.id})
          articles = article_meta.solution_articles.first
        else
          articles = article_meta.map(&:primary_article).flatten
        end
        get :filter, controller_params({version: 'private', :portal_id=>"#{@portal_id}", :category => ["#{@@category_meta.id}"], :folder => ["#{@@folder_meta.id}"]},false)
        assert_response 200
        pattern = articles.map { |article| private_api_solution_article_pattern(article, {action: :filter}, true, nil, article.draft) }
        match_json(pattern)
      end

      def test_article_filters_by_category_folder_mismatched
        article_meta = create_article({:folder_meta_id=>@@folder_meta.id})
        article = article_meta.solution_articles.first
        get :filter, controller_params({version: 'private', :portal_id=>"#{@portal_id}", :category => ["#{@@category_meta.id}"], 
          :folder => ["10101010100000"]},false)
        assert_response 200
        match_json([])
      end

      def test_article_filters_by_tags
        author_id = @account.agents.first.id
        article_meta = create_article({:user_id=>author_id, :folder_meta_id=>@@folder_meta.id})
        article = article_meta.solution_articles.first
        tag = Faker::Lorem.characters(7)
        create_tag_use(@account, {:taggable_type=>"Solution::Article", :taggable_id=>article.id, :name=>tag, 
          :allow_skip => true})
        get :filter, controller_params({version: 'private', :portal_id=>"#{@portal_id}", :tags => [tag]},false)
        article.reload
        assert_response 200
        pattern = private_api_solution_article_pattern(article, {action: :filter}, true, nil, article.draft)
        match_json([pattern])
      end

      def test_article_filters_by_status
        articles = @account.solution_articles.where(status: "2", language_id: 6)
        if articles.blank?
          article_meta = create_article({:folder_meta_id=>@@folder_meta.id})
          articles = article_meta.solution_articles
        end
        get :filter, controller_params({version: 'private', :portal_id=>"#{@portal_id}", :status=>"2"},false)
        assert_response 200
        pattern = articles.map { |article| private_api_solution_article_pattern(article, {action: :filter}, true, nil, article.draft) }
        match_json(pattern)
      end

      def test_article_filters_by_author_lastmodified
        author_id = add_test_agent.id
        article_meta = create_article({:user_id=>author_id, :folder_meta_id=>@@folder_meta.id})
        article = article_meta.solution_articles.first
        get :filter, controller_params({version: 'private', :portal_id=>"#{@portal_id}", 
              :author=> "#{author_id}", :last_modified => {:start=>"20190101",:end=>"21190101"}},false)
        article.reload
        assert_response 200
        pattern = private_api_solution_article_pattern(article, {action: :filter}, true, nil, article.draft)
        match_json([pattern])
      end

      def test_article_filters_by_author_createdat_mismatched
        author_id = add_test_agent.id
        article_meta = create_article({:user_id=>author_id, :folder_meta_id=>@@folder_meta.id})
        article = article_meta.solution_articles.first
        start_date = Time.now + 10.days
        end_date = Time.now + 20.days
        get :filter, controller_params({version: 'private', :portal_id=>"#{@portal_id}", 
              :author=> "#{author_id}", :created_at => {:start=>"#{start_date}",:end=>"#{end_date}"}},false)
        assert_response 200
        match_json([])
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
        User.any_instance.stubs(:privilege?).with(:publish_solution).returns(false)
        folder = @account.solution_folder_meta.where(is_default: false).first
        populate_articles(folder)
        put :reorder, construct_params({ version: 'private' }, id: folder.solution_article_meta.first.id, position: 2)
        assert_response 403
      ensure
        User.any_instance.unstub(:privilege?)
      end

      def test_article_filters_with_secondary_language_nodata
        Account.any_instance.stubs(:supported_languages).returns(['et'])
        Account.any_instance.stubs(:all_portal_language_objects).returns([Language.find_by_code('et')])
        get :filter, controller_params(version: 'private', portal_id: @portal_id, language: 'et')
        assert_response 200
        match_json([])
        Account.any_instance.unstub(:supported_languages)
        Account.any_instance.unstub(:all_portal_language_objects)
      end

      def test_article_filters_with_secondary_language
        languages = @account.supported_languages + ['primary']
        language = @account.supported_languages.first
        articles = @account.solution_articles.where(language_id: Language.find_by_code(language).id)
        if articles.blank?
          article_meta = create_article(article_params(lang_codes: languages))
          articles = [article_meta.safe_send("#{language}_article")]
        end
        Account.any_instance.stubs(:all_portal_language_objects).returns([Language.find_by_code(language)])
        get :filter, controller_params(version: 'private', portal_id: @portal_id, language: language)
        assert_response 200
        pattern = articles.map { |article| private_api_solution_article_pattern(article, { action: :filter }, true, nil, article.draft) }
        match_json(pattern)
        Account.any_instance.unstub(:all_portal_language_objects)
      end

      def test_article_filters_all_attributes_with_secondary_language
        languages = @account.supported_languages + ['primary']
        language = @account.supported_languages.first
        author_id = @account.agents.first.id
        article_meta = create_article(user_id: author_id, folder_meta_id: @@folder_meta.id, lang_codes: languages)
        article = article_meta.safe_send("#{language}_article")
        tag = Faker::Lorem.characters(7)
        create_tag_use(@account, taggable_type: "Solution::Article", taggable_id: article.id, name: tag, allow_skip: true)
        Account.any_instance.stubs(:all_portal_language_objects).returns([Language.find_by_code(language)])
        get :filter, controller_params({ version: 'private', portal_id: "#{@portal_id}", language: language, status: "2", 
              author: "#{author_id}", category: ["#{@@category_meta.id}"], folder: ["#{@@folder_meta.id}"], 
              created_at: { start: "20190101", end: "21190101" }, last_modified: { start: "20190101", end: "21190101" }, tags: [tag] }, false)
        article.reload
        assert_response 200
        pattern = private_api_solution_article_pattern(article, { action: :filter }, true, nil, article.draft)
        match_json([pattern])
        Account.any_instance.unstub(:all_portal_language_objects)
      end

      def test_article_filters_with_diff_sec_lang
        author_id = add_test_agent.id
        languages = @account.supported_languages + ['primary']
        language = @account.supported_languages.first
        article_meta = create_article({user_id: author_id, folder_meta_id: @@folder_meta.id, lang_codes: languages})
        Account.any_instance.stubs(:all_portal_language_objects).returns([Language.find_by_code('ru-RU')])
        get :filter, controller_params({ version: 'private', portal_id: "#{@portal_id}", language: 'ru-RU', author: "#{author_id}" }, false)
        assert_response 200
        match_json([])
        Account.any_instance.unstub(:all_portal_language_objects)
      end

      def test_article_filters_by_category_folder_with_sec_lang
        languages = @account.supported_languages + ['primary']
        language  = @account.supported_languages.first
        author_id = add_test_agent.id
        article_meta = create_article(user_id: author_id, folder_meta_id: @@folder_meta.id, lang_codes: languages)
        article = article_meta.safe_send("#{language}_article")
        Account.any_instance.stubs(:all_portal_language_objects).returns([Language.find_by_code(language)])
        get :filter, controller_params({ version: 'private', portal_id: "#{@portal_id}", language: language, category: ["#{@@category_meta.id}"], folder: ["#{@@folder_meta.id}"], author: "#{author_id}"}, false)
        article.reload
        assert_response 200
        pattern = private_api_solution_article_pattern(article, { action: :filter }, true, nil, article.draft)
        match_json([pattern])
        Account.any_instance.unstub(:all_portal_language_objects)
      end

      def test_article_filters_by_category_folder_mismatched_with_sec_lang
        languages = @account.supported_languages + ['primary']
        language  = @account.supported_languages.first
        article_meta = create_article({folder_meta_id: @@folder_meta.id, lang_codes: languages})
        Account.any_instance.stubs(:all_portal_language_objects).returns([Language.find_by_code(language)])
        get :filter, controller_params({ version: 'private', portal_id: "#{@portal_id}", language: language, category: ["10101010100000"], folder: ["#{@@folder_meta.id}"] }, false)
        assert_response 200
        match_json([])
        Account.any_instance.unstub(:all_portal_language_objects)
      end

      def test_article_filters_by_status_with_sec_lang
        languages = @account.supported_languages + ['primary']
        language  = @account.supported_languages.first
        articles = @account.solution_articles.where(status: "2", language_id: 8)
        if articles.blank?
           article_meta = create_article({ folder_meta_id: @@folder_meta.id, lang_codes: languages })
           articles = [article_meta.safe_send("#{language}_article")]
        end
        Account.any_instance.stubs(:all_portal_language_objects).returns([Language.find_by_code(language)])
        get :filter, controller_params({ version: 'private', portal_id: "#{@portal_id}", language: language, status: "2" }, false)
        assert_response 200
        pattern = articles.map { |article| private_api_solution_article_pattern(article, { action: :filter }, true, nil, article.draft) }
        match_json(pattern)
        Account.any_instance.unstub(:all_portal_language_objects)
      end

      def test_article_filters_by_author_lastmodified_with_sec_lang
        languages = @account.supported_languages + ['primary']
        language  = @account.supported_languages.first
        author_id = add_test_agent.id
        article_meta = create_article({:user_id=>author_id, :folder_meta_id=>@@folder_meta.id, lang_codes: languages})
        article = article_meta.safe_send("#{language}_article")
        Account.any_instance.stubs(:all_portal_language_objects).returns([Language.find_by_code(language)])
        get :filter, controller_params({ version: 'private', portal_id: "#{@portal_id}", language: language, author: "#{author_id}", last_modified: { start: "20190101", end: "21190101" }}, false)
        article.reload
        assert_response 200
        pattern = private_api_solution_article_pattern(article, {action: :filter}, true, nil, article.draft)
        match_json([pattern])
        Account.any_instance.unstub(:all_portal_language_objects)
      end

      def test_article_filters_by_author_createdat_mismatched_with_sec_lang
        languages = @account.supported_languages + ['primary']
        language  = @account.supported_languages.first
        author_id = add_test_agent.id
        article_meta = create_article({:user_id=>author_id, :folder_meta_id=>@@folder_meta.id, lang_codes: languages})
        articles = article_meta.safe_send("#{language}_article")
        start_date = Time.now + 10.days
        end_date = Time.now + 20.days
        Account.any_instance.stubs(:all_portal_language_objects).returns([Language.find_by_code(language)])
        get :filter, controller_params({version: 'private', :portal_id=>"#{@portal_id}", language: language, 
              :author=> "#{author_id}", :created_at => {:start=>"#{start_date}",:end=>"#{end_date}"}},false)
        assert_response 200
        match_json([])
        Account.any_instance.unstub(:all_portal_language_objects)
      end

      private

        def get_valid_not_supported_language
          languages = @account.supported_languages + [@account.language]
          Language.all.map(&:code).find { |language| !languages.include?(language) }
        end

        def get_article_meta_with_translation
          @account.solution_category_meta.where(is_default: false).collect(&:solution_article_meta).flatten.map { |x| x if x.children.count > 1 }.flatten.reject(&:blank?).first
        end

        def populate_articles(folder_meta)
          return if folder_meta.article_count > 10

          (1..10).each do |i|
            articlemeta = Solution::ArticleMeta.new
            articlemeta.art_type = 1
            articlemeta.solution_folder_meta_id = folder_meta.id
            articlemeta.solution_category_meta = folder_meta.solution_category_meta
            articlemeta.account_id = @account.id
            articlemeta.published = false
            articlemeta.save

            article_with_lang = Solution::Article.new
            article_with_lang.title = "#{Faker::Name.name} #{i}"
            article_with_lang.description = '<b>aaa</b>'
            article_with_lang.status = 1
            article_with_lang.language_id = @account.language_object.id
            article_with_lang.parent_id = articlemeta.id
            article_with_lang.account_id = @account.id
            article_with_lang.user_id = @account.agents.first.id
            article_with_lang.save
          end
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

        def create_draft options = {}
          @draft = Solution::Draft.new
          @draft.account = @account
          @draft.article = options[:article] || @@article
          @draft.title = 'Sample'
          @draft.category_meta = @@folder_meta.solution_category_meta
          @draft.status = 1
          @draft.keep_previous_author = true if options[:keep_previous_author]
          @draft.user_id = options[:user_id] if options[:user_id]
          @draft.description = '<b>aaa</b>'
          @draft.save

          @draft_body = Solution::DraftBody.new
          @draft_body.draft = @draft
          @draft_body.description = '<b>aaa</b>'
          @draft_body.account = @account
          @draft_body.save
        end
    end
  end
end
