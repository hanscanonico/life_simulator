# frozen_string_literal: true

require "rails_helper"

# The deploy job is the only thing that starts the live stack, and nothing else in the
# suite notices when it stops being able to. A cancelled job dies mid `up -d` and leaves
# app and runner in `Created`, which `restart: unless-stopped` never acts on, so the two
# guards below — never cancel, and always sweep afterwards — are the site's uptime.
RSpec.describe ".github/workflows/ci.yml" do
  let(:deploy) { YAML.load_file(Rails.root.join(".github/workflows/ci.yml"), aliases: true).dig("jobs", "deploy") }
  let(:ensure_up) { Rails.root.join("deploy/ensure_up") }

  it "refuses to cancel a deploy in progress" do
    expect(deploy["concurrency"]).to eq("group" => "deploy-life", "cancel-in-progress" => false)
  end

  it "sweeps the stack back up whatever the deploy did" do
    expect(deploy["steps"]).to include(
      a_hash_including("if" => "always()", "run" => a_string_including("deploy/ensure_up"))
    )
  end

  it "ships the sweep as an executable script" do
    expect(ensure_up).to be_executable
  end
end
