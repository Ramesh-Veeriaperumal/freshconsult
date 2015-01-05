class Workers::Community::CheckForSpam
  extend Resque::AroundPerform

	include ActionController::UrlWriter

  @queue = 'check_for_spam'

  EMAIL_PATTERN = /(\A.*[-A-Z0-9.'_&%=+]+@(?:[A-Z0-9\-]+\.)+(?:[A-Z]{2,15}).*\z)/i
  NUMBER_PATTERN = /((\+\d{1,3}(-| )?\(?\d\)?(-| )?\d{1,5})|(\(?\d{2,6}\)?))(-| )?([A-Z,0-9]{2,4})(-| )?([A-Z,0-9]{3,4})(-| )?(( x| ext)(-| )?\d{1,5}){0,1}/

  APPROVED_DOMAINS = YAML::load_file(File.join(Rails.root, 'config', 'whitelisted_link_domains.yml'))

  class << self

    include ModerationUtil
    
	  def perform(params)
	  	params.symbolize_keys!
	  	post = build_post(params[:id])
	  	process(post, params[:request_params])
	  	SpamAnalysis.push(post, {:request_params => params[:request_params]})
	  end

	  private

  	def build_post(post_id)
  		Account.current.posts.find(post_id)
  	end

  	def process(post, request_params)
  		post.spam = is_spam?(post, request_params)
  		post.published = !post.spam? && !to_be_moderated?(post)
  		post.save
  	end
	end
end
