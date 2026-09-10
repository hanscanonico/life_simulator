# frozen_string_literal: true

FactoryBot.define do
  factory :snapshot do
    run
    sequence(:epoch) { |n| n * 100 }
    blob { "world-bytes" }
    png { "png-bytes" }
  end
end
