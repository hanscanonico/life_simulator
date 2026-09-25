# frozen_string_literal: true

require "rails_helper"

RSpec.describe "deploy/docker-compose.yml" do
  let(:services) do
    YAML.safe_load(Rails.root.join("deploy/docker-compose.yml").read, aliases: true).fetch("services")
  end

  describe "the images the stack builds" do
    it "builds the app and the runner from the Dockerfile" do
      built = services.select { |_name, service| service.key?("build") }.keys

      expect(built).to contain_exactly("app", "runner")
    end

    # A `provenance:` key would stop Compose's built-in builder from reading
    # BUILDX_NO_DEFAULT_ATTESTATIONS, and in Compose 2.40.3 the key itself is misread
    # as a request for provenance (docker/compose#14111).
    it "sets no provenance key on either build" do
      expect(services.slice("app", "runner").values.map { |service| service.fetch("build").key?("provenance") })
        .to eq([false, false])
    end

    it "builds the runner from its own stage" do
      expect(services.dig("runner", "build", "target")).to eq("runner")
    end
  end
end

RSpec.describe "deploy/deploy" do
  let(:script) { Rails.root.join("deploy/deploy").read }

  # Without it the provenance attestation gives the runner a new image ID on every
  # build, and compose recreates the container on an app-only deploy (#173).
  it "builds both images without the default attestations" do
    expect(script).to match(/^BUILDX_NO_DEFAULT_ATTESTATIONS=1 \$compose build app runner$/)
  end

  it "has no build step that could omit the variable" do
    expect(script.scan("$compose build").size).to eq(1)
  end
end
