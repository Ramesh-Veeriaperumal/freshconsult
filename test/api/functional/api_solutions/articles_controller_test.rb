require_relative '../../test_helper'
module ApiSolutions
  class ArticlesControllerTest < ActionController::TestCase
    include SolutionsTestHelper

    def setup
      super
      initial_setup
    end

    @@initial_setup_run = false

    def initial_setup
      return if @@initial_setup_run
      @account.launch(:translate_solutions)
      additional = @account.account_additional_settings
      additional.supported_languages = ["es","ru-RU"]
      additional.save
      @account.features.enable_multilingual.create
      @account.reload
      setup_articles
      @@initial_setup_run = true
    end

    def setup_articles
      @articlemeta = Solution::ArticleMeta.new
      @articlemeta.art_type = 1
      @articlemeta.solution_folder_meta_id = Solution::FolderMeta.first.id
      @articlemeta.account_id = @account.id
      @articlemeta.published = false
      @articlemeta.save

      @article = Solution::Article.new
      @article.title = "Sample"
      @article.description = "<b>aaa</b>"
      @article.status = 1
      @article.language_id = @account.language_object.id
      @article.parent_id = @articlemeta.id
      @article.account_id = @account.id
      @article.user_id = @account.agents.first.id
      @article.save
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
      { article: params }
    end

    def get_article
      @account.solution_category_meta.where(is_default: false).collect{ |x| x.solution_folder_meta }.flatten.map{ |x| x unless x.is_default}.collect{ |x| x.solution_article_meta }.flatten.collect{ |x| x.children }.flatten.first
    end

    def get_article_with_draft
      @account.solution_category_meta.where(is_default: false).collect{ |x| x.solution_folder_meta }.flatten.map{ |x| x unless x.is_default}.collect{ |x| x.solution_article_meta }.flatten.collect{ |x| x.children }.flatten.select{ |x| x.draft.present? }.first
    end

    def get_folder_meta
      @account.solution_category_meta.where(is_default: false).collect{ |x| x.solution_folder_meta }.flatten.map{ |x| x unless x.is_default}.first
    end

    def get_category_with_folders
      @account.solution_category_meta.select { |x| x if x.children.count > 0 }.first
    end

    def get_folder_without_translation
      @account.solution_folders.group('parent_id').having('count(*) = 1').first
    end

    def get_folder_with_translation
      @account.solution_folders.group('parent_id').having('count(*) > 1').first
    end

    def get_article_without_translation
      @account.solution_category_meta.where(is_default:false).collect{ |x| x.solution_article_meta }.flatten.map{ |x| x.children if x.children.count == 1}.flatten.reject(&:blank?).first
    end

    def get_article_with_translation
      @account.solution_category_meta.where(is_default:false).collect{ |x| x.solution_article_meta }.flatten.map{ |x| x.children if x.children.count > 1}.flatten.reject(&:blank?).first
    end


    def get_default_folder
      @account.solution_folder_meta.where(is_default: true).collect{ |x| x.children }.flatten.first
    end

    def test_show_article
      sample_article = get_article
      get :show, controller_params(id: sample_article.parent_id)
      match_json(solution_article_pattern(sample_article))
      assert_response 200
    end

    def test_show_unavailalbe_article
      get :show, controller_params(id: 99999)
      assert_response :missing
    end

    def test_show_unavailalbe_article_with_language
      get :show, controller_params({id: 99999, language: @account.supported_languages.last})
      assert_response :missing
    end


    def test_show_article_with_language_query_param
      sample_article = get_article
      get :show, controller_params(id: sample_article.parent_id, language: @account.language)
      match_json(solution_article_pattern(sample_article))
      assert_response 200
    end

    def test_show_article_with_invalid_language_query_param
      sample_article = get_article
      get :show, controller_params(id: sample_article.parent_id, language: 'xaasd')
      assert_response 404
      match_json(request_error_pattern(:language_not_allowed, code: 'xaasd', list: (@account.supported_languages + [@account.language]).sort.join(', ')))
    end

    # Feature Check
    def test_show_article_with_language_and_without_multilingual_feature
      allowed_features = Account.first.features.where(' type not in (?) ', ['EnableMultilingualFeature'])
      Account.any_instance.stubs(:features).returns(allowed_features)
      sample_article = get_article
      get :show, controller_params({id: sample_article.parent_id, language: @account.language })
      match_json(request_error_pattern(:require_feature, feature: 'MultilingualFeature'))
      assert_response 404
    ensure
      Account.any_instance.unstub(:features)
    end

    def test_create_article
      folder_meta = get_folder_meta
      title = Faker::Name.name
      paragraph = Faker::Lorem.paragraph
      post :create, construct_params({ id: folder_meta.id }, {title: title, description: paragraph, status: 1, type: 2})
      assert_response 201
      result = parse_response(@response.body)
      assert_equal "http://#{@request.host}/api/v2/solutions/articles/#{result['id']}", response.headers['Location']
      match_json(solution_article_pattern(Solution::Article.last))
      article = Solution::Article.last
      assert article.title == title
      assert article.desc_un_html.strip == paragraph
      assert article.user_id == @agent.id
      assert article.status == 1
      assert article.parent.art_type == 2
    end

    def test_create_article_in_primary_language
      folder_meta = get_folder_meta
      title = Faker::Name.name
      paragraph = Faker::Lorem.paragraph
      post :create, construct_params({ id: folder_meta.id }, {title: title, description: paragraph, status: 1, type: 2})
      assert_response 201
      match_json(solution_article_pattern(Solution::Article.last))
      article = Solution::Article.last
      assert article.title == title
      assert article.desc_un_html.strip == paragraph
      assert article.user_id == @agent.id
      assert article.status == 1
      assert article.parent.art_type == 2
    end

    def test_create_article_with_html_content
      folder_meta = get_folder_meta
      title = Faker::Name.name
      paragraph = "<h2 style=\"color: rgb(0, 0, 0); margin-top: 1em; margin-bottom: 0.25em; overflow: hidden; border-bottom-width: 1px; border-bottom-style: solid; border-bottom-color: rgb(170, 170, 170); font-family: 'Linux Libertine', Georgia, Times, serif, 'Helvetica Neue', Helvetica, Arial, sans-serif; line-height: 1.3;\">\n<span id=\"Etymology\">Etymology</span><span style=\"-webkit-user-select: none; font-size: small; font-weight: normal; margin-left: 1em; line-height: 1em; display: inline-block; white-space: nowrap; unicode-bidi: isolate; font-family: sans-serif, 'Helvetica Neue', Helvetica, Arial, sans-serif;\"><span style=\"margin-right: 0.25em; color: rgb(85, 85, 85);\">[</span><a href=\"https://en.wikipedia.org/w/index.php?title=Tamils&amp;action=edit&amp;section=1\" title=\"Edit section: Etymology\" style=\"color: rgb(11, 0, 128); background-image: none;\">edit</a><span style=\"margin-left: 0.25em; color: rgb(85, 85, 85);\">]</span></span>\n</h2>\n<p>See also: <a href=\"https://en.wikipedia.org/wiki/Sources_of_ancient_Tamil_history\" title=\"Sources of ancient Tamil history\" style=\"color: rgb(11, 0, 128); background-image: none;\">Sources of ancient Tamil history</a></p>\n<p style=\"margin-top: 0.5em; margin-bottom: 0.5em; line-height: 22.4px; color: rgb(37, 37, 37); font-family: sans-serif, 'Helvetica Neue', Helvetica, Arial, sans-serif; font-size: 14px;\">It is unknown as to whether the term <i>Thamizhar</i> and its equivalents in <a href=\"https://en.wikipedia.org/wiki/Prakrit\" title=\"Prakrit\" style=\"color: rgb(11, 0, 128); background-image: none;\">Prakrit</a> such as <i>Damela</i>, <i>Dameda</i>, <i>Dhamila</i> and <i>Damila</i> was a self designation or a term denoted by outsiders. Epigraphic evidence of an ethnic group termed as such is found in ancient Sri Lanka where a number of inscriptions have come to light datable from the 6th to the 5th century BCE mentioning <i>Damela</i> or <i>Dameda</i> persons. In the well-known <a href=\"https://en.wikipedia.org/wiki/Hathigumpha_inscription\" title=\"Hathigumpha inscription\" style=\"color: rgb(11, 0, 128); background-image: none;\">Hathigumpha inscription</a>of the <a href=\"https://en.wikipedia.org/wiki/Kalinga_(India)\" title=\"Kalinga (India)\" style=\"color: rgb(11, 0, 128); background-image: none;\">Kalinga</a> ruler <a href=\"https://en.wikipedia.org/wiki/Kharavela\" title=\"Kharavela\" style=\"color: rgb(11, 0, 128); background-image: none;\">Kharavela</a>, refers to a <i>T(ra)mira samghata</i> (Confederacy of Tamil rulers) dated to 150 BC. It also mentions that the league of Tamil kingdoms had been in existence 113 years before then.<sup id=\"cite_ref-KI157_30-0\" style=\"line-height: 1; unicode-bidi: isolate; white-space: nowrap; font-size: 11.2px; font-weight: normal; font-style: normal;\"><a href=\"https://en.wikipedia.org/wiki/Tamils#cite_note-KI157-30\" style=\"color: rgb(11, 0, 128); background-image: none;\">[29]</a></sup> In <a href=\"https://en.wikipedia.org/wiki/Amaravathi_village,_Guntur_district\" title=\"Amaravathi village, Guntur district\" style=\"color: rgb(11, 0, 128); background-image: none;\">Amaravati</a> in present-day <a href=\"https://en.wikipedia.org/wiki/Andhra_Pradesh\" title=\"Andhra Pradesh\" style=\"color: rgb(11, 0, 128); background-image: none;\">Andhra Pradesh</a> there is an inscription referring to a<i>Dhamila-vaniya</i> (Tamil trader) datable to the 3rd century AD.<sup id=\"cite_ref-KI157_30-1\" style=\"line-height: 1; unicode-bidi: isolate; white-space: nowrap; font-size: 11.2px; font-weight: normal; font-style: normal;\"><a href=\"https://en.wikipedia.org/wiki/Tamils#cite_note-KI157-30\" style=\"color: rgb(11, 0, 128); background-image: none;\">[29]</a></sup> Another inscription of about the same time in <a href=\"https://en.wikipedia.org/wiki/Nagarjunakonda\" title=\"Nagarjunakonda\" style=\"color: rgb(11, 0, 128); background-image: none;\">Nagarjunakonda</a> seems to refer to a<i>Damila</i>. A third inscription in <a href=\"https://en.wikipedia.org/wiki/Kanheri_Caves\" title=\"Kanheri Caves\" style=\"color: rgb(11, 0, 128); background-image: none;\">Kanheri Caves</a> refers to a <i>Dhamila-gharini</i> (Tamil house-holder). In the <a href=\"https://en.wikipedia.org/wiki/Buddhist\" title=\"Buddhist\" style=\"color: rgb(11, 0, 128); background-image: none;\">Buddhist</a> <a href=\"https://en.wikipedia.org/wiki/Jataka\" title=\"Jataka\" style=\"color: rgb(11, 0, 128); background-image: none;\">Jataka</a> story known as <i>Akiti Jataka</i>there is a mention to <i>Damila-rattha</i> (Tamil dynasty). There were trade relationship between the <a href=\"https://en.wikipedia.org/wiki/Roman_Empire\" title=\"Roman Empire\" style=\"color: rgb(11, 0, 128); background-image: none;\">Roman Empire</a> and <a href=\"https://en.wikipedia.org/wiki/Pandyan_Empire\" title=\"Pandyan Empire\" style=\"color: rgb(11, 0, 128); background-image: none;\">Pandyan Empire</a>. As recorded by <a href=\"https://en.wikipedia.org/wiki/Strabo\" title=\"Strabo\" style=\"color: rgb(11, 0, 128); background-image: none;\">Strabo</a>, <a href=\"https://en.wikipedia.org/wiki/Emperor_Augustus\" title=\"Emperor Augustus\" style=\"color: rgb(11, 0, 128); background-image: none;\">Emperor Augustus</a> of <a href=\"https://en.wikipedia.org/wiki/Rome\" title=\"Rome\" style=\"color: rgb(11, 0, 128); background-image: none;\">Rome</a> received at <a href=\"https://en.wikipedia.org/wiki/Antioch\" title=\"Antioch\" style=\"color: rgb(11, 0, 128); background-image: none;\">Antioch</a> an ambassador from a king called <i>Pandyan of Dramira</i>.<sup id=\"cite_ref-The_cyclop.C3.A6dia_of_India_and_of_Eastern_and_Southern_Asia_31-0\" style=\"line-height: 1; unicode-bidi: isolate; white-space: nowrap; font-size: 11.2px; font-weight: normal; font-style: normal;\"><a href=\"https://en.wikipedia.org/wiki/Tamils#cite_note-The_cyclop.C3.A6dia_of_India_and_of_Eastern_and_Southern_Asia-31\" style=\"color: rgb(11, 0, 128); background-image: none;\">[30]</a></sup> Hence, it is clear that by at least the 300 BC, the ethnic identity of Tamils has been formed as a distinct group.<sup id=\"cite_ref-KI157_30-2\" style=\"line-height: 1; unicode-bidi: isolate; white-space: nowrap; font-size: 11.2px; font-weight: normal; font-style: normal;\"><a href=\"https://en.wikipedia.org/wiki/Tamils#cite_note-KI157-30\" style=\"color: rgb(11, 0, 128); background-image: none;\">[29]</a></sup> <i>Thamizhar</i>is etymologically related to Tamil, the language spoken by Tamil people. Southworth suggests that the name comes from tam-miz &gt; tam-iz 'self-speak', or 'one's own speech'.<sup id=\"cite_ref-32\" style=\"line-height: 1; unicode-bidi: isolate; white-space: nowrap; font-size: 11.2px; font-weight: normal; font-style: normal;\"><a href=\"https://en.wikipedia.org/wiki/Tamils#cite_note-32\" style=\"color: rgb(11, 0, 128); background-image: none;\">[31]</a></sup> Zvelebil suggests an etymology of <i>tam-iz</i>, with tam meaning \"self\" or \"one's self\", and \"-iz\" having the connotation of \"unfolding sound\". Alternatively, he suggests a derivation of <i>tamiz</i> &lt; <i>tam-iz</i> &lt; <i>*tav-iz</i> &lt;<i>*tak-iz</i>, meaning in origin \"the proper process (of speaking).\"<sup id=\"cite_ref-33\" style=\"line-height: 1; unicode-bidi: isolate; white-space: nowrap; font-size: 11.2px; font-weight: normal; font-style: normal;\"><a href=\"https://en.wikipedia.org/wiki/Tamils#cite_note-33\" style=\"color: rgb(11, 0, 128); background-image: none;\">[32]</a></sup> Another theory say the term <i>Thamizhar</i> was derived from the name of the ancient people <i>Dravida</i> &gt; <i>Dramila</i> &gt; <i>Damila</i> &gt; <i>Tamila</i> &gt;<i>Tamilar</i><sup id=\"cite_ref-34\" style=\"line-height: 1; unicode-bidi: isolate; white-space: nowrap; font-size: 11.2px; font-weight: normal; font-style: normal;\"><a href=\"https://en.wikipedia.org/wiki/Tamils#cite_note-34\" style=\"color: rgb(11, 0, 128); background-image: none;\">[33]</a></sup></p>\n<p><br></p>\r\n"
      post :create, construct_params({ id: folder_meta.id }, {title: title, description: paragraph, status: 1, type: 2})
      assert_response 201
      result = parse_response(@response.body)
      assert_equal "http://#{@request.host}/api/v2/solutions/articles/#{result['id']}", response.headers['Location']
      match_json(solution_article_pattern(Solution::Article.last))
      article = Solution::Article.last
      assert article.title == title
      assert article.description == paragraph
      assert article.user_id == @agent.id
      assert article.status == 1
      assert article.parent.art_type == 2
    end

    def test_create_article_with_user_id
      folder_meta = get_folder_meta
      title = Faker::Name.name
      paragraph = Faker::Lorem.paragraph
      post :create, construct_params({ id: folder_meta.id }, {title: title, description: paragraph, status: 1, type: 2, agent_id: @agent.id})
      assert_response 400
      match_json([bad_request_error_pattern('agent_id', :invalid_field)])
    end

    def test_create_article_with_seo_data_and_tags
      folder_meta = get_folder_meta
      title = Faker::Name.name
      seo_title = Faker::Name.name
      paragraph = Faker::Lorem.paragraph
      post :create, construct_params({ id: folder_meta.id }, {title: title, description: paragraph, status: 1, type: 2, tags: ['tag1','tag2','tag2'],  seo_data: { meta_title: seo_title, meta_keywords: ['tag3','tag4','tag4'] } })
      assert_response 201
      result = parse_response(@response.body)
      assert_equal "http://#{@request.host}/api/v2/solutions/articles/#{result['id']}", response.headers['Location']
      match_json(solution_article_pattern(Solution::Article.last))
      article = Solution::Article.last
      assert article.title == title
      assert article.desc_un_html.strip == paragraph
      assert article.user_id == @agent.id
      assert article.status == 1
      assert article.parent.art_type == 2
      assert article.seo_data[:meta_title] == seo_title
      assert article.seo_data[:meta_keywords] == ['tag3','tag4'].join(",")
      assert article.tags.map(&:name) == ['tag1', 'tag2']
    end

    def test_create_article_without_params
      folder_meta = get_folder_meta
      post :create, construct_params({ id: folder_meta.id }, { })
      assert_response 400
      match_json([bad_request_error_pattern('title', :datatype_mismatch, code: :missing_field, expected_data_type: String),
                  bad_request_error_pattern('description', :datatype_mismatch, code: :missing_field, expected_data_type: String),
                  bad_request_error_pattern('type', :missing_field),
                  bad_request_error_pattern('status', :not_included, list: [1,2].join(','), code: :missing_field)])
    end

    def test_create_article_with_invalid_params
      folder_meta = get_folder_meta
      post :create, construct_params({ id: folder_meta.id }, { description: 1, title: 1, status: 'a', type: 'c', seo_data: 1, tags: "a" })
      assert_response 400
      match_json([bad_request_error_pattern('status', :not_included, list: [1,2].join(','), code: :invalid_value),
                  bad_request_error_pattern('type', :not_included, list: [1,2].join(','), code: :invalid_value),
                  bad_request_error_pattern('description', :datatype_mismatch, code: :datatype_mismatch, expected_data_type: 'String', given_data_type: 'Integer', prepend_msg: :input_received),
                  bad_request_error_pattern('seo_data', :datatype_mismatch, code: :datatype_mismatch, expected_data_type: 'key/value pair', given_data_type: 'Integer', prepend_msg: :input_received),
                  bad_request_error_pattern('tags', :datatype_mismatch, code: :datatype_mismatch, expected_data_type: 'Array', given_data_type: 'String', prepend_msg: :input_received),
                  bad_request_error_pattern('title', :datatype_mismatch, code: :datatype_mismatch, expected_data_type: 'String', given_data_type: 'Integer', prepend_msg: :input_received)])
    end

    def test_create_article_with_invalid_status_article_type
      folder_meta = get_folder_meta
      post :create, construct_params({ id: folder_meta.id }, { description: '<b>aaaa</b>', title: 'Sample title', status: 3, type: 4 })
      assert_response 400
      match_json([bad_request_error_pattern('status', :not_included, list: [1,2].join(',')),
                bad_request_error_pattern('type', :not_included, list: [1,2].join(','))])
    end

    def test_create_article_with_title_exceeding_max_length
      folder_meta = get_folder_meta
      post :create, construct_params({ id: folder_meta.id }, { description: '<b>aaaa</b>', title: 'a'*260, status: 1, type: 1 })
      assert_response 400
      match_json([bad_request_error_pattern('title', :too_long_too_short, current_count: 260, element_type: 'characters', max_count: 240, min_count: 3)])
    end

    def test_create_article_in_unavailable_folder
      post :create, construct_params({ id: 9999 }, { description: '<b>aaaa</b>', title: 'aaaa', status: 1, type: 1 })
      assert_response :missing
    end

    def test_create_article_in_unavailable_folder_without_mandatory_fields
      post :create, construct_params({ id: 9999 }, { description: '<b>aaaa</b>', title: 'aaaa' })
      assert_response :missing
    end

    def test_create_article_with_invalid_seo_data
      folder_meta = get_folder_meta
      post :create, construct_params({ id: folder_meta.id }, { description: '<b>aaaa</b>', title: 'aaaa', status: 1, type: 1, seo_data: { meta_title: 1, meta_description: 1, meta_keywords: 1 } })
      assert_response 400
      match_json([bad_request_error_pattern('meta_title', :datatype_mismatch, code: :datatype_mismatch, expected_data_type: 'String', given_data_type: 'Integer', prepend_msg: :input_received),
                  bad_request_error_pattern('meta_description', :datatype_mismatch, code: :datatype_mismatch, expected_data_type: 'String', given_data_type: 'Integer', prepend_msg: :input_received),
                  bad_request_error_pattern('meta_keywords', :datatype_mismatch, code: :datatype_mismatch, expected_data_type: 'Array', given_data_type: 'Integer', prepend_msg: :input_received)])
    end

    def test_create_article_translation
      sample_article = get_article_without_translation
      title = 'translated title'
      description = 'translated description'
      status = 1
      category_name = 'translated category_name'
      folder_name = 'translated folder_name'
      post :create, construct_params({id: sample_article.parent_id, language: @account.supported_languages.last}, {title: title, description: description, status: status, category_name: category_name, folder_name: folder_name})
      assert_response 201
      result = parse_response(@response.body)
      assert_equal "http://#{@request.host}/api/v2/solutions/articles/#{result['id']}", response.headers['Location']
      match_json(solution_article_pattern(Solution::Article.last))
      article = Solution::Article.last
      assert article.title == title
      assert article.desc_un_html.strip == description
      assert article.user_id == @agent.id
      assert article.status == 1
    end

    def test_create_translation_with_type
      sample_article = get_article_without_translation
      title = 'translated title'
      description = 'translated description'
      status = 1
      category_name = 'translated category_name'
      folder_name = 'translated folder_name'
      type = 1
      post :create, construct_params({id: sample_article.parent_id, language: @account.supported_languages.first}, {title: title, description: description, status: status, category_name: category_name, folder_name: folder_name, type: type})
      assert_response 400
      match_json([bad_request_error_pattern('type', :cant_set_for_secondary_language, code: :incompatible_field)])
    end

    def test_update_article
      sample_article = get_article
      paragraph = Faker::Lorem.paragraph
      params_hash  = { title: 'new title', description: paragraph, status: 2, type: 2, agent_id: @agent.id }
      put :update, construct_params({ id: sample_article.parent_id }, params_hash)
      assert_response 200
      match_json(solution_article_pattern(sample_article.reload))
      assert sample_article.reload.title == 'new title'
      assert sample_article.reload.status == 2
      assert sample_article.reload.parent.reload.art_type == 2
      assert sample_article.reload.parent.reload.user_id == @agent.id
    end

    def test_update_and_publish_a_draft
      sample_article = get_article_with_draft
      paragraph = Faker::Lorem.paragraph
      params_hash  = { title: 'new title', description: paragraph, status: 2, type: 2, agent_id: @agent.id }
      put :update, construct_params({ id: sample_article.parent_id }, params_hash)
      assert_response 200
      match_json(solution_article_pattern(sample_article.reload))
      assert sample_article.reload.title == 'new title'
      assert sample_article.reload.status == 2
      assert sample_article.reload.parent.reload.art_type == 2
      assert sample_article.reload.parent.reload.user_id == @agent.id
    end

    def test_update_article_with_unavailable_user_id
      sample_article = get_article
      paragraph = Faker::Lorem.paragraph
      params_hash  = { title: 'new title', description: paragraph, status: 2, type: 2, agent_id: 9999 }
      put :update, construct_params({ id: sample_article.parent_id }, params_hash)
      assert_response 400
      match_json([bad_request_error_pattern('agent_id', :absent_in_db, resource: 'agent', attribute: 'agent_id')])
    end


    def test_update_unavailalbe_article
      paragraph = Faker::Lorem.paragraph
      params_hash  = { title: 'new title', description: paragraph, status: 2, type: 2 }
      put :update, construct_params({ id: 9999 }, params_hash)
      assert_response :missing
    end

    def test_update_unavailalbe_article_with_language
      paragraph = Faker::Lorem.paragraph
      params_hash  = { title: 'new title', description: paragraph, status: 2, type: 2 }
      put :update, construct_params({ id: 9999, language: @account.supported_languages.last }, params_hash)
      assert_response :missing
    end

    def test_update_article_type
      sample_article = get_article
      old_description = sample_article.description
      params_hash  = { type: 2 }
      put :update, construct_params({ id: sample_article.parent_id }, params_hash)
      assert_response 200
      match_json(solution_article_pattern(sample_article.reload))
      assert sample_article.reload.description == old_description
      assert sample_article.reload.parent.reload.art_type == 2
    end

    def test_update_translated_article_with_category_name_and_folder_name
      sample_article = get_article_with_translation
      title = 'updated title'
      description = 'updated description'
      status = 2
      category_name = 'category_name'
      folder_name = 'folder_name'
      language = @account.language
      put :update, construct_params({ id: sample_article.parent_id, language: language }, { title: title, description: description, status: status, category_name: category_name, folder_name: folder_name})
      assert_response 400
      match_json([bad_request_error_pattern('folder_name', :attribute_not_required, code: :incompatible_field),
                  bad_request_error_pattern('category_name', :attribute_not_required, code: :incompatible_field)])
    end

    def test_update_article_with_primary_language_with_category_name_and_folder_name
      sample_article = get_article
      title = 'updated title'
      description = 'updated description'
      status = 2
      language = @account.language
      put :update, construct_params({ id: sample_article.parent_id, language: language }, { title: title, description: description, status: status, category_name: 'category', folder_name: 'folder'})
      assert_response 400
      match_json([bad_request_error_pattern('folder_name', :attribute_not_required, code: :incompatible_field),
                  bad_request_error_pattern('category_name', :attribute_not_required, code: :incompatible_field)])
    end

    def test_update_article_with_user_id_without_privilege
      User.any_instance.stubs(:privilege?).with(:manage_solutions).returns(true)
      User.any_instance.stubs(:privilege?).with(:publish_solution).returns(true)
      User.any_instance.stubs(:privilege?).with(:delete_solution).returns(true)
      User.any_instance.stubs(:privilege?).with(:admin_tasks).returns(false)
      sample_article = get_article
      paragraph = Faker::Lorem.paragraph
      params_hash  = { title: 'new title', description: paragraph, status: 2, type: 2, agent_id: @agent.id }
      put :update, construct_params({ id: sample_article.parent_id }, params_hash)
      assert_response 400
      match_json([bad_request_error_pattern('agent_id', :inaccessible_field)])
    ensure
      User.any_instance.unstub(:privilege?)
    end

    def test_folder_index
      sample_folder = get_folder_meta
      get :folder_articles, controller_params(id: sample_folder.id)
      assert_response 200
      articles = sample_folder.solution_articles.where(language_id: @account.language_object.id)
      pattern = articles.map { |article| solution_article_pattern_index(article) }
      match_json(pattern.ordered!)
    end

    def test_folder_index_with_language_param
      sample_folder = get_folder_meta
      get :folder_articles, controller_params(id: sample_folder.id, language: @account.supported_languages.last)
      assert_response 200
      articles = sample_folder.solution_articles.where(language_id: Language.find_by_code(@account.supported_languages.last).id)
      pattern = articles.map { |article| solution_article_pattern_index(article) }
      match_json(pattern.ordered!)
    end

    def test_folder_index_with_language_param_having_primary_language
      sample_folder = get_folder_meta
      get :folder_articles, controller_params(id: sample_folder.id, language: @account.language)
      assert_response 200
      articles = sample_folder.solution_articles.where(language_id: @account.language_object.id)
      pattern = articles.map { |article| solution_article_pattern_index(article) }
      match_json(pattern.ordered!)
    end

    def test_folder_index_with_invalid_language_param
      sample_folder = get_folder_meta
      get :folder_articles, controller_params(id: sample_folder.id, language: 'aaaa')
      assert_response 404
      match_json(request_error_pattern(:language_not_allowed, code: 'aaaa', list: (@account.supported_languages + [@account.language]).sort.join(', ')))
    end

    # Delete article
    def test_delete_article
      sample_article = get_article_without_translation
      delete :destroy, construct_params(id: sample_article.parent_id)
      assert_response 204
    end

    def test_delete_article_with_language_param
      sample_article = get_article
      language_code = Language.find(sample_article.language_id).code
      delete :destroy, construct_params({id: sample_article.parent_id, language: language_code})
      assert_response 404
    end

    def test_delete_unavailable_article
      delete :destroy, construct_params(id: 9999)
      assert_response :missing
    end
  end
end

