module TabHelper
	class TabsRenderer

		def initialize( options={}, &block )
			raise ArgumentError, "Missing block" unless block_given?
			@template = eval( 'self', block.binding )
			@options = options
			@tabs = []
			yield self
		end
		# Use this function if you have static data
		def create( tab_id, tab_text, options={}, &block )
			raise "Block needed for TabsRenderer#CREATE" unless block_given?
			@tabs << [ tab_id, tab_text, options, block, {:ajax => false} ]
		end
		#  Use this funtion if you want to load dynamic data from ajax
		def create_ajax( tab_id, link, tab_text, options={})
			@tabs << [ link, tab_text, options, nil, {:ajax => true}, tab_id ]
		end

		def render
		    content_tag :div, raw([render_tabs, render_bodies].join), { :class => :tabs }.merge( @options )
		end

	private #	 ---------------------------------------------------------------------------

		def render_tabs
			content_tag :ul, :class => 'tabs nav-tabs' do
				result = @tabs.each_with_index.collect do |tab, index|
					if tab[4][:ajax]
						classes = [("active" unless index != 0)]
						content_tag( :li, link_to( raw(tab[1]), "#{tab[5]}",  :data => { :toggle => 'tab',:ajax => true,  :url => "#{tab[0]}"}), :class => classes )
					else
						classes = [("active" unless index != 0)]
						content_tag( :li, link_to( raw(tab[1]), "##{tab[0]}",  :data => { :toggle => 'tab'} ), :class => classes )
					end
				end.join
				raw(result)
			end
		end

		def render_bodies
			content_tag :div, :class => 'tab-content' do
				results = @tabs.each_with_index.collect do |tab, index|
					if tab[4][:ajax]
						classes = ["tab-pane", ("active" unless index != 0)]
						content_tag( :div, '', :id => "#{tab[5]}", :class => classes)
					else
						classes = ["tab-pane", ("active" unless index != 0)]
						content_tag( :div, tab[2].merge( :id => tab[0], :class => classes ), & tab[3])
					end
				end.join
				raw(results)
			end
		end

		def method_missing( *args, &block )
			@template.send( *args, &block )
		end

	end
end