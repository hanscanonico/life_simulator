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

    trait :stale do
      claimed
      heartbeat_at { 10.minutes.ago }
      epochs_done { 42 }
    end
  end
end
