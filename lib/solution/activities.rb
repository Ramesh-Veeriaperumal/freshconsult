module Solution::Activities
  
  def self.included(base)
    base.after_create :add_activity_new
    base.before_destroy :add_activity_delete, :if => :activity_required?
  end

  def class_short_name
    self.class.name.underscore.gsub('solution/','')
  end

  def activity_required?
    !(!Account.current.multilingual? && self.language_id != Language.for_current_account.id)
  end

  def add_activity_delete
    create_activity("delete_#{class_short_name == 'category' ? 'solution_' : ''}#{class_short_name}")
  end

  def add_activity_new
    create_activity("new_#{class_short_name == 'category' ? 'solution_' : ''}#{class_short_name}")
  end

  def create_activity(type)
    path = "solution_#{class_short_name}_path"
    self.activities.create(
      :description => "activities.solutions.#{type}.long",
      :short_descr => "activities.solutions.#{type}.short",
      :account => self.account,
      :user => User.current,
      :activity_data => {
        :path => Rails.application.routes.url_helpers.send("#{path}", self.id),
        :url_params => {
            :id => self.id,
            :path_generator => path
          },
        :title => self.to_s
      }
    )
  end

end