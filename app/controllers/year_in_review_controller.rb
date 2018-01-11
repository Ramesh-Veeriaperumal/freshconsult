class YearInReviewController < ApplicationController

  include YearInReviewMethods

  before_filter :check_feature

  def share
    share_video
    render_resp
  end

  def clear
    clear_review_box
    render_resp
  end

  private

    def check_feature
      return if Account.current.year_in_review_2017_enabled?
      respond_to do |format|
        format.json { render :json => { failure: true, errors: ["Feature Unavailable"] }.to_json }
      end
    end

    def render_resp
      respond_to do |format|
        format.json { render :json => { success: true }.to_json }
      end
    end
end
