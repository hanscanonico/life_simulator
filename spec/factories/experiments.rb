# frozen_string_literal: true

FactoryBot.define do
  factory :experiment do
    sequence(:name) { |n| "Sweep #{n}" }
    sequence(:slug) { |n| "sweep-#{n}" }
    description { Faker::Lorem.sentence }
    substrate { "soup" }
    param_grid { { "mutation_rate" => [0.0, 0.001] } }
    seeds { [1, 2] }
    epochs { 1_000 }
    status { "draft" }
  end
end
