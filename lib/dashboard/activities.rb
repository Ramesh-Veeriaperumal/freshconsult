class Dashboard::Activities < Dashboard

  attr_accessor :user, :page, :per_page

  TOTAL_ENTRIES = 1000
  DEFAULT_PER_PAGE = 5

  def initialize(user = User.current, options = {})
    @user = user
    @page = options[:page]
    @per_page = options[:per_page] || DEFAULT_PER_PAGE
  end

  def fetch_records(options = {})
    recent_activities(options[:activity_id]).paginate(:page => page, :per_page => per_page, :total_entries => TOTAL_ENTRIES)
  end

  protected
    def default_scoper
      Helpdesk::Activity.freshest(Account.current)
    end

    def recent_activities(activity_id)
      if activity_id
        default_scoper.activity_before(activity_id).permissible(user).includes(:notable,{:user => :avatar}) unless activity_id == "0"
      else
        default_scoper.permissible(user).includes(:notable,{:user => :avatar})
      end
    end
end