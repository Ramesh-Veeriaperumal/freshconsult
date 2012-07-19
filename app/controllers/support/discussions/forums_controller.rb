class Support::Discussions::ForumsController < Support::SupportController
	before_filter :scoper

	def show
		@forum = scoper.find_by_id(params[:id])
		@topics = @forum.topics.paginate(
          							:page => params[:page], 
          							:per_page => 10)
		@category = @forum.forum_category
		@topics_filters = render_to_string :partial => "/support/discussions/forums/filters"
	end

private
	def scoper
	   current_account.portal_forums
	end	
end