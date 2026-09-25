# frozen_string_literal: true

FactoryBot.define do
  factory :run do
    experiment
    params { Lab::Schema.run_defaults }
    sequence(:seed) { |n| n }
    epochs { 1_000 }
    status { "pending" }

    trait :claimed do
      status { "claimed" }
      runner_id { "runner-1" }
      claimed_at { Time.current }
      heartbeat_at { Time.current }
    end

    trait :just_failed do
      status { "failed" }
      finished_at { 1.hour.ago }
      error { "runner exited with status 101" }
    end

    # A run whose crossing a witness confirmed: what the open-endedness findings read.
    trait :emerged do
      status { "finished" }
      transition_epoch { 100 }
      emergence_epoch { transition_epoch }
      emergence_witness { Runs::Emergence::CENSUS }
    end

    # A run started from an emerged parent's stored world at its last epoch, carrying the
    # parent's emergence as Run.descend_from would.
    trait :descendant do
      parent_run { association :run, :emerged, epochs: 1_000, params: params }
      parent_epoch { 1_000 }
      epochs { parent_epoch + 1_000 }
      epochs_done { parent_epoch }
      emergence_epoch { parent_run.emergence_epoch }
      emergence_witness { parent_run.emergence_witness }

      before(:create) do |run|
        run.parent_run.snapshots.find_or_create_by!(epoch: run.parent_epoch) { |snapshot| snapshot.blob = "world" }
      end
    end

    trait :stale do
      claimed
      heartbeat_at { 10.minutes.ago }
      epochs_done { 42 }
    end
  end
end
