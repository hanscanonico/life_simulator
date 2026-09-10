# frozen_string_literal: true

FactoryBot.define do
  factory :sample do
    run
    sequence(:epoch) { |n| n * 100 }
    values { { "compress_ratio" => 0.98, "distinct_tapes" => 16_384 } }
  end
end
