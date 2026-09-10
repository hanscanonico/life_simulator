# frozen_string_literal: true

require "rails_helper"

RSpec.describe Experiment, type: :model do
  subject(:experiment) { build(:experiment) }

  it { is_expected.to have_many(:runs).dependent(:destroy) }
  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_presence_of(:substrate) }
  it { is_expected.to define_enum_for(:status).backed_by_column_of_type(:string).with_values(Experiment::STATUSES.index_by(&:itself)) }

  it "rejects a duplicate name" do
    create(:experiment, name: "Mutation rate", slug: "mutation-rate")

    expect(build(:experiment, name: "Mutation rate")).not_to be_valid
  end

  it "rejects a duplicate slug" do
    create(:experiment, slug: "mutation-rate")

    expect(build(:experiment, slug: "mutation-rate")).not_to be_valid
  end

  it "rejects a slug that is not kebab-case" do
    expect(build(:experiment, slug: "Mutation Rate")).not_to be_valid
  end

  it "is identified by its slug in urls" do
    expect(build(:experiment, slug: "mutation-rate").to_param).to eq("mutation-rate")
  end

  it "counts its runs" do
    experiment.save!
    create_list(:run, 2, experiment: experiment)

    expect(experiment.reload.runs_count).to eq(2)
  end
end
