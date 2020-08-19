['attachments_test_helper.rb'].each { |file| require Rails.root.join('test', 'api', 'helpers', file) }

module SolutionsArticlesCommonTests
  include AttachmentsTestHelper

  def setup
    super
    @account.features.enable_multilingual.create
  end

  # Common test cases for public api and private API
  def test_show_article
    sample_article = get_article
    get :show, controller_params(version: version, id: sample_article.parent_id)
    if sample_article.draft.nil?
      match_json(article_pattern(sample_article.solution_article_meta.primary_article))
    else
      match_json(article_draft_pattern(sample_article.solution_article_meta.primary_article, sample_article.solution_article_meta.primary_article.draft))
    end
    assert_response 200
  end

  def test_show_unavailalbe_article
    get :show, controller_params(id: 99_999)
    assert_response :missing
  end

  def test_show_unavailalbe_article_with_language
    get :show, controller_params(id: 99_999, language: @account.supported_languages.last)
    assert_response :missing
  end

  def test_show_article_with_language_query_param
    sample_article = get_article
    get :show, controller_params(version: version, id: sample_article.parent_id, language: sample_article.language_code)
    if sample_article.draft.nil?
      match_json(article_pattern(sample_article))
    else
      match_json(article_draft_pattern(sample_article, sample_article.draft))
    end
    assert_response 200
  end

  def test_show_article_with_invalid_language_query_param
    sample_article = get_article
    get :show, controller_params(version: version, id: sample_article.parent_id, language: 'xaasd')
    assert_response 404
    match_json(request_error_pattern(:language_not_allowed, code: 'xaasd', list: (@account.supported_languages + [@account.language]).sort.join(', ')))
  end

  def test_show_article_secondary_language
    languages = @account.supported_languages + ['primary']
    language = @account.supported_languages.first
    article_meta = create_article(article_params(lang_codes: languages))
    translated_article = article_meta.safe_send("#{language}_article")
    get :show, controller_params(version: version, id: translated_article.parent_id, language: language)
    match_json(article_pattern(translated_article))
    assert_response 200
  end

  def test_show_article_metrics_with_language_query_param
    languages = @account.supported_languages + ['primary']
    language = @account.supported_languages.first
    article_meta = create_article(article_params(lang_codes: languages))
    translated_article = article_meta.safe_send("#{language}_article")
    3.times do
      translated_article.thumbs_up!
    end
    article_meta.primary_article.thumbs_up!
    translated_article.reload
    get :show, controller_params(version: version, id: translated_article.parent_id, language: language)
    assert_response 200
    assert_equal translated_article.thumbs_up, JSON.parse(response.body)['thumbs_up']
    match_json(article_pattern(translated_article, request_language: true))
  end

  def test_show_article_metrics_without_language_query_param
    languages = @account.supported_languages + ['primary']
    language = @account.supported_languages.first
    article_meta = create_article(article_params(lang_codes: languages))
    translated_article = article_meta.safe_send("#{language}_article")
    3.times do
      translated_article.thumbs_up!
    end
    article_meta.primary_article.thumbs_up!
    article_meta.reload
    get :show, controller_params(version: version, id: article_meta.id)
    assert_response 200
    match_json(article_pattern(article_meta.primary_article, request_language: version.to_sym == :private))
  end

  # Feature Check
  def test_show_article_with_language_and_without_multilingual_feature
    Account.any_instance.stubs(:multilingual?).returns(false)
    sample_article = get_article
    get :show, controller_params(version: version, id: sample_article.parent_id, language: @account.supported_languages.last)
    match_json(request_error_pattern(:require_feature, feature: 'MultilingualFeature'))
    assert_response 404
  ensure
    Account.any_instance.unstub(:multilingual?)
  end

  def test_create_article
    folder_meta = get_folder_meta
    title = Faker::Name.name
    paragraph = Faker::Lorem.paragraph
    post :create, construct_params({ version: version, id: folder_meta.id }, title: title, description: paragraph, status: 1, type: 2)
    assert_response 201
    result = parse_response(@response.body)
    assert_equal "http://#{@request.host}/api/v2/solutions/articles/#{result['id']}", response.headers['Location']
    match_json(article_pattern(Solution::Article.last))
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
    post :create, construct_params({ version: version, id: folder_meta.id }, title: title, description: paragraph, status: 1, type: 2)
    assert_response 201
    match_json(article_pattern(Solution::Article.last))
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
    paragraph = "<h2 style=\"color: rgb(0, 0, 0); margin-top: 1em; margin-bottom: 0.25em; overflow: hidden; border-bottom-width: 1px; border-bottom-style: solid; border-bottom-color: rgb(170, 170, 170); font-family: 'Linux Libertine', Georgia, Times, serif, 'Helvetica Neue', Helvetica, Arial, sans-serif; line-height: 1.3;\">\n<span id=\"Etymology\">Etymology</span><span style=\"-webkit-user-select: none; font-size: small; font-weight: normal; margin-left: 1em; line-height: 1em; display: inline-block; white-space: nowrap; unicode-bidi: isolate; font-family: sans-serif, 'Helvetica Neue', Helvetica, Arial, sans-serif;\"><span style=\"margin-right: 0.25em; color: rgb(85, 85, 85);\">[</span><a href=\"https://en.wikipedia.org/w/index.php?title=Tamils&amp;action=edit&amp;section=1\" title=\"Edit section: Etymology\" style=\"color: rgb(11, 0, 128); background-image: none;\">edit</a><span style=\"margin-left: 0.25em; color: rgb(85, 85, 85);\">]</span></span>\n</h2>\n<p>See also: <a href=\"https://en.wikipedia.org/wiki/Sources_of_ancient_Tamil_history\" title=\"Sources of ancient Tamil history\" style=\"color: rgb(11, 0, 128); background-image: none;\">Sources of ancient Tamil history</a></p>\n<p style=\"margin-top: 0.5em; margin-bottom: 0.5em; line-height: 22.4px; color: rgb(37, 37, 37); font-family: sans-serif, 'Helvetica Neue', Helvetica, Arial, sans-serif; font-size: 14px;\">It is unknown as to whether the term <i>Thamizhar</i> and its equivalents in <a href=\"https://en.wikipedia.org/wiki/Prakrit\" title=\"Prakrit\" style=\"color: rgb(11, 0, 128); background-image: none;\">Prakrit</a> such as <i>Damela</i>, <i>Dameda</i>, <i>Dhamila</i> and <i>Damila</i> was a self designation or a term denoted by outsiders. Epigraphic evidence of an ethnic group termed as such is found in ancient Sri Lanka where a number of inscriptions have come to light datable from the 6th to the 5th century BCE mentioning <i>Damela</i> or <i>Dameda</i> persons. In the well-known <a href=\"https://en.wikipedia.org/wiki/Hathigumpha_inscription\" title=\"Hathigumpha inscription\" style=\"color: rgb(11, 0, 128); background-image: none;\">Hathigumpha inscription</a>of the <a href=\"https://en.wikipedia.org/wiki/Kalinga_(India)\" title=\"Kalinga (India)\" style=\"color: rgb(11, 0, 128); background-image: none;\">Kalinga</a> ruler <a href=\"https://en.wikipedia.org/wiki/Kharavela\" title=\"Kharavela\" style=\"color: rgb(11, 0, 128); background-image: none;\">Kharavela</a>, refers to a <i>T(ra)mira samghata</i> (Confederacy of Tamil rulers) dated to 150 BC. It also mentions that the league of Tamil kingdoms had been in existence 113 years before then.<sup id=\"cite_ref-KI157_30-0\" style=\"line-height: 1; unicode-bidi: isolate; white-space: nowrap; font-size: 11.2px; font-weight: normal; font-style: normal;\"><a href=\"https://en.wikipedia.org/wiki/Tamils#cite_note-KI157-30\" style=\"color: rgb(11, 0, 128); background-image: none;\">[29]</a></sup> In <a href=\"https://en.wikipedia.org/wiki/Amaravathi_village,_Guntur_district\" title=\"Amaravathi village, Guntur district\" style=\"color: rgb(11, 0, 128); background-image: none;\">Amaravati</a> in present-day <a href=\"https://en.wikipedia.org/wiki/Andhra_Pradesh\" title=\"Andhra Pradesh\" style=\"color: rgb(11, 0, 128); background-image: none;\">Andhra Pradesh</a> there is an inscription referring to a<i>Dhamila-vaniya</i> (Tamil trader) datable to the 3rd century AD.<sup id=\"cite_ref-KI157_30-1\" style=\"line-height: 1; unicode-bidi: isolate; white-space: nowrap; font-size: 11.2px; font-weight: normal; font-style: normal;\"><a href=\"https://en.wikipedia.org/wiki/Tamils#cite_note-KI157-30\" style=\"color: rgb(11, 0, 128); background-image: none;\">[29]</a></sup> Another inscription of about the same time in <a href=\"https://en.wikipedia.org/wiki/Nagarjunakonda\" title=\"Nagarjunakonda\" style=\"color: rgb(11, 0, 128); background-image: none;\">Nagarjunakonda</a> seems to refer to a<i>Damila</i>. A third inscription in <a href=\"https://en.wikipedia.org/wiki/Kanheri_Caves\" title=\"Kanheri Caves\" style=\"color: rgb(11, 0, 128); background-image: none;\">Kanheri Caves</a> refers to a <i>Dhamila-gharini</i> (Tamil house-holder). In the <a href=\"https://en.wikipedia.org/wiki/Buddhist\" title=\"Buddhist\" style=\"color: rgb(11, 0, 128); background-image: none;\">Buddhist</a> <a href=\"https://en.wikipedia.org/wiki/Jataka\" title=\"Jataka\" style=\"color: rgb(11, 0, 128); background-image: none;\">Jataka</a> story known as <i>Akiti Jataka</i>there is a mention to <i>Damila-rattha</i> (Tamil dynasty). There were trade relationship between the <a href=\"https://en.wikipedia.org/wiki/Roman_Empire\" title=\"Roman Empire\" style=\"color: rgb(11, 0, 128); background-image: none;\">Roman Empire</a> and <a href=\"https://en.wikipedia.org/wiki/Pandyan_Empire\" title=\"Pandyan Empire\" style=\"color: rgb(11, 0, 128); background-image: none;\">Pandyan Empire</a>. As recorded by <a href=\"https://en.wikipedia.org/wiki/Strabo\" title=\"Strabo\" style=\"color: rgb(11, 0, 128); background-image: none;\">Strabo</a>, <a href=\"https://en.wikipedia.org/wiki/Emperor_Augustus\" title=\"Emperor Augustus\" style=\"color: rgb(11, 0, 128); background-image: none;\">Emperor Augustus</a> of <a href=\"https://en.wikipedia.org/wiki/Rome\" title=\"Rome\" style=\"color: rgb(11, 0, 128); background-image: none;\">Rome</a> received at <a href=\"https://en.wikipedia.org/wiki/Antioch\" title=\"Antioch\" style=\"color: rgb(11, 0, 128); background-image: none;\">Antioch</a> an ambassador from a king called <i>Pandyan of Dramira</i>.<sup id=\"cite_ref-The_cyclop.C3.A6dia_of_India_and_of_Eastern_and_Southern_Asia_31-0\" style=\"line-height: 1; unicode-bidi: isolate; white-space: nowrap; font-size: 11.2px; font-weight: normal; font-style: normal;\"><a href=\"https://en.wikipedia.org/wiki/Tamils#cite_note-The_cyclop.C3.A6dia_of_India_and_of_Eastern_and_Southern_Asia-31\" style=\"color: rgb(11, 0, 128); background-image: none;\">[30]</a></sup> Hence, it is clear that by at least the 300 BC, the ethnic identity of Tamils has been formed as a distinct group.<sup id=\"cite_ref-KI157_30-2\" style=\"line-height: 1; unicode-bidi: isolate; white-space: nowrap; font-size: 11.2px; font-weight: normal; font-style: normal;\"><a href=\"https://en.wikipedia.org/wiki/Tamils#cite_note-KI157-30\" style=\"color: rgb(11, 0, 128); background-image: none;\">[29]</a></sup> <i>Thamizhar</i>is etymologically related to Tamil, the language spoken by Tamil people. Southworth suggests that the name comes from tam-miz &gt; tam-iz 'self-speak', or 'one's own speech'.<sup id=\"cite_ref-32\" style=\"line-height: 1; unicode-bidi: isolate; white-space: nowrap; font-size: 11.2px; font-weight: normal; font-style: normal;\"><a href=\"https://en.wikipedia.org/wiki/Tamils#cite_note-32\" style=\"color: rgb(11, 0, 128); background-image: none;\">[31]</a></sup> Zvelebil suggests an etymology of <i>tam-iz</i>, with tam meaning \"self\" or \"one's self\", and \"-iz\" having the connotation of \"unfolding sound\". Alternatively, he suggests a derivation of <i>tamiz</i> &lt; <i>tam-iz</i> &lt; <i>*tav-iz</i> &lt;<i>*tak-iz</i>, meaning in origin \"the proper process (of speaking).\"<sup id=\"cite_ref-33\" style=\"line-height: 1; unicode-bidi: isolate; white-space: nowrap; font-size: 11.2px; font-weight: normal; font-style: normal;\"><a href=\"https://en.wikipedia.org/wiki/Tamils#cite_note-33\" style=\"color: rgb(11, 0, 128); background-image: none;\">[32]</a></sup> Another theory say the term <i>Thamizhar</i> was derived from the name of the ancient people <i>Dravida</i> &gt; <i>Dramila</i> &gt; <i>Damila</i> &gt; <i>Tamila</i> &gt;<i>Tamilar</i><sup id=\"cite_ref-34\" style=\"line-height: 1; unicode-bidi: isolate; white-space: nowrap; font-size: 11.2px; font-weight: normal; font-style: normal;\"><a href=\"https://en.wikipedia.org/wiki/Tamils#cite_note-34\" style=\"color: rgb(11, 0, 128); background-image: none;\">[33]</a></sup></p>\n<p><br></p>\n"
    post :create, construct_params({ version: version, id: folder_meta.id }, title: title, description: paragraph, status: 1, type: 2)
    assert_response 201
    result = parse_response(@response.body)
    assert_equal "http://#{@request.host}/api/v2/solutions/articles/#{result['id']}", response.headers['Location']
    match_json(article_pattern(Solution::Article.last))
    article = Solution::Article.last
    assert_equal title, article.title
    assert_equal paragraph, article.description
    assert_equal @agent.id, article.user_id
    assert_equal 1, article.status
    assert_equal 2, article.parent.art_type
  end

  def test_create_article_with_user_id
    folder_meta = get_folder_meta
    title = Faker::Name.name
    paragraph = Faker::Lorem.paragraph
    post :create, construct_params({ version: version, id: folder_meta.id }, title: title, description: paragraph, status: 1, type: 2, agent_id: @agent.id)
    assert_response 400
    match_json([bad_request_error_pattern('agent_id', :invalid_field)])
  end

  def test_create_article_with_seo_data_and_tags
    folder_meta = get_folder_meta
    title = Faker::Name.name
    seo_title = Faker::Name.name
    seo_desc = Faker::Lorem.paragraph
    paragraph = Faker::Lorem.paragraph
    post :create, construct_params({ version: version, id: folder_meta.id }, title: title, description: paragraph, status: 1, type: 2, tags: ['tag1', 'tag2', 'tag2'], seo_data: { meta_title: seo_title, meta_description: seo_desc, meta_keywords: ['tag3', 'tag4', 'tag4'] })
    assert_response 201
    result = parse_response(@response.body)
    assert_equal "http://#{@request.host}/api/v2/solutions/articles/#{result['id']}", response.headers['Location']
    match_json(article_pattern(Solution::Article.last))
    article = Solution::Article.last
    assert article.title == title
    assert article.desc_un_html.strip == paragraph
    assert article.user_id == @agent.id
    assert article.status == 1
    assert article.parent.art_type == 2
    assert article.seo_data[:meta_title] == seo_title
    assert article.seo_data[:meta_keywords] == ['tag3', 'tag4'].join(',')
    assert article.tags.map(&:name) == ['tag1', 'tag2']
  end

  def test_create_article_with_new_tags_without_privilege
    folder_meta = get_folder_meta
    title = Faker::Name.name
    paragraph = Faker::Lorem.paragraph
    tags = Faker::Lorem.words(3).uniq
    tags = tags.map do |tag|
      # Timestamp added to make sure tag names are new
      tag = "#{tag}#{Time.now.to_i}#{rand(1_000_000)}"
      assert_equal @account.tags.map(&:name).include?(tag), false
      tag
    end
    User.current.reload
    remove_privilege(User.current, :create_tags)
    post :create, construct_params({ version: version, id: folder_meta.id }, title: title, description: paragraph, status: 1, type: 2, tags: tags)
    assert_response 400
    add_privilege(User.current, :create_tags)
  end

  def test_create_article_with_existing_tags_without_privilege
    folder_meta = get_folder_meta
    title = Faker::Name.name
    paragraph = Faker::Lorem.paragraph
    tag = Faker::Lorem.word
    @account.tags.create(name: tag) unless @account.tags.map(&:name).include?(tag)
    User.current.reload
    remove_privilege(User.current, :create_tags)
    post :create, construct_params({ version: version, id: folder_meta.id }, title: title, description: paragraph, status: 1, type: 2, tags: [tag])
    assert_response 201
    article = Solution::Article.last
    assert_equal article.tags.count, 1
    add_privilege(User.current, :create_tags)
  end

  def test_create_article_with_tags_with_privilege
    folder_meta = get_folder_meta
    title = Faker::Name.name
    paragraph = Faker::Lorem.paragraph
    tags = Faker::Lorem.words(3).uniq
    tags = tags.map do |tag|
      # Timestamp added to make sure tag names are new
      tag = "#{tag}#{Time.now.to_i}"
      assert_equal @account.tags.map(&:name).include?(tag), false
      tag
    end
    post :create, construct_params({ version: version, id: folder_meta.id }, title: title, description: paragraph, status: 1, type: 2, tags: tags)
    assert_response 201
    article = Solution::Article.last
    assert_equal article.tags.count, tags.count
  end

  def test_create_article_without_params
    folder_meta = get_folder_meta
    post :create, construct_params({ version: version, id: folder_meta.id }, {})
    assert_response 400
    match_json([bad_request_error_pattern('title', 'Mandatory attribute missing', code: :missing_field),
                bad_request_error_pattern('description', 'Mandatory attribute missing', code: :missing_field),
                bad_request_error_pattern('status', :not_included, list: [1, 2].join(','), code: :missing_field)])
  end

  def test_create_article_with_invalid_params
    folder_meta = get_folder_meta
    post :create, construct_params({ version: version, id: folder_meta.id }, description: 1, title: 1, status: 'a', type: 'c', seo_data: 1, tags: 'a')
    assert_response 400
    match_json([bad_request_error_pattern('status', :not_included, list: [1, 2].join(','), code: :invalid_value),
                bad_request_error_pattern('type', :not_included, list: [1, 2].join(','), code: :invalid_value),
                bad_request_error_pattern('description', :datatype_mismatch, code: :datatype_mismatch, expected_data_type: 'String', given_data_type: 'Integer', prepend_msg: :input_received),
                bad_request_error_pattern('seo_data', :datatype_mismatch, code: :datatype_mismatch, expected_data_type: 'key/value pair', given_data_type: 'Integer', prepend_msg: :input_received),
                bad_request_error_pattern('tags', :datatype_mismatch, code: :datatype_mismatch, expected_data_type: 'Array', given_data_type: 'String', prepend_msg: :input_received),
                bad_request_error_pattern('title', :datatype_mismatch, code: :datatype_mismatch, expected_data_type: 'String', given_data_type: 'Integer', prepend_msg: :input_received)])
  end

  def test_create_article_with_invalid_status_article_type
    folder_meta = get_folder_meta
    post :create, construct_params({ version: version, id: folder_meta.id }, description: '<b>aaaa</b>', title: 'Sample title', status: 3, type: 4)
    assert_response 400
    match_json([bad_request_error_pattern('status', :not_included, list: [1, 2].join(',')),
                bad_request_error_pattern('type', :not_included, list: [1, 2].join(','))])
  end

  def test_create_article_with_title_exceeding_max_length
    folder_meta = get_folder_meta
    post :create, construct_params({ version: version, id: folder_meta.id }, description: '<b>aaaa</b>', title: 'a' * 260, status: 1, type: 1)
    assert_response 400
    match_json([bad_request_error_pattern('title', :too_long_too_short, current_count: 260, element_type: 'characters', max_count: 240, min_count: 3)])
  end

  def test_create_article_in_unavailable_folder
    post :create, construct_params({ version: version, id: 9999 }, description: '<b>aaaa</b>', title: 'aaaa', status: 1, type: 1)
    assert_response :missing
  end

  def test_create_article_in_unavailable_folder_without_mandatory_fields
    post :create, construct_params({ version: version, id: 9999 }, description: '<b>aaaa</b>', title: 'aaaa')
    assert_response :missing
  end

  def test_create_article_with_invalid_seo_data
    folder_meta = get_folder_meta
    post :create, construct_params({ version: version, id: folder_meta.id }, description: '<b>aaaa</b>', title: 'aaaa', status: 1, type: 1, seo_data: { meta_title: 1, meta_description: 1, meta_keywords: 1 })
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
    post :create, construct_params({ version: version, id: sample_article.parent_id, language: @account.supported_languages.last }, title: title, description: description, status: status, category_name: category_name, folder_name: folder_name)
    assert_response 201
    result = parse_response(@response.body)
    assert_equal "http://#{@request.host}/api/v2/solutions/articles/#{result['id']}", response.headers['Location']
    match_json(article_pattern(Solution::Article.last))
    article = Solution::Article.last
    assert article.title == title
    assert article.desc_un_html.strip == description
    assert article.user_id == @agent.id
    assert article.status == 1
  end

  def test_create_article_translation_with_allow_language_fallback
    sample_article = get_article_without_translation
    title = 'translated title'
    description = 'translated description'
    status = 1
    category_name = 'translated category_name'
    folder_name = 'translated folder_name'
    post :create, construct_params({ version: version, id: sample_article.parent_id, language: 'en-us', allow_language_fallback: 'true' }, title: title, description: description, status: status, category_name: category_name, folder_name: folder_name)
    assert_response 404
    match_json(request_error_pattern(:language_not_allowed, code: 'en-us', list: @account.supported_languages.sort.join(', ')))
  end

  def test_language_fallback_without_fallback_params
    languages = @account.supported_languages + ['primary']
    language = @account.supported_languages.first
    article_meta = create_article(article_params(lang_codes: languages))
    translated_article = article_meta.safe_send("#{language}_article")
    get :show, controller_params(version: version, id: translated_article.parent_id, language: language + '-us')
    assert_response 404
    match_json(request_error_pattern(:language_not_allowed, code: language + '-us', list: (@account.supported_languages + [@account.language]).sort.join(', ')))
  end

  def test_language_fallback_with_fallback_params_true
    languages = @account.supported_languages + ['primary']
    language = @account.supported_languages.first
    article_meta = create_article(article_params(lang_codes: languages))
    translated_article = article_meta.safe_send("#{language}_article")
    get :show, controller_params(version: version, id: translated_article.parent_id, language: language + '-us', allow_language_fallback: 'true')
    assert_response 200
  end

  def test_language_fallback_with_fallback_params_false
    languages = @account.supported_languages + ['primary']
    language = @account.supported_languages.first
    article_meta = create_article(article_params(lang_codes: languages))
    translated_article = article_meta.safe_send("#{language}_article")
    get :show, controller_params(version: version, id: translated_article.parent_id, language: language + '-us', allow_language_fallback: 'false')
    assert_response 404
    match_json(request_error_pattern(:language_not_allowed, code: language + '-us', list: (@account.supported_languages + [@account.language]).sort.join(', ')))
  end

  def test_language_fallback_with_params_true_and_incorrect_language_params
    languages = @account.supported_languages + ['primary']
    language = @account.supported_languages.first
    article_meta = create_article(article_params(lang_codes: languages))
    translated_article = article_meta.safe_send("#{language}_article")
    get :show, controller_params(version: version, id: translated_article.parent_id, language: 'incorrect', allow_language_fallback: 'true')
    assert_response 200
  end

  def test_language_fallback_with_non_multi_lingual_account
    Account.any_instance.stubs(:multilingual?).returns(false)
    non_supported_language = get_valid_not_supported_language
    sample_article = get_article
    get :show, controller_params(version: version, id: sample_article.parent_id, language: non_supported_language, allow_language_fallback: 'true')
    assert_response 200
  ensure
    Account.any_instance.unstub(:multilingual?)
  end

  def test_create_article_translation_without_manage_solution_privilege
    User.any_instance.stubs(:privilege?).with(:manage_solutions).returns(false)
    User.any_instance.stubs(:privilege?).with(:create_and_edit_article).returns(true)
    User.any_instance.stubs(:privilege?).with(:publish_solution).returns(true)
    User.any_instance.stubs(:privilege?).with(:delete_solution).returns(true)
    User.any_instance.stubs(:privilege?).with(:admin_tasks).returns(true)
    sample_article = create_article(article_params(lang_codes: ['primary']))
    title = 'translated title'
    description = 'translated description'
    status = 1
    category_name = 'translated category_name'
    folder_name = 'translated folder_name'
    post :create, construct_params({ version: version, id: sample_article.parent_id, language: @account.supported_languages.last }, title: title, description: description, status: status, category_name: category_name, folder_name: folder_name)
    assert_response 400
    match_json([bad_request_error_pattern('folder_name', :permission_required_to_edit_category_folder, code: :incomaptiable_field), bad_request_error_pattern('category_name', :permission_required_to_edit_category_folder, code: :incomaptiable_field)])
  ensure
    User.any_instance.unstub(:privilege?)
  end

  def test_create_translation_with_type
    sample_article = get_article_without_translation
    title = 'translated title'
    description = 'translated description'
    status = 1
    category_name = 'translated category_name'
    folder_name = 'translated folder_name'
    type = 1
    post :create, construct_params({ version: version, id: sample_article.parent_id, language: @account.supported_languages.first }, title: title, description: description, status: status, category_name: category_name, folder_name: folder_name, type: type)
    assert_response 400
    match_json([bad_request_error_pattern('type', :cant_set_for_secondary_language, code: :incompatible_field)])
  end

  def test_create_translation_with_non_supported_langugage
    sample_article = get_article_without_translation
    title = 'translated title'
    description = 'translated description'
    status = 1
    category_name = 'translated category_name'
    folder_name = 'translated folder_name'
    non_supported_language = get_valid_not_supported_language
    post :create, construct_params({ version: version, id: sample_article.parent_id, language: non_supported_language }, title: title, description: description, status: status, category_name: category_name, folder_name: folder_name)
    assert_response 404
    match_json(request_error_pattern(:language_not_allowed, code: non_supported_language, list: @account.supported_languages.sort.join(', ')))
  end

  def test_create_translation_without_multilingual_feature
    Account.any_instance.stubs(:multilingual?).returns(false)
    sample_article = get_article_without_translation
    title = 'translated title'
    description = 'translated description'
    status = 1
    category_name = 'translated category_name'
    folder_name = 'translated folder_name'
    post :create, construct_params({ version: version, id: sample_article.parent_id, language: 'ar' }, title: title, description: description, status: status, category_name: category_name, folder_name: folder_name)
    assert_response 404
    match_json(request_error_pattern(:require_feature, feature: 'MultilingualFeature'))
  ensure
    Account.any_instance.unstub(:multilingual?)
  end

  def test_update_article
    sample_article = get_article
    paragraph = Faker::Lorem.paragraph
    params_hash = { title: 'new title', description: paragraph, status: 2, type: 2, agent_id: @agent.id }
    put :update, construct_params({ version: version, id: sample_article.parent_id }, params_hash)
    assert_response 200
    match_json(article_pattern(sample_article.reload))
    assert sample_article.reload.title == 'new title'
    assert sample_article.reload.status == 2
    assert sample_article.reload.parent.reload.art_type == 2
    assert sample_article.reload.parent.reload.user_id == @agent.id
  end

  def test_update_and_publish_a_draft
    sample_article = get_article_with_draft
    paragraph = Faker::Lorem.paragraph
    params_hash = { title: 'new title', description: paragraph, status: 2, type: 2, agent_id: @agent.id }
    put :update, construct_params({ version: version, id: sample_article.parent_id }, params_hash)
    assert_response 200
    match_json(article_pattern(sample_article.reload))
    assert sample_article.reload.title == 'new title'
    assert sample_article.reload.status == 2
    assert sample_article.reload.parent.reload.art_type == 2
    assert sample_article.reload.parent.reload.user_id == @agent.id
  end

  def test_update_and_publish_without_draft
    sample_article = get_article_without_draft
    paragraph = Faker::Lorem.paragraph
    params_hash = { title: 'new title', description: paragraph, status: 2, type: 2, agent_id: @agent.id }
    put :update, construct_params({ version: version, id: sample_article.parent_id }, params_hash)
    assert_response 200
    match_json(article_pattern(sample_article.reload))
    assert sample_article.reload.title == 'new title'
    assert sample_article.reload.status == 2
    assert sample_article.reload.parent.reload.art_type == 2
    assert sample_article.reload.parent.reload.user_id == @agent.id
  end

  def test_article_title_description_updated_as_draft_when_no_status_is_passed_in_public_api
    sample_article = get_article_without_draft
    article_title = sample_article.title
    article_description = sample_article.description
    paragraph = Faker::Lorem.paragraph
    params_hash = { 'title' => 'new title', 'description' => paragraph, 'type' => 2 }
    put :update, construct_params({ version: version, id: sample_article.parent_id }, params_hash)
    assert_response 200
    draft = sample_article.reload.draft
    assert_equal sample_article.reload.title, article_title
    assert_equal sample_article.reload.description, article_description
    assert_equal draft.title, 'new title'
    assert_equal draft.description, paragraph
  end

  def test_no_draft_is_created_when_title_description_and_status_is_not_passed_in_public_api
    sample_article = get_article_without_draft
    params_hash = { 'seo_data' => { 'meta_title' => Faker::Name.name, 'meta_description' => Faker::Name.name } }
    put :update, construct_params({ version: version, id: sample_article.parent_id }, params_hash)
    assert_response 200
    draft = sample_article.reload.draft
    assert draft.nil?
  end

  def test_article_draft_title_description_updated_when_no_status_is_passed_in_public_api
    sample_article = get_article_with_draft
    article_title = sample_article.title
    article_description = sample_article.description
    paragraph = Faker::Lorem.paragraph
    params_hash = { 'title' => 'new title', 'description' => paragraph, 'type' => 2 }
    put :update, construct_params({ version: version, id: sample_article.parent_id }, params_hash)
    assert_response 200
    draft = sample_article.reload.draft
    assert_equal sample_article.reload.title, article_title
    assert_equal sample_article.reload.description, article_description
    assert_equal draft.title, 'new title'
    assert_equal draft.description, paragraph
  end

  def test_published_with_draft_article_titile_description_update_when_no_status_is_passed_in_public_api
    sample_article = get_article_without_draft
    draft = sample_article.draft
    assert draft.nil?
    create_draft(article: sample_article)
    draft = sample_article.reload.draft
    assert !draft.nil?
    article_title = sample_article.reload.title
    article_description = sample_article.reload.description
    paragraph = Faker::Lorem.paragraph
    params_hash = { 'title' => 'new title', 'description' => paragraph, 'type' => 2 }
    put :update, construct_params({ version: version, id: sample_article.parent_id }, params_hash)
    assert_response 200
    draft = sample_article.reload.draft
    assert_equal sample_article.reload.title, article_title
    assert_equal sample_article.reload.description, article_description
    assert_equal draft.title, 'new title'
    assert_equal draft.description, paragraph
  end

  def test_update_draft_with_unavailable_agent_id
    sample_article = get_article_with_draft
    params_hash = { agent_id: 9999, status: 2 }
    put :update, construct_params({ version: version, id: sample_article.parent_id }, params_hash)
    assert_response 400
    match_json([bad_request_error_pattern('agent_id', :invalid_agent_id)])
  end

  def test_update_article_with_unavailable_user_id
    sample_article = get_article
    paragraph = Faker::Lorem.paragraph
    params_hash = { title: 'new title', description: paragraph, status: 2, type: 2, agent_id: 9999 }
    put :update, construct_params({ version: version, id: sample_article.parent_id }, params_hash)
    assert_response 400
    match_json([bad_request_error_pattern('agent_id', :invalid_agent_id)])
  end

  def test_update_unavailalbe_article
    paragraph = Faker::Lorem.paragraph
    params_hash = { title: 'new title', description: paragraph, status: 2, type: 2 }
    put :update, construct_params({ version: version, id: 9999 }, params_hash)
    assert_response :missing
  end

  def test_update_unavailable_article_with_language
    paragraph = Faker::Lorem.paragraph
    params_hash = { title: 'new title', description: paragraph, status: 2, type: 2 }
    put :update, construct_params({ version: version, id: 9999, language: @account.supported_languages.last }, params_hash)
    assert_response :missing
  end

  def test_update_article_type
    sample_article = get_article_without_draft
    old_description = sample_article.description
    params_hash = { type: 2, status: 2 }
    put :update, construct_params({ version: version, id: sample_article.parent_id }, params_hash)
    assert_response 200
    match_json(article_pattern(sample_article.reload))
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
    put :update, construct_params({ version: version, id: sample_article.parent_id, language: language }, title: title, description: description, status: status, category_name: category_name, folder_name: folder_name)
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
    put :update, construct_params({ version: version, id: sample_article.parent_id, language: language }, title: title, description: description, status: status, category_name: 'category', folder_name: 'folder')
    assert_response 400
    match_json([bad_request_error_pattern('folder_name', :attribute_not_required, code: :incompatible_field),
                bad_request_error_pattern('category_name', :attribute_not_required, code: :incompatible_field)])
  end

  def test_update_article_with_user_id_without_privilege
    User.any_instance.stubs(:privilege?).with(:manage_solutions).returns(true)
    User.any_instance.stubs(:privilege?).with(:create_and_edit_article).returns(true)
    User.any_instance.stubs(:privilege?).with(:publish_solution).returns(true)
    User.any_instance.stubs(:privilege?).with(:delete_solution).returns(true)
    User.any_instance.stubs(:privilege?).with(:admin_tasks).returns(false)
    sample_article = get_article
    paragraph = Faker::Lorem.paragraph
    params_hash = { title: 'new title', description: paragraph, status: 2, type: 2, agent_id: @agent.id }
    put :update, construct_params({ version: version, id: sample_article.parent_id }, params_hash)
    assert_response 400
    match_json([bad_request_error_pattern('agent_id', :inaccessible_field)])
  ensure
    User.any_instance.unstub(:privilege?)
  end

  def test_folder_index
    sample_folder = get_folder_meta
    get :folder_articles, controller_params(version: version, id: sample_folder.id)
    assert_response 200
    articles = sample_folder.solution_articles.where(language_id: @account.language_object.id).reorder(Solution::Constants::ARTICLE_ORDER_COLUMN_BY_TYPE[sample_folder.article_order]).limit(30)
    pattern = articles.map { |article| article_pattern_index(article) }
    match_json(pattern.ordered!)
  end

  def test_folder_index_with_language_param
    sample_folder = get_folder_meta
    get :folder_articles, controller_params(version: version, id: sample_folder.id, language: @account.supported_languages.last)
    assert_response 200
    articles = sample_folder.solution_articles.where(language_id: Language.find_by_code(@account.supported_languages.last).id).reorder(Solution::Constants::ARTICLE_ORDER_COLUMN_BY_TYPE[sample_folder.article_order])
    pattern = articles.map { |article| article_pattern_index(article) }
    match_json(pattern.ordered!)
  end

  def test_folder_index_with_language_param_having_primary_language
    sample_folder = get_folder_meta
    get :folder_articles, controller_params(version: version, id: sample_folder.id, language: @account.language)
    assert_response 200
    articles = sample_folder.solution_articles.where(language_id: @account.language_object.id).reorder(Solution::Constants::ARTICLE_ORDER_COLUMN_BY_TYPE[sample_folder.article_order]).limit(30)
    pattern = articles.map { |article| article_pattern_index(article) }
    match_json(pattern.ordered!)
  end

  # default index params test
  def test_index_with_invalid_page_and_per_page
    sample_folder = get_folder_meta
    get :folder_articles, controller_params(version: version, id: sample_folder.id, page: 'aaa', per_page: 'aaa')
    assert_response 400
    match_json([bad_request_error_pattern('page', :datatype_mismatch, expected_data_type: 'Positive Integer'),
                bad_request_error_pattern('per_page', :per_page_invalid, max_value: 100)])
  end

  # Delete article
  def test_delete_article
    sample_article = get_article_without_translation
    delete :destroy, construct_params(version: version, id: sample_article.parent_id)
    assert_response 204
  end

  def test_delete_article_with_language_param
    sample_article = get_article
    language_code = Language.find(sample_article.language_id).code
    delete :destroy, construct_params(version: version, id: sample_article.parent_id, language: language_code)
    assert_response 404
  end

  def test_delete_unavailable_article
    delete :destroy, construct_params(id: 9999)
    assert_response :missing
  end

  def test_create_with_attachment
    file = fixture_file_upload('/files/attachment.txt', 'plain/text', :binary)
    file2 = fixture_file_upload('files/image33kb.jpg', 'image/jpg')
    DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
    @request.env['CONTENT_TYPE'] = 'multipart/form-data'
    folder_meta = get_folder_meta
    title = Faker::Name.name
    paragraph = Faker::Lorem.paragraph
    post :create, construct_params({ version: version, id: folder_meta.id }, title: title, description: paragraph, status: 1, type: 2, attachments: [file, file2])
    DataTypeValidator.any_instance.unstub(:valid_type?)
    assert_response 201
    result = parse_response(@response.body)
    assert_equal "http://#{@request.host}/api/v2/solutions/articles/#{result['id']}", response.headers['Location']
    assert Solution::Article.last.attachments.count == 2
  end

  def test_create_with_invalid_attachment_array
    folder_meta = get_folder_meta
    title = Faker::Name.name
    paragraph = Faker::Lorem.paragraph
    controller_params = { title: title, description: paragraph, status: 1, type: 2 }
    params = controller_params.merge('attachments' => [1, 2])
    post :create, construct_params({ version: version, id: folder_meta.id }, params)
    assert_response 400
    match_json([bad_request_error_pattern('attachments', :array_datatype_mismatch, expected_data_type: 'valid file format')])
  end

  def test_create_with_invalid_attachment_type
    folder_meta = get_folder_meta
    title = Faker::Name.name
    paragraph = Faker::Lorem.paragraph
    controller_params = { title: title, description: paragraph, status: 1, type: 2 }
    params = controller_params.merge('attachments' => 'test')
    post :create, construct_params({ version: version, id: folder_meta.id }, params)
    assert_response 400
    match_json([bad_request_error_pattern('attachments', :datatype_mismatch, expected_data_type: Array, given_data_type: String, prepend_msg: :input_received)])
  end

  def test_create_with_invalid_empty_attachment
    folder_meta = get_folder_meta
    title = Faker::Name.name
    paragraph = Faker::Lorem.paragraph
    controller_params = { title: title, description: paragraph, status: 1, type: 2 }
    params = controller_params.merge('attachments' => [])
    post :create, construct_params({ version: version, id: folder_meta.id }, params)
    assert_response 201
  end

  def test_create_with_invalid_attachment_size
    invalid_attachment_limit = @account.attachment_limit + 2
    Rack::Test::UploadedFile.any_instance.stubs(:size).returns(invalid_attachment_limit.megabytes)
    file = fixture_file_upload('/files/attachment.txt', 'plain/text', :binary)
    folder_meta = get_folder_meta
    title = Faker::Name.name
    paragraph = Faker::Lorem.paragraph
    controller_params = { title: title, description: paragraph, status: 1, type: 2 }
    params = controller_params.merge('attachments' => [file])
    DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
    post :create, construct_params({ version: version, id: folder_meta.id }, params)
    DataTypeValidator.any_instance.unstub(:valid_type?)
    assert_response 400
    match_json([bad_request_error_pattern('attachments', :invalid_size, max_size: "#{@account.attachment_limit} MB", current_size: "#{invalid_attachment_limit} MB")])
  end

  def test_update_with_attachment
    file = fixture_file_upload('/files/attachment.txt', 'plain/text', :binary)
    file2 = fixture_file_upload('files/image33kb.jpg', 'image/jpg')
    sample_article = get_article
    attachments_count = sample_article.attachments.count
    paragraph = Faker::Lorem.paragraph
    params_hash = { title: 'new title', description: paragraph, status: 2, type: 2, agent_id: @agent.id }
    params = params_hash.merge('attachments' => [file, file2])
    DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
    put :update, construct_params({ version: version, id: sample_article.parent_id }, params)
    DataTypeValidator.any_instance.unstub(:valid_type?)
    assert_response 200
    match_json(article_pattern(sample_article.reload))
    assert sample_article.attachments.count == (attachments_count + 2)
  end

  def test_update_with_invalid_attachment_size
    attachment = create_attachment(attachable_type: 'UserDraft', attachable_id: @agent.id)
    invalid_attachment_limit = @account.attachment_limit + 2
    Helpdesk::Attachment.any_instance.stubs(:content_file_size).returns(invalid_attachment_limit.megabytes)
    Helpdesk::Attachment.any_instance.stubs(:size).returns(invalid_attachment_limit.megabytes)
    sample_article = get_article_without_draft
    paragraph = Faker::Lorem.paragraph
    params_hash = { title: 'new title', description: paragraph, status: 2, type: 2, agent_id: @agent.id }
    params = params_hash.merge('attachments' => [attachment])
    DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
    Solution::Article.any_instance.stubs(:attachments).returns([attachment])
    put :update, construct_params({ version: version, id: sample_article.parent_id }, params)
    DataTypeValidator.any_instance.unstub(:valid_type?)
    Helpdesk::Attachment.any_instance.unstub(:content_file_size)
    Helpdesk::Attachment.any_instance.unstub(:size)
    Solution::Article.any_instance.unstub(:attachments)
    assert_response 400
    match_json([bad_request_error_pattern('attachments', :invalid_size, max_size: "#{@account.attachment_limit} MB", current_size: "#{2 * invalid_attachment_limit} MB")])
  end

  def test_update_with_invalid_attachment_params_format
    sample_article = get_article
    paragraph = Faker::Lorem.paragraph
    params_hash = { title: 'new title', description: paragraph, status: 2, type: 2, agent_id: @agent.id }
    params = params_hash.merge('attachments' => [1, 2])
    put :update, construct_params({ version: version, id: sample_article.parent_id }, params)
    assert_response 400
    match_json([bad_request_error_pattern('attachments', :array_datatype_mismatch, expected_data_type: 'valid file format')])
  end

  def test_update_article_in_draft_status_with_no_draft
    sample_article = get_article_without_draft
    paragraph = Faker::Lorem.paragraph
    article_title = sample_article.title
    article_description = sample_article.description
    title = 'Test Draft Title'
    params_hash = {
      title: title, description: paragraph,
      status: 1, agent_id: @agent.id
    }
    put :update, construct_params({ version: version, id: sample_article.parent_id }, params_hash)
    assert_response 200
    draft = sample_article.reload.draft
    assert draft.present?
    match_json(article_draft_pattern(sample_article, draft))
    assert draft.title == title
    assert draft.description == paragraph
    assert sample_article.parent.reload.user_id == @agent.id

    assert sample_article.title == article_title
    assert sample_article.description == article_description
  end

  def test_update_article_in_published_status_with_no_draft
    sample_article = get_article_without_draft
    paragraph = Faker::Lorem.paragraph
    title = 'Test Article Title'
    params_hash = {
      title: title, description: paragraph,
      status: 2, agent_id: @agent.id
    }
    put :update, construct_params({ version: version, id: sample_article.parent_id }, params_hash)
    assert_response 200
    sample_article.reload
    match_json(article_pattern(sample_article))
    draft = sample_article.draft
    refute draft.present?
    assert sample_article.title == title
    assert sample_article.description == paragraph
    assert sample_article.parent.reload.user_id == @agent.id
  end

  def test_update_article_in_draft_status_with_draft
    sample_article = get_article_with_draft
    paragraph = Faker::Lorem.paragraph
    article_title = sample_article.title
    article_description = sample_article.description
    title = 'Test Draft Title'
    params_hash = {
      title: title, description: paragraph,
      status: 1, agent_id: @agent.id
    }
    put :update, construct_params({ version: version, id: sample_article.parent_id }, params_hash)
    assert_response 200
    draft = sample_article.reload.draft
    assert draft.present?
    match_json(article_draft_pattern(sample_article, draft))
    assert draft.title == title
    assert draft.description == paragraph
    assert sample_article.parent.reload.user_id == @agent.id

    assert sample_article.title == article_title
    assert sample_article.description == article_description
  end

  def test_update_article_in_published_status_with_draft
    sample_article = get_article_without_draft
    paragraph = Faker::Lorem.paragraph
    title = 'Test Article Title'
    params_hash = {
      title: title, description: paragraph,
      status: 2, agent_id: @agent.id
    }
    put :update, construct_params({ version: version, id: sample_article.parent_id }, params_hash)
    assert_response 200
    sample_article.reload
    match_json(article_pattern(sample_article))
    draft = sample_article.draft
    refute draft.present?
    assert sample_article.title == title
    assert sample_article.description == paragraph
    assert sample_article.parent.reload.user_id == @agent.id
  end

  def test_update_article_with_tags_with_privilege
    sample_article = get_article
    tags = Faker::Lorem.words(3).uniq
    tags = tags.map do |tag|
      # Timestamp added to make sure tag names are new
      tag = "#{tag}#{Time.now.to_i}"
      assert_equal @account.tags.map(&:name).include?(tag), false
      tag
    end
    put :update, construct_params({ version: version, id: sample_article.parent_id }, tags: tags, status: 2)
    assert_response 200
    assert_equal sample_article.reload.tags.count, tags.count
    put :update, construct_params({ id: sample_article.parent_id }, tags: [])
  end

  def test_update_article_with_new_tags_without_privilege
    sample_article = get_article
    initial_tag_count = sample_article.tags.count
    tags = Faker::Lorem.words(3).uniq
    tags = tags.map do |tag|
      # Timestamp added to make sure tag names are new
      tag = "#{tag}#{Time.now.to_i}#{rand(1_000_000_000)}"
      assert_equal @account.tags.map(&:name).include?(tag), false
      tag
    end
    User.current.reload
    remove_privilege(User.current, :create_tags)
    put :update, construct_params({ version: version, id: sample_article.parent_id }, tags: tags, status: 1)
    assert_response 400
    assert_equal sample_article.reload.tags.count, initial_tag_count
    add_privilege(User.current, :create_tags)
  end

  def test_update_article_with_existing_tags_without_privilege
    sample_article = get_article
    tag = Faker::Lorem.word
    @account.tags.create(name: tag) unless @account.tags.map(&:name).include?(tag)
    User.current.reload
    remove_privilege(User.current, :create_tags)
    put :update, construct_params({ version: version, id: sample_article.parent_id }, tags: [tag], status: 1)
    assert_response 200
    assert_equal sample_article.reload.tags.count, 1
    add_privilege(User.current, :create_tags)
    put :update, construct_params({ version: version, id: sample_article.parent_id }, tags: [])
  end

  def test_update_article_unpublish_with_incorrect_credentials
    @controller.stubs(:api_current_user).raises(ActiveSupport::MessageVerifier::InvalidSignature)
    put :update, construct_params(version: version, id: 1, status: Solution::Article::STATUS_KEYS_BY_TOKEN[:draft])
    assert_response 401
    assert_equal request_error_pattern(:credentials_required).to_json, response.body
  ensure
    @controller.unstub(:api_current_user)
  end

  def test_update_article_unpublish_without_publish_solution_privilege
    User.any_instance.stubs(:privilege?).with(:admin_tasks).returns(true)
    User.any_instance.stubs(:privilege?).with(:create_and_edit_article).returns(true)
    User.any_instance.stubs(:privilege?).with(:publish_solution).returns(false)
    User.any_instance.stubs(:privilege?).with(:publish_approved_solution).returns(false)
    put :update, construct_params(version: version, id: 1, status: Solution::Article::STATUS_KEYS_BY_TOKEN[:draft])
    assert_response 403
    error_info_hash = { details: 'dont have permission to perfom on published article' }
    match_json(request_error_pattern_with_info(:published_article_privilege_error, error_info_hash, error_info_hash))
  ensure
    User.any_instance.unstub(:privilege?)
  end

  def test_update_article_unpublish_without_access
    user = add_new_user(@account, active: true)
    login_as(user)
    put :update, construct_params(version: version, id: 1, status: Solution::Article::STATUS_KEYS_BY_TOKEN[:draft])
    assert_response 403
    match_json(request_error_pattern(:access_denied))
    @admin = get_admin
    login_as(@admin)
  end

  def test_update_article_unpublish_for_non_existant_article
    put :update, construct_params(version: version, id: 0, status: Solution::Article::STATUS_KEYS_BY_TOKEN[:draft])
    assert_response 404
  end

  def test_update_article_unpublish_with_invalid_field
    put :update, construct_params(version: version, id: 1, test: 'test', status: Solution::Article::STATUS_KEYS_BY_TOKEN[:draft])
    assert_response 400
    match_json([bad_request_error_pattern('test', :invalid_field)])
  end

  def test_update_article_unpublish
    article = create_article(article_params)
    put :update, construct_params(version: version, id: article.id, status: Solution::Article::STATUS_KEYS_BY_TOKEN[:draft])
    assert_response 200
    assert_equal Solution::Article::STATUS_KEYS_BY_TOKEN[:draft], article.reload.primary_article.status
  end

  def test_update_article_unpublish_with_language_without_multilingual_feature
    Account.any_instance.stubs(:multilingual?).returns(false)
    put :update, construct_params(version: version, id: 0, status: Solution::Article::STATUS_KEYS_BY_TOKEN[:draft], language: @account.supported_languages.last)
    match_json(request_error_pattern(:require_feature, feature: 'MultilingualFeature'))
    assert_response 404
  ensure
    Account.any_instance.unstub(:multilingual?)
  end

  def test_update_article_unpublish_with_invalid_language
    article = create_article(article_params)
    put :update, construct_params(version: version, id: article.id, status: Solution::Article::STATUS_KEYS_BY_TOKEN[:draft], language: 'test')
    assert_response 404
    match_json(request_error_pattern(:language_not_allowed, code: 'test', list: (@account.supported_languages + [@account.language]).sort.join(', ')))
  end

  def test_update_article_unpublish_with_primary_language
    article = create_article(article_params)
    put :update, construct_params(version: version, id: article.id, status: Solution::Article::STATUS_KEYS_BY_TOKEN[:draft], language: @account.language)
    assert_response 200
    assert_equal Solution::Article::STATUS_KEYS_BY_TOKEN[:draft], article.reload.primary_article.status
  end

  def test_update_article_unpublish_with_supported_language
    languages = @account.supported_languages + ['primary']
    language = @account.supported_languages.first
    article = create_article(article_params(lang_codes: languages))
    put :update, construct_params(version: version, id: article.id, status: Solution::Article::STATUS_KEYS_BY_TOKEN[:draft], language: language)
    assert_response 200
    assert_equal Solution::Article::STATUS_KEYS_BY_TOKEN[:draft], article.reload.safe_send("#{language}_article").status
  end

  def test_create_article_without_type
    folder_meta = get_folder_meta
    title = Faker::Name.name
    paragraph = Faker::Lorem.paragraph
    post :create, construct_params({ version: version, id: folder_meta.id }, title: title, description: paragraph, status: 1)
    assert_response 201
    result = parse_response(@response.body)
    assert_equal "http://#{@request.host}/api/v2/solutions/articles/#{result['id']}", response.headers['Location']
    match_json(article_pattern(Solution::Article.last))
    article = Solution::Article.last
    assert article.title == title
    assert article.desc_un_html.strip == paragraph
    assert article.user_id == @agent.id
    assert article.status == 1
    assert article.parent.art_type == 1
  end

  def test_create_article_with_privateapi_cloud_attachment_params
    folder_meta = get_folder_meta
    title = Faker::Name.name
    paragraph = Faker::Lorem.paragraph
    cloud_file_params = [{ name: 'image.jpg', link: CLOUD_FILE_IMAGE_URL, provider: 'dropbox' }]
    post :create, construct_params({ version: version, id: folder_meta.id }, title: title, description: paragraph, status: 1, cloud_file_attachments: cloud_file_params)
    assert_response 400
    match_json([bad_request_error_pattern('cloud_file_attachments', 'is invalid', code: :invalid_value)])
  end
end
