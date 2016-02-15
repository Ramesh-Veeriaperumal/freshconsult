class Dashboard::Widget

	attr_accessor :name, :width, :height, :x, :y

	def initialize(name, width, height)
		@name = name
		@width = width
		@height = height
		@x = 0
		@y = 0
	end

	def x2
		@x + @width
	end

	def y2
		@y + @height
	end

	def increment_x_by pos
		@x += pos	
	end

	def increment_y_by pos
		@y += pos
	end
	
	def hit(widget)
    	((self.x < widget.x2) &&
      		(self.x2 > widget.x) &&
      		(self.y < widget.y2) &&
      		(self.y2 > widget.y))
	end

end