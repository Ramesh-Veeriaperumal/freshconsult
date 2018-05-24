module SandboxConstants
  STATUSES = [
    [:enqueued, 1],
    [:create_sandbox, 2],
    [:account_complete, 3],
    [:sync_from_prod, 4],
    [:provision_staging, 5],
    [:sandbox_complete, 6],
    [:destroy_sandbox, 7],
    [:error, 99]
  ].freeze

  PROGRESS_STATUS = [
    [[1, 2, 3, 4, 5], :build_in_progress],
    [[6], :build_complete],
    [[7], :destroy_sandbox],
    [[99], :error]
  ].freeze

  PROGRESS_KEYS_BY_TOKEN = Hash[*PROGRESS_STATUS.map { |i| i[0].map { |j| [j, i[1]] } }.flatten].freeze

  STATUS_KEYS_BY_TOKEN = Hash[*STATUSES.map { |i| [i[0], i[1]] }.flatten].freeze
  STATUS_TOKEN_BY_KEYS = Hash[*STATUSES.map { |i| [i[1], i[0]] }.flatten].freeze
end.freeze
