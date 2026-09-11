# frozen_string_literal: true

FactoryBot.define do
  factory :rescore do
    run
    sequence(:epoch) { |n| n * 100 }
    top_k { 16 }
    replicator_count { 0 }
    top_share { 0.5 }
    distinct_tapes { 12 }
    compress_ratio { 0.25 }
    entropy_bits { 3.5 }
    measured_at { Time.current }
  end
end
