module Solution::Activities
  
  def self.included(base)
    base.after_create :add_activity_new
    base.before_update :add_activity_update
    base.before_destroy :add_activity_delete, :if => :activity_required?
  end

  def class_short_name
    self.class.name.underscore.gsub('solution/','')
  end

  def activity_required?
    # Checking if this is the Primary version/translation.
    is_primary? || !Account.current.multilingual?
  end

  def translation_activity?
    Account.current.multilingual? && self.language_id != Language.for_current_account.id
  end

  def article_publish_activity
    self.class.to_s == 'Solution::Article' && ((changes && changes[:title]) || (body.changes && body.changes[:description]))
  end

  def add_activity_delete
    deleted_childs = { folders_count: 0, articles_count: 0 }
    case self.class.to_s
    when 'Solution::Category'
      deleted_childs[:folders_count] = solution_folder_meta.count
      solution_folder_meta.each { |folder_meta| deleted_childs[:articles_count] += folder_meta.solution_article_meta.count }
      create_activity("delete_#{activity_suffix}", deleted_childs)
    when 'Solution::Folder'
      deleted_childs[:articles_count] = solution_folder_meta.solution_article_meta.count
      create_activity("delete_#{activity_suffix}", deleted_childs)
    else
      create_activity("delete_#{activity_suffix}")
    end
  end

  def add_activity_new
    create_activity("new_#{activity_suffix}")
  end

  def add_activity_update
    create_activity('published_article') if article_publish_activity
    create_activity('rename_actions', changes[:name]) if changes[:name]
    if self.class.to_s == 'Solution::Folder'
      create_activity('folder_visibility_update', parent.changes[:visibility]) if parent.changes[:visibility]
      if parent.changes[:solution_category_meta_id]
        changes = []
        changes.push(Account.current.solution_categories.where(parent_id: parent.changes[:solution_category_meta_id][0], language_id: language_id).first.to_s)
        changes.push(Account.current.solution_categories.where(parent_id: parent.changes[:solution_category_meta_id][1], language_id: language_id).first.to_s)
        create_activity('folder_category_update', changes)
      end
    end
  end

  def url_locale
    self.language.code
  end
  
  def activity_suffix
    (class_short_name=='category') && "solution_#{class_short_name}" || class_short_name
  end

  def create_activity(type, additional_params = [])
    path = Rails.application.routes.url_helpers.safe_send("solution_#{class_short_name}_path", self)
    path << "/#{url_locale}" if translation_activity? && class_short_name == 'article'
    self.activities.create(
      :description => "activities.solutions.#{type}.long",
      :short_descr => "activities.solutions.#{type}.short",
      :account => self.account,
      :user => User.current,
      :activity_data => {
        :path => path,
        :url_params => {
          :id => self.id,
          :path_generator => path
        },
        :title => self.to_s,
        'eval_args' => (translation_activity? ? { 'language_name' => ['language_name', url_locale] } : nil),
        solutions_properties: (additional_params.empty? ? nil : additional_params)
      }
    )
  end

end
