class Bot < ActiveRecord::Base
  include RepresentationHelper

  acts_as_api

  api_accessible :ml_training_start do |b|
    b.add :external_id
    b.add :solution_category_metum_ids, as: :category_ids
    b.add :account_id
  end

  api_accessible :ml_training_end do |b|
    b.add :external_id
    b.add :solution_category_metum_ids, as: :category_ids
    b.add :account_id
    b.add :training_completed
  end

  def payload_template_mapping
    {
      ml_training_start: :ml_training_start,
      ml_training_end: :ml_training_end
    }.with_indifferent_access
  end
end
