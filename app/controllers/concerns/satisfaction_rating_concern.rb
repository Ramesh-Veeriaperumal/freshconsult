module Concerns::SatisfactionRatingConcern
  extend ActiveSupport::Concern

  def custom_rating(rating)
    classic_vs_custom = {
      Survey::HAPPY => CustomSurvey::Survey::EXTREMELY_HAPPY,
      Survey::NEUTRAL => CustomSurvey::Survey::NEUTRAL,
      Survey::UNHAPPY => CustomSurvey::Survey::EXTREMELY_UNHAPPY
    }
    rating = classic_vs_custom[rating] if rating < 100 && rating > 0
    rating
  end
end
