module SandboxConstants
  STATUSES = [
    [:enqueued, 1],
    [:create_sandbox, 2],
    [:account_complete, 3],
    [:sync_from_prod, 4],
    [:provision_staging, 5],
    [:sandbox_complete, 6],
    [:destroy_sandbox, 7],
    [:diff_in_progress,  8],
    [:diff_complete,     9],
    [:merge_in_progress, 10],
    [:merge_complete,    11],
    [:error, 98],
    [:build_error, 99],
    [:clone_initiated, 101],
    [:clone_backup_staging, 102],
    [:clone_sync_from_prod, 103],
    [:clone_provision_staging, 104],
    [:clone_complete, 105],
    [:clone_error, 199]
  ].freeze

  PROGRESS_STATUS = [
    [[1, 2, 3, 4, 5], :build_in_progress],
    [[6],             :build_complete],
    [[7],             :destroy_sandbox],
    [[98],            :error],
    [[99],            :build_error],
    [[8],             :diff_in_progress],
    [[9],             :diff_complete],
    [[10],            :merge_in_progress],
    [[11],            :merge_complete],
    [[101, 102, 103, 104], :clone_in_progress],
    [[105],           :clone_complete],
    [[199],           :clone_error]
  ].freeze

  PROGRESS_KEYS_BY_TOKEN = Hash[*PROGRESS_STATUS.map { |i| i[0].map { |j| [j, i[1]] } }.flatten].freeze

  STATUS_KEYS_BY_TOKEN = Hash[*STATUSES.map { |i| [i[0], i[1]] }.flatten].freeze
  STATUS_TOKEN_BY_KEYS = Hash[*STATUSES.map { |i| [i[1], i[0]] }.flatten].freeze

  MERGE_FIELDS = %w(sandbox meta).freeze

  SANDBOX_NOTIFICATION_STATUS = [6, 8, 9, 10, 98].freeze
end.freeze
