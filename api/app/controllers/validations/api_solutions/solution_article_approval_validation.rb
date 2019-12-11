class ApiSolutions::SolutionArticleApprovalValidation < ApiValidation
  attr_accessor :approver_id
  validates :approver_id, data_type: { rules: Integer }, on: :send_for_review
end
