class Discussions::MergeTopicController < ApplicationController

	helper TopicMergeHelper
	include Redis::RedisKeys
	include Redis::OthersRedis
	
	before_filter :load_topics

	def select
		@redirect_back = params[:redirect_back]
		render :layout => false
	end

	def review
	end

	def confirm
		handle_merge
		flash[:notice] = t("discussions.topic_merge.target_note_description", 
										:count => @source_topics.length, 
										:target_topic_title => @target_topic.title, 
										:source_topics => @source_topics.map(&:title).to_sentence)
		redirect_to ( params[:redirect_back].eql?("true") ? :back : discussions_topic_path(@target_topic.id) )
	end

	protected

		def load_topics
			@source_topics = current_account.topics.where(id: params[:source_topics]).order('created_at DESC').to_a
			@target_topic = current_account.topics.find(params[:target_topic_id]) if params[:target_topic_id]
		end

		def handle_merge
		  @source_topics.each do |source_topic|
		    source_topic.update_attributes(:locked => 1, :merged_topic_id => @target_topic.id)
		  end
		  args = { :source_topic_ids => @source_topics.map(&:id), 
				   :target_topic_id => @target_topic.id, 
				   :source_note => params[:source_note] }
		  Community::MergeTopicsWorker.perform_async(args)
		end
end