# frozen_string_literal: true

require "rails_helper"

# Nothing boots the recurring schedule outside production, so a job renamed here would only
# surface as a Solid Queue error on the mini-pc. These examples pin the names instead.
RSpec.describe "The recurring schedule" do
  subject(:tasks) { YAML.load_file(Rails.root.join("config/recurring.yml")).fetch("production") }

  it "schedules the unattended work the lab depends on" do
    expect(tasks.keys).to include("release_stale_runs", "prune_snapshots")
  end

  it "names a job class that exists for every task that declares one" do
    tasks.each_value do |task|
      next unless task["class"]

      expect { task["class"].constantize }.not_to raise_error
    end
  end

  it "names a receiver that exists for every task that declares a command" do
    tasks.each_value do |task|
      next unless task["command"]

      receiver = task["command"][/\A([A-Z][\w:]*)/, 1]
      expect(receiver).to be_present
      expect { receiver.constantize }.not_to raise_error
    end
  end

  it "gives every task a schedule" do
    expect(tasks.values.pluck("schedule")).to all(be_present)
  end
end
