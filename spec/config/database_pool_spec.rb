# frozen_string_literal: true

require "rails_helper"

# Solid Queue runs inside Puma on the deployed stack (DESIGN 4), so its worker and a Puma
# worker read the same pool configuration, and the app service sets RAILS_MAX_THREADS for
# the Puma side. A pool below the worker's need starves job threads instead of failing
# loudly, which nothing else in the suite would notice.
RSpec.describe "config/database.yml" do
  let(:compose) { YAML.load_file(Rails.root.join("deploy/docker-compose.yml"), aliases: true) }
  let(:deployed_threads) { compose.dig("services", "app", "environment", "RAILS_MAX_THREADS") }

  let(:queue_worker_connections) do
    queue = YAML.safe_load(ERB.new(Rails.root.join("config/queue.yml").read).result, aliases: true)
    queue.dig("production", "workers", 0, "threads") + 2
  end

  def production_pool(name, threads:)
    previous = ENV.fetch("RAILS_MAX_THREADS", nil)
    ENV["RAILS_MAX_THREADS"] = threads
    Rails.application.config.database_configuration.dig("production", name, "max_connections").to_i
  ensure
    previous.nil? ? ENV.delete("RAILS_MAX_THREADS") : ENV["RAILS_MAX_THREADS"] = previous
  end

  it "gives the queue pool the connections Solid Queue's worker needs" do
    expect(production_pool("queue", threads: deployed_threads)).to be >= queue_worker_connections
  end

  it "sizes the primary pool for the request threads of one Puma worker" do
    expect(production_pool("primary", threads: deployed_threads)).to eq(deployed_threads.to_i)
  end
end
