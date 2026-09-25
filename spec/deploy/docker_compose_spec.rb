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

    # A provenance attestation changes the image index digest on every build, which is
    # the image ID under the containerd store, so compose would recreate the runner on
    # an app-only deploy (#173).
    it "leaves out the provenance attestation, so identical layers keep the image ID" do
      expect(services.slice("app", "runner").values.map { |service| service.dig("build", "provenance") })
        .to eq([false, false])
    end

    it "builds the runner from its own stage" do
      expect(services.dig("runner", "build", "target")).to eq("runner")
    end
  end
end
