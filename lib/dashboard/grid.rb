class Dashboard::Grid

  def initialize(size = 3)
    @max_columns = size
    @widgets = []
  end

  def process_widgets(dashboard_widget, privilege, dashboard_type)    
    dashboard_widget.each_with_index.map do |widget, i|
      if (privilege[widget[0]])
        _widget = Dashboard::Widget.new(widget[0], widget[1], widget[2])
        @widgets.push calculate_position(_widget)
      end 
    end
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

end