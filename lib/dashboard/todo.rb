class Dashboard::Todo < Dashboard
  attr_accessor :tasks

  def initialize
  end

  def fetch_records
    default_scoper.reminders
  end

  protected

    def default_scoper
      User.current
    end
end