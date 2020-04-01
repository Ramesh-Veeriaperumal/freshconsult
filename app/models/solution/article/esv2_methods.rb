class Solution::Article < ActiveRecord::Base

  def to_esv2_json
    as_json({
        root: false,
        tailored_json: true,
        only: [ :title, :desc_un_html, :user_id, :status, :created_at,
                :updated_at, :thumbs_up, :thumbs_down, :account_id, :modified_at,
                :hits, :language_id, :modified_by, :outdated
              ],
        methods: [ :tag_names, :tag_ids ]
      }).merge(meta_referenced_attributes)
        .merge(es_draft_attributes)
        .merge(attachments: es_v2_attachments).to_json
  end

  def es_draft_attributes
    draft.present? ? draft_attr_hash(Solution::Constants::DRAFT_STATUSES_ES[:draft_present], draft.modified_by, draft.modified_at) : draft_attr_hash(Solution::Constants::DRAFT_STATUSES_ES[:draft_not_present], nil, nil)
  end

  def draft_attr_hash(status, modified_by, modified_at)
    { draft_status: draft_status, draft_modified_by: modified_by, draft_modified_at: modified_at }
  end

  def draft_status
    status = Solution::Constants::DRAFT_STATUSES_ES[:draft_not_present]
    status = Solution::Constants::DRAFT_STATUSES_ES[:draft_present] if self.draft_present?
    status = self.helpdesk_approval.try(:approval_status) if Account.current.article_approval_workflow_enabled? && self.helpdesk_approval.try(:approval_status)
    status
  end

  def tag_names
    tags.map(&:name)
  end

  def tag_ids
    tags.map(&:id)
  end

  def es_v2_attachments
    attachments.pluck(:content_file_name)
  end

  # _Note_: If these attributes will be delegated in future,
  # no need to do this way
  #
  def meta_referenced_attributes
    {
      art_type: solution_article_meta.art_type,
      position: solution_article_meta.position,
      folder_id: solution_folder_meta.id,
      folder_category_id: solution_folder_meta.solution_category_meta_id,
      folder_visibility: solution_folder_meta.visibility,
      company_ids: solution_folder_meta.customer_folders.pluck(:customer_id),
      contact_filter_ids: solution_folder_meta.folder_visibility_mapping.where(mappable_type: 'ContactFilter').pluck(:mappable_id),
      company_filter_ids: solution_folder_meta.folder_visibility_mapping.where(mappable_type: 'CompanyFilter').pluck(:mappable_id)
    }
  end

  ##########################
  ### V1 Cluster methods ###
  ##########################

  # _Note_: Will be deprecated and remove in near future
  #
  def to_indexed_json
    article_json = as_json(
            :root => "solution/article",
            :tailored_json => true,
            :only => [ :title, :desc_un_html, :user_id, :status,
                  :language_id, :account_id, :created_at, :updated_at ],
            :include => { :tags => { :only => [:name] },
                          :attachments => { :only => [:content_file_name] }
                        }
          )
    article_json["solution/article"].merge!(meta_attributes)
    article_json.to_json
  end

  # Need to verify if it can be handled differently in v2
  #
  def related(current_portal, size = 10)
    search_key = "#{tags.map(&:name).join(' ')} #{title}"
    return [] if search_key.blank? || (search_key = search_key.gsub(/[\^\$]/, '')).blank?
    begin
      if Account.current.launched?(:es_v2_reads)
        related_from_esv2(current_portal, search_key, size)
      else
        @search_lang = ({ :language => current_portal.language }) if current_portal and Account.current.es_multilang_soln?
        Search::EsIndexDefinition.es_cluster(account_id)
        options = { :load => true, :page => 1, :size => size, :preference => :_primary_first }
        item = Tire.search Search::EsIndexDefinition.searchable_aliases([Solution::Article], account_id, @search_lang), options do |search|
          search.query do |query|
            query.filtered do |f|
              f.query { |q| q.string SearchUtil.es_filter_key(search_key), :fields => ['title', 'desc_un_html', 'tags.name'], :analyzer => SearchUtil.analyzer(@search_lang) }
              f.filter :term, { :account_id => account_id }
              f.filter :not, { :ids => { :values => [self.id] } }
              f.filter :term, {:language_id => Language.current.id}
              f.filter :or, { :not => { :exists => { :field => :status } } },
                            { :not => { :term => { :status => Solution::Constants::STATUS_KEYS_BY_TOKEN[:draft] } } }
              f.filter :or, { :not => { :exists => { :field => 'folder.visibility' } } },
                            { :terms => { 'folder.visibility' => user_visibility } }
              f.filter :or, { :not => { :exists => { :field => 'folder.customer_folders.customer_id' } } },
                            { :term => { 'folder.customer_folders.customer_id' => User.current.customer_id } } if User.current && User.current.has_company?
              f.filter :or, { :not => { :exists => { :field => 'folder.category_id' } } },
                           { :terms => { 'folder.category_id' => current_portal.portal_solution_categories.map(&:solution_category_meta_id) } }
            end
          end
          search.from options[:size].to_i * (options[:page].to_i-1)
        end

        return item.results.results.compact
      end
    rescue Exception => e
      NewRelic::Agent.notice_error(e)
      []
    end
  end

  def related_from_esv2(current_portal, search_term, size = 10)
    return [] if search_term.blank?

    searchparams = Hash.new.tap do |es_params|
      es_params[:search_term] = search_term
      es_params[:language_id]         = Language.current.try(:id) || Language.for_current_account.id
      es_params[:article_id]          = self.id
      es_params[:article_status]      = Solution::Constants::STATUS_KEYS_BY_TOKEN[:draft]
      es_params[:article_visibility]  = self.user_visibility
      es_params[:article_company_id]  = User.current.try(:company_ids)
      es_params[:article_category_id] = current_portal.portal_solution_categories.map(&:solution_category_meta_id)

      es_params[:size]                = 10
      es_params[:from]                = 0
    end

    Search::V2::QueryHandler.new({
      account_id:   Account.current.id,
      context:      :portal_related_articles,
      exact_match:  Search::Utils.exact_match?(searchparams[:search_term]),
      es_models:    { 'article' => { model: 'Solution::Article', associations: []}},
      current_page: Search::Utils::DEFAULT_PAGE,
      offset:       0,
      types:        ['article'],
      es_params:    ({
        account_id: Account.current.id,
        request_id: Thread.current[:message_uuid].try(:first) #=> Msg ID is casted as array.
      }).merge(searchparams)
    }).query_results
  end
end