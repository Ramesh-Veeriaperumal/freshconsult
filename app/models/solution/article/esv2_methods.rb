class Solution::Article < ActiveRecord::Base

  def to_esv2_json
    as_json({
        root: false,
        tailored_json: true,
        only: [ :title, :desc_un_html, :user_id, :status, :created_at, 
                :updated_at, :thumbs_up, :thumbs_down, :account_id, :modified_at, 
                :hits, :language_id, :modified_by 
              ],
        methods: [ :tag_names, :tag_ids ]
      }).merge(meta_referenced_attributes)
        .merge(attachments: es_v2_attachments).to_json
  end

  def tag_names
    tags.map(&:name)
  end

  def tag_ids
    tags.map(&:id)
  end

  def es_v2_attachments
    attachments.pluck(:content_file_name).collect { |file_name| 
      f_name = file_name.rpartition('.')
      {
        name: f_name.first,
        type: f_name.last
      }
    }
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
      company_ids: solution_folder_meta.customer_folders.map(&:customer_id)
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
      @search_lang = ({ :language => current_portal.language }) if current_portal and Account.current.features_included?(:es_multilang_solutions)
      Search::EsIndexDefinition.es_cluster(account_id)
      options = { :load => true, :page => 1, :size => size, :preference => :_primary_first }
      item = Tire.search Search::EsIndexDefinition.searchable_aliases([Solution::Article], account_id, @search_lang), options do |search|
        search.query do |query|
          query.filtered do |f|
            f.query { |q| q.string SearchUtil.es_filter_key(search_key), :fields => ['title', 'desc_un_html', 'tags.name'], :analyzer => SearchUtil.analyzer(@search_lang) }
            f.filter :term, { :account_id => account_id }
            f.filter :not, { :ids => { :values => [self.id] } }
            f.filter :or, { :not => { :exists => { :field => :status } } },
                          { :not => { :term => { :status => Solution::Constants::STATUS_KEYS_BY_TOKEN[:draft] } } }
            f.filter :or, { :not => { :exists => { :field => 'folder.visibility' } } },
                          { :terms => { 'folder.visibility' => user_visibility } }
            f.filter :or, { :not => { :exists => { :field => 'folder.customer_folders.customer_id' } } },
                          { :term => { 'folder.customer_folders.customer_id' => User.current.customer_id } } if User.current && User.current.has_company?
            f.filter :or, { :not => { :exists => { :field => 'folder.category_id' } } },
                         { :terms => { 'folder.category_id' => current_portal.portal_solution_categories.map(&:solution_category_id) } }
          end
        end
        search.from options[:size].to_i * (options[:page].to_i-1)
      end

      item.results.results.compact
    rescue Exception => e
      NewRelic::Agent.notice_error(e)
      []
    end
  end
end