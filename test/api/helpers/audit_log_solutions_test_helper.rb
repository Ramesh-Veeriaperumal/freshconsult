module AuditLogSolutionsTestHelper
  # Helper to mock Hypertrail response and to build the payload sent to helpkit-ember

  include AuditLogConstants

  def solution_category_sample_data
    {
      links: meta_link('solution_categories', 1_669_021_680_575_178_624),
      data: [category_create_payload, category_update_payload, category_destroy_payload]
    }
  end

  def solution_category_filter_response
    [category_create_response, category_update_response, category_destroy_response]
  end

  def solution_category_next_url
    next_link('solution_categories', 1_669_021_680_575_178_624)
  end

  def solution_folder_sample_data
    {
      links: meta_link('solution_folders', 1_669_210_518_219_128_320),
      data: [folder_create_payload, folder_update_payload, folder_destroy_payload]
    }
  end

  def solution_folder_filter_response
    [folder_create_response, folder_update_response, folder_destroy_response]
  end

  def solution_folder_next_url
    next_link('solution_folders', 1_669_210_518_219_128_320)
  end

  def solution_article_sample_data
    {
      links: meta_link('solution_articles', 1_669_300_418_664_720_896),
      data: [article_create_payload, article_update_payload, article_destroy_payload]
    }
  end

  def solution_article_filter_response
    [article_create_response, article_update_response, article_destroy_response]
  end

  def solution_article_apporval_data
    approval_event_payload = approval_event_changes.values.map { |value| { approval_status: value } } + [{ approval_status: [2, nil], draft_exists: [1, 0] }]
    {
      links: meta_link('solution_articles', 1_669_300_418_664_720_896),
      data: approval_event_payload.map! { |changes| article_update_payload(changes) }
    }
  end

  def solution_article_approval_response
    response_description = approval_event_response.values
    response_description.map! { |status_change| update_activity_default_response_description('Status', status_change) }
    response_description.map! { |description| article_update_response(description) }
  end

  def solution_article_reset_ratings_data(opts = {})
    {
      links: meta_link('solution_articles', 1_669_300_418_664_720_896),
      data: [reset_ratings_payload(opts), reset_ratings_payload]
    }
  end

  def solution_article_reset_ratings_response(opts = {})
    [reset_ratings_response(opts), reset_ratings_response]
  end

  def solution_article_next_url
    next_link('solution_articles', 1_669_300_418_664_720_896)
  end

  private

    def category_create_payload
      {
        actor: agent_object,
        timestamp: 1_592_048_947_414,
        model: 'Solution::Category',
        object: category_object,
        account_id: '11_010_040_535',
        ip_address: '115.112.69.51',
        action: 'category_create'
      }
    end

    def category_update_payload
      {
        actor: agent_object,
        timestamp: 1_591_935_198_044,
        model: 'Solution::Category',
        changes: {
          description: ['Old is Gold', 'Gold is Gold'],
          name: ['Gold', 'Gold Girl']
        },
        object: category_object,
        account_id: 11_010_040_535,
        ip_address: '115.112.69.51',
        action: 'category_update'
      }
    end

    def category_destroy_payload
      {
        actor: agent_object,
        timestamp: 1_592_048_969_015,
        model: 'Solution::Category',
        object: category_object.slice(:name, :id, :account_id, :language_code, :category_id),
        account_id: 11_010_040_535,
        ip_address: '115.112.69.51',
        action: 'category_destroy'
      }
    end

    def category_create_response
      {
        time: 1_592_048_947_414,
        ip_address: '115. 112. 69. 51',
        name: { url_type: 'category' }.merge!(category_object.slice(:name, :id, :language_code)),
        event_performer: event_performer,
        action: 'create',
        event_type: 'Knowledge Base - Category'
      }
    end

    def category_update_response
      {
        time: 1_591_935_198_044,
        ip_address: '115. 112. 69. 51',
        name: { url_type: 'category' }.merge!(category_object.slice(:name, :id, :language_code)),
        event_performer: event_performer,
        action: 'update',
        event_type: 'Knowledge Base - Category',
        description: [
          update_activity_default_response_description('Description', ['Old is Gold', 'Gold is Gold']),
          update_activity_default_response_description('Name', ['Gold', 'Gold Girl'])
        ]
      }
    end

    def category_destroy_response
      {
        time: 1_592_048_969_015,
        ip_address: '115. 112. 69. 51',
        name: { url_type: 'category' }.merge!(category_object.slice(:name, :id, :language_code)),
        event_performer: event_performer,
        action: 'destroy',
        event_type: 'Knowledge Base - Category'
      }
    end

    def category_object
      {
        name: 'Gold Girl',
        language_id: 6,
        description: 'Gold is Gold',
        id: 10_660,
        account_id: 11_010_040_535,
        language_code: 'en',
        category_id: 13_994,
        created_at: '2020-06-12T04:12:41Z',
        updated_at: '2020-06-12T04:13:18Z'
      }
    end

    def folder_create_payload
      {
        actor: agent_object,
        timestamp: 1_592_048_953_904,
        model: 'Solution::Folder',
        object: folder_object,
        account_id: '11010040535',
        ip_address: '115.112.69.51',
        action: 'folder_create'
      }
    end

    def folder_update_payload
      {
        actor: agent_object,
        timestamp: 1_591_935_332_963,
        model: 'Solution::Folder',
        changes: {
          name: ['Bronze Boy', 'Bronze Boys'],
          description: ['Boys are back', 'Bronze Boys are back'],
          solution_category_meta_id: [10_660, 10_571],
          solution_category_name: ['Gold Girl', 'General'],
          article_order: [1, 3],
          visibility: [1, 2]
        },
        object: folder_object,
        account_id: '11010040535',
        ip_address: '115.112.69.51',
        action: 'folder_update'
      }
    end

    def folder_destroy_payload
      {
        actor: agent_object,
        timestamp: 1_592_048_970_195,
        model: 'Solution::Folder',
        object: folder_object.slice(:name, :id, :language_code, :account_id, :folder_id),
        account_id: '11010040535',
        ip_address: nil,
        action: 'folder_destroy'
      }
    end

    def folder_create_response
      {
        time: 1_592_048_953_904,
        ip_address: '115. 112. 69. 51',
        name: { url_type: 'folder' }.merge!(folder_object.slice(:name, :id, :language_code)),
        event_performer: event_performer,
        action: 'create',
        event_type: 'Knowledge Base - Folder'
      }
    end

    def folder_update_response
      {
        time: 1_591_935_332_963,
        ip_address: '115. 112. 69. 51',
        name: { url_type: 'folder' }.merge!(folder_object.slice(:name, :id, :language_code)),
        event_performer: event_performer,
        action: 'update',
        event_type: 'Knowledge Base - Folder',
        description: [
          update_activity_default_response_description('Name', ['Bronze Boy', 'Bronze Boys']),
          update_activity_default_response_description('Description', ['Boys are back', 'Bronze Boys are back']),
          update_activity_default_response_description('Category changed', ['Gold Girl', 'General']),
          update_activity_default_response_description('Ordering', [1, 3].map { |id| translate_folder_property('ordering', ORDERING_NAMES_BY_ID[id]) }),
          update_activity_default_response_description('Visibility', [1, 2].map { |id| translate_folder_property('visible_to', VISIBILITY_NAMES_BY_ID[id]) })
        ]
      }
    end

    def folder_destroy_response
      {
        time: 1_592_048_970_195,
        ip_address: nil,
        name: { url_type: 'folder' }.merge!(folder_object.slice(:name, :id, :language_code)),
        event_performer: event_performer,
        action: 'destroy',
        event_type: 'Knowledge Base - Folder'
      }
    end

    def folder_object
      {
        name: 'Bronze Boys',
        language_id: 6,
        description: 'Bronze Boys are back',
        folder_id: 18_113,
        id: 14_661,
        account_id: 11_010_040_535,
        article_order: 3,
        language_code: 'en',
        category_id: 10_571,
        created_at: '2020-06-12T04:14:42Z',
        updated_at: '2020-06-12T04:15:32Z',
        visibility: 2
      }
    end

    def article_create_payload
      {
        actor: agent_object,
        timestamp: 1_592_048_591_042,
        model: 'Solution::Article',
        object: article_object,
        account_id: 11_010_040_535,
        ip_address: '115.112.69.51',
        action: 'article_create'
      }
    end

    def article_update_payload(changes_params = {})
      {
        actor: agent_object,
        timestamp: 1_592_048_624_098,
        model: 'Solution::Article',
        object: article_object,
        account_id: 11_010_040_535,
        ip_address: '115.112.69.51',
        action: 'article_update',
        changes: changes_params.presence || article_update_sample_changes
      }
    end

    def article_destroy_payload
      {
        actor: event_performer,
        timestamp: 1_592_048_466_370,
        model: 'Solution::Article',
        object: article_object.slice(:id, :title, :account_id, :language_code, :article_id),
        account_id: 11_010_040_535,
        ip_address: '115.112.69.51',
        action: 'article_destroy'
      }
    end

    def article_create_response
      {
        time: 1_592_048_591_042,
        ip_address: '115. 112. 69. 51',
        name: { name: article_object[:title], url_type: 'article' }.merge!(article_object.slice(:id, :language_code)),
        event_performer: event_performer,
        action: 'create',
        event_type: 'Knowledge Base - Article'
      }
    end

    def article_update_response(changes_params = {})
      {
        time: 1_592_048_624_098,
        ip_address: '115. 112. 69. 51',
        name: { name: article_object[:title], url_type: 'article' }.merge!(article_object.slice(:id, :language_code)),
        event_performer: event_performer,
        action: 'update',
        event_type: 'Knowledge Base - Article',
        description: changes_params.present? ? [changes_params] : article_update_sample_changes_response
      }
    end

    def article_destroy_response
      {
        time: 1_592_048_466_370,
        ip_address: '115. 112. 69. 51',
        name: { name: article_object[:title], url_type: 'article' }.merge!(article_object.slice(:id, :language_code)),
        event_performer: event_performer,
        action: 'destroy',
        event_type: 'Knowledge Base - Article'
      }
    end

    def reset_ratings_payload(opts = {})
      {
        actor: agent_object,
        timestamp: 1_592_115_807_207,
        model: 'Solution::Article',
        changes: { thumbs_down: [0, 0], article_thumbs_down: [0, 0], article_thumbs_up: [1, 0], thumbs_up: [1, 0] },
        object: reset_rating_object(opts),
        account_id: '11010040535',
        ip_address: '115.112.69.51',
        action: 'article_update'
      }
    end

    def reset_ratings_response(opts = {})
      article = Account.current.solution_articles.find(opts[:article_id]) if opts[:article_id]
      response_hash = {
        time: 1_592_115_807_207,
        ip_address: '115. 112. 69. 51',
        name: { url_type: 'article', id: opts[:id] || 999_999 },
        event_performer: event_performer,
        action: 'update',
        event_type: 'Knowledge Base - Article',
        description: [update_activity_default_response_description('Reset Likes and Dislikes')]
      }
      response_hash[:name][:name] = article.present? ? article.title : t('deleted')
      response_hash[:name][:language_code] = article.present? ? article.language_code : nil
      response_hash
    end

    def reset_rating_object(opts = {})
      {
        thumbs_up: 0,
        article_suggested: nil,
        article_hits: 3,
        article_thumbs_up: 0,
        id: opts[:id] || 999_999,
        account_id: 11_010_040_535,
        hits: 3,
        article_id: opts[:article_id] || 999_998,
        thumbs_down: 0,
        article_thumbs_down: 0
      }
    end

    def article_update_sample_changes
      {
        solution_folder_name: ['BMW', 'Bentley'],
        description: 'description changes',
        solution_folder_meta_id: [14_552, 14_663],
        agent_name: ['Spiderman123', 'Aravindhan'],
        agent_id: [364_938, 365_158],
        tags: { added_tags: ['Cool'], removed_tags: ['Fool'] },
        status: [1, 2]
      }
    end

    def article_update_sample_changes_response
      [
        update_activity_default_response_description('Folder changed', ['BMW', 'Bentley']),
        update_activity_default_response_description('Description'),
        update_activity_default_response_description('Author changed', ['Spiderman123', 'Aravindhan']),
        update_activity_nested_response_description('Tags', [{ Added: 'Cool' }, { Removed: 'Fool' }]),
        update_activity_default_response_description('Status', [t('draft'), t('published')])
      ]
    end

    def article_object
      {
        published_by: nil,
        thumbs_up: 0,
        language_id: 6,
        tags: [],
        outdated: false,
        draft_exists: 1,
        folder_id: 14_552,
        id: 59_549,
        account_id: 11_010_040_535,
        modified_by: 364_938,
        hits: 0,
        language_code: 'en',
        status: 1,
        modified_at: '2020-06-13T11:43:10Z',
        article_id: 65_520,
        approved_at: nil,
        category_id: 10_570,
        created_at: '2020-06-13T11:43:10Z',
        draft_modified_by: 364_938,
        title: 'Tantanatan',
        type: 1,
        updated_at: '2020-06-13T11:43:11Z',
        approved_by: nil,
        thumbs_down: 0,
        approval_status: nil,
        published_at: nil,
        draft_modified_at: '2020-06-13T11:43:10Z',
        agent_id: 364_938,
        seo_data: {}
      }
    end

    def approval_event_changes
      # Possible apporval status payload for approval events
      {
        invalid_status: [26, 999_999],
        send_for_review: [nil, 1],
        discard_draft_of_approved: [nil, 2],
        approved: [1, 2],
        edit_in_review: [1, nil],
        edit_in_approved: [2, nil]
      }
      # publish_approved_article: { approval_status: [2, nil], draft_exists: [1, 0] }
    end

    def approval_event_response
      # Possible apporval status response for approval events
      {
        invalid_status: [26, 999_999],
        send_for_review: [t('draft'), t('in_review')],
        discard_draft_of_approved: [t('draft'), t('approved')],
        approved: [t('in_review'), t('approved')],
        edit_in_review: [t('in_review'), t('draft')],
        edit_in_approved: [t('approved'), t('draft')],
        publish_approved: [t('approved'), t('published')]
      }
    end

    def agent_object
      { name: 'Spiderman123', id: 364_938, type: 'agent' }
    end

    def event_performer
      { name: 'Spiderman123', id: 364_938, url_type: 'agent' }
    end

    def update_activity_default_response_description(field_name, value = nil)
      response_hash = { type: 'default', field: field_name }
      value = value.present? ? { value: { from: value[0], to: value[1] } } : { value: nil }
      response_hash.merge!(value)
    end

    def update_activity_array_response_description(object)
      { type: 'array', field: object.keys.first, value: [{ type: 'default', field: '', value: object.values.first, id: nil }] }
    end

    def update_activity_nested_response_description(field, value)
      { type: 'array', field: field, value: value.map! { |object| update_activity_array_response_description(object) } }
    end

    def meta_link(filter_type, next_token)
      [{ rel: 'next', href: next_link(filter_type, next_token), type: 'GET' }]
    end

    def next_link(filter_type, next_token)
      "https://hypertrail-staging.freshworksapi.com/api/v1/audit/account/11010040535?type=#{filter_type}&nextToken=#{next_token}"
    end

    def t(token)
      I18n.t("admin.audit_log.solution_article.#{token}")
    end

    def translate_folder_property(property, token)
      I18n.t("admin.audit_log.solution_folder.#{property}.#{token}")
    end
end
