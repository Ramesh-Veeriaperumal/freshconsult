module DiscussionsHelper
	include Helpdesk::TicketsHelperMethods
	include Community::MonitorshipHelper

	def discussions_breadcrumb(page = :home)
		_output = []
		_output << pjax_link_to(t('discussions.all_categories'), categories_discussions_path)
		case page
			when :category
				_output << h(truncate(@forum_category.name, :length => 120))
			when :forum
				_output << category_link(@forum, page)
				_output << h(truncate(@forum.name, :length => 50))
			when :topic
				_output << category_link(@forum, page)
				_output << forum_link(@forum)
			else
		end
		"<div class='breadcrumb'>#{_output.map{ |bc| "<li>#{bc}</li>" }.join("")}</div>".html_safe
	end

	def forum_link forum
		options = { :title => forum.name } if forum.name.length > 40
		pjax_link_to(truncate(forum.name, :length => 40), discussions_forum_path(forum.id), (options || {}))
	end

	def category_link(forum, page)
		truncate_length = ( (page == :forum) ? 70 : 40 )
		forum_category_name = forum.forum_category.name 
		options = { :title => forum_category_name } if forum_category_name.length > truncate_length
		pjax_link_to(truncate(forum.forum_category.name, :length => truncate_length), 
			 			"/discussions/#{forum.forum_category_id}", (options || {}))
	end

	def more_user_avatar(count, href, options={})
		return "" if count <=0
		options[:class] = "#{options[:class]} more-users-link"
		link_to "...", href, options
	end

	def forum_category_list
		op = []
		current_account.forum_categories_from_cache.each do |category|
			forums = category.forums
			op << %(<li class="cm-sb-cat-item">)
			op << %(<i class="forum_expand"></i>) unless forums.blank?
			op << pjax_link_to(category.name, discussion_path(category), {
									:"data-category-id" => category.id,
									:id => "sb-discussions-category-#{category.id}"
								})
			op << forum_list(forums, category.id)
			op << %(</li>)
		end
		op.join('').html_safe
	end

	def forum_list forums, category_id
		op = []
		op << %( <ul class="forum_list" id="#{category_id}_forums"> )
		forums.each do |forum|
			op << %( <li class="forum_list_item" id="#{forum.id}_forum"> )
			op << pjax_link_to( "#{forum.name} (#{forum.topics_count})",
													discussions_forum_path(forum), {
														:"data-forum-id" => forum.id,
														:"data-category-id" => category_id,
														:id => "sb-discussions-forum-#{forum.id}"
												})
			op << %( </li> )
		end
		op << %( </ul> )
		op.join('').html_safe
	end

	def sidebar_toggle(extra_classes="")
		font_icon("sidebar-list",
								:size => 21,
								:class => "cm-sb-toggle #{extra_classes}",
								:id => "cm-sb-toggle").html_safe
	end

	def moderation_count(counts)
		return moderation_link(:unpublished, counts[:unpublished]) if counts[:unpublished] > 0
		return moderation_link(:spam, counts[:spam]) if counts[:spam] > 0
		""
	end

	def moderation_link(type, count)
		pjax_link_to t("discussions.unpublished.index.#{type}") + " (#{count}) ", discussions_unpublished_filter_path(type), :class => 'mini-link mr20'
	end

	def moderation_enabled?
		current_account.features?(:moderate_all_posts) || current_account.features?(:moderate_posts_with_links)
	end

	def list_discussions_panel(default_btn = :topic)
	  _op = ""
	  _op << %(<ul class="list-actions-right">
		           <li class="list-default-btns">)

		_op << %(<a href="#" class="btn" id="categories_reorder_btn">
	             #{font_icon "reorder", :size => 13}
	             #{t('topic.reorder')}
					   </a>) if privilege?(:manage_forums)

		_op << new_discussions_button(default_btn)
	  _op << %(</li>
	           <li class="list-reorder-btns">
	             <a href="#" class="btn btn-primary" id="categories_submit_btn">Done</a>
	             <a href="#" class="btn btn-link" id="categories_cancel_btn">cancel</a>
	           </li>
	          </ul>)
	  _op.html_safe
	end

	def new_discussions_button(default_btn = :topic)
	  category = [t('topic.add_category'), new_discussion_path]
	  forum    = [t('topic.add_forum'),    new_discussions_forum_path(btn_default_params(:forum))]
	  topic    = [t("topic.add_topic"),    new_discussions_topic_path(btn_default_params(:topic))]
	  opts     = {:"data-pjax" => "#body-container"}

	  if privilege?(:manage_forums)
	    topic = nil unless privilege?(:create_topic)
	    case default_btn
	      when :category
	        btn_dropdown_menu(category, [forum, topic], opts)
	      when :forum
	        btn_dropdown_menu(forum, [category, topic], opts)
	      else
	        if privilege?(:create_topic)
	        	btn_dropdown_menu(topic, [category, forum], opts)
	        else
	        	btn_dropdown_menu(forum, [category], opts)
	        end
	    end
	  elsif privilege?(:create_topic)
	    pjax_link_to(topic[0], topic[1], :class => 'btn')
		else
			""
	  end
	end

	def btn_default_params(type)
	  case type
	    when :forum
	      { :forum_category_id => @forum_category.id } if @forum_category.present?
	    when :topic
	      { :forum_id => @forum.id } if @forum.present?
	    else
	  end
	end

  # Topic page
	def topic_sort
	  %(<div class="dropdown" id="topic-sort-menu">
	      <a href="#" class="dropdown-toggle" id="sorted_by" data-toggle="dropdown">
	        #{ t('topic.sorted_by') } :
	        <strong> #{ t("topic.#{params[:order].to_s}") }</strong>
	        <span class="caret"></span>
	      </a>
	      #{ topic_sort_dropdown }
	    </div>).html_safe
	end

	def topic_sort_dropdown
	  sort_items = ["recent", "popular"].map {|s|
	                  [t("topic.#{s}"), "#", params[:order].eql?(s), { :"data-value" => s, :id => "#{s}-sort", :rel => "topic-sort-item" }] }

	  dropdown_menu(sort_items)
	end

	def merged_list topic
		list = "<ul id='merge-topics-list'>"
		topic.merged_topics.each do |merged|
			list << "<li>" + pjax_link_to(merged.title, discussions_topic_path(merged)) + "</li>"
		end
		list << "</ul>"
		list.html_safe
	end

  def display_widget_topic_icons(topic)
    output = ""
  	output << %(<div class='list-space'>#{font_icon('lock-2', :class => 'widget-icon-list').html_safe}
  						#{t('portal.topic.locked')}</div>) if topic.locked?
  	output << %(<div class='list-space'>#{font_icon('merge', :class => 'widget-icon-list').html_safe}
  						#{t('portal.topic.merge')}<br>
  						#{pjax_link_to(truncate(topic.merged_into.title, { :length => 27 }), discussions_topic_path(topic.merged_into), :class => 'indent-topic-merge-link', :title => topic.merged_into.title)}</div>) if topic.merged_topic_id?
  	output << %(<div>#{font_icon('pushpin', :class => 'widget-icon-list').html_safe}
  						#{t('portal.topic.sticky')}</div>) if topic.sticky?
    output.html_safe
  end

	def pageless_dynamo(url)
		_output = []
		_output << %(<div id="dynamo-next-page">)
		_output << 	link_to_remote(
										t('discussions.show_more'), 
										:url => url,
										:method => :get,
										:html => {
										:onclick => "jQuery(this).hide(); jQuery(this).parent().addClass('sloading loading-small')"
										})
		_output << %(</div>)
		_output.join('').html_safe
	end

	def spam_modal_header(topic, type)
		op = "<div class='modal-header'>"
		op << heading(topic, type)
		op << "</div>"
		op
	end

	def heading(topic, type)
		op = "<div id='modal-heading-#{type}'><h3 class='ellipsis'>"
		op << t("discussions.unpublished.index.#{type}")
		op << " (#{topic.send("#{type}_count")})" if topic.send("#{type}_count") > 0
		op << "</h3>"
		op << empty_link(topic.id) if topic.send("#{type}_count") > 1 && type.eql?('spam')
		op << "</div>"
		op
	end

	def empty_link(topic_id)
		op = "<span class='empty-trash'>"
		op << link_to(t('discussions.unpublished.empty_spam'), empty_topic_spam_discussions_unpublished_path(topic_id), :method => :delete)
		op << "</span>"
		op
	end

	def shorten(text, opts = {})
		opts = shorten_defaults.merge!(opts)
		op = [ h(text.first(opts[:length])) ]
		op << shorten_links(opts, text) if text.length > opts[:length]
		op.join('').html_safe
	end

	def shorten_defaults
		{
			:length => 200,
			:more => t('discussions.unpublished.more'),
			:less => t('discussions.unpublished.less')
		}
	end

	def shorten_links(opts, text)
		op = []
		op << %(<a href class='more-link'>#{opts[:more]}</a>)
		op << %(<span class='hide more'>)
		op << h(text[opts[:length]..-1])
		op << link_to(opts[:less], '', :class => 'less-link')
		op << %(</span>)
		op
	end

  def display_topic_icons(topic)
		output = ""
  	output << content_tag(:span, font_icon('lock-2', :class => 'widget-icon-list').html_safe, {
  			:class => 'tooltip ml4',
  			:title => t('discussions.topics.locked')
		}).html_safe if topic.locked?
  	
  	output << content_tag(:span, font_icon('merge', :class => 'widget-icon-list').html_safe, {
  			:class => 'tooltip ml4',
  			:title => t('discussions.topics.merged')
		}).html_safe if topic.merged_topic_id?
  	
  	output << content_tag(:span, font_icon('pushpin', :class => 'widget-icon-list').html_safe, {
  			:class => 'tooltip ml4',
  			:title => t('discussions.topics.sticky')
		}).html_safe if topic.sticky?
    output.html_safe
  end

  def unpublished_post_body(post, truncate_length, shorten_length)
  	post_body = post.body
  	if post_body.strip.blank?
  		post.body_html.html_safe
  	else
  		shorten( truncate( post_body, :length => truncate_length ), :length => shorten_length)
  	end
  end

  def display_count(count)
  	"(#{count})" if count > 0
  end
  
  def populate_vote_list_content object
    return "" unless User.current.present?
    output = object.voters.all(:limit => 5).collect(&:name).map do |name|
    					h(name.size > 20 ? name.truncate(20) : name)
    				 end
    output << "..." if object.user_votes > 5
    output.join("<br>").html_safe
  end

  def attachment_view(attached, page)
	output = ""
	output << %(<li class="attachment list_element" id="#{ dom_id(attached) }">)
	output << %(<div>)
	output << %(<span>)
	output << link_to("",'javascript:void(0)',:class => "delete remove-attachment mr10 #{ page }", :id =>"#{attached.id.to_s}")
	output << %(</span>)
	scoper = page == "cloud_file" ? "cloud_file_attachments" : "ticket_attachments"
	output <<  %(<input type="hidden" name="post[#{scoper}][][resource]" 
	  	        value="#{attached.id}" rel="original_attachment"/>)
  	output << attached_icon(attached, page)
  	output << %(<div class="attach_content">)

	if(page == "cloud_file")
		filename = attached.filename || URI.unescape(attached.url.split('/')[-1])
		tooltip = filename.size > 15 ? "tooltip" : ""
		output << link_to( h(filename.truncate(15)), attached.url , :target => "_blank",
	                       :title => h(filename), :class => "#{tooltip}")
		output << %(<span class="file-size cloud-file"></span>)
	else
		size = number_to_human_size attached.content_file_size
		tooltip = attached.content_file_name.size > 15 ? "tooltip" : "" 
		output << content_tag( :div,link_to(h(attached.content_file_name.truncate(15)), attached, :target => "_blank", 
	                          :title => h(attached.content_file_name), :class => "#{tooltip}"),
	                          :class => "ellipsis")
	    output << %(<span class="file-size">( #{size} )</span>)
	end

	output << %(</div>)
	output << %(</div>)
	output << %(</li>)
	output.html_safe
  end
end
