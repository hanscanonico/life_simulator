# frozen_string_literal: true

FactoryBot.define do
  factory :snapshot_reading do
    run
    instrument { "oriented_census/1" }
    sequence(:epoch) { |n| (n * 100) + 5 }
    source_epoch { epoch - 5 }
    values { { "replicator_share" => 0.0, "reverse_copy_rate" => 0.25 } }
    measured_at { Time.current }
  end
end
