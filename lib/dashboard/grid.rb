class Dashboard::Grid

  def initialize(size = 3)
    @max_columns = size
    @widgets = []
  end

  def process_widgets(dashboard_widget, snapshot)
    @max_columns = (snapshot == 'standard') ? 3 : 6
    dashboard_widget.each_with_index.map do |widget, i|
      _widget = Dashboard::Widget.new(widget[1], widget[2], widget[3])
      @widgets.push calculate_position(_widget)
    end    
    calculateActivityHeight if snapshot == 'standard'    
    @widgets
  end

  private

  def canFit(widget)
    _canFit = true
    @widgets.each do |_widget|
      _canFit = !widget.hit(_widget)
      break if(_canFit === false)
    end
    return _canFit
  end

  def calculate_position(widget)
    if(!canFit(widget))
      widget = increment_position(widget)
      calculate_position(widget)
    end
    widget
  end

  def increment_position(widget)
    widget.increment_x_by(1)
    if(@max_columns < widget.x2)
      widget.x = 0
      widget.increment_y_by(1)
    end
    widget
  end

  def calculateActivityHeight
    # This sets the height of "recent helpdesk activities"
    # according to the widgets available
    exceptActivity = @widgets.reject { |n| n.name == 'activity' }
    activityHeight = exceptActivity.length > 3 ? exceptActivity.length : 3
    @widgets.map! { |w| 
      w.height = activityHeight if w.name == 'activity' 
      w
    }
  end

end