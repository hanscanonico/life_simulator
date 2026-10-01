# frozen_string_literal: true

require "rails_helper"

RSpec.describe "deploy/docker-compose.yml" do
  let(:compose) { YAML.safe_load(Rails.root.join("deploy/docker-compose.yml").read, aliases: true) }
  let(:services) { compose.fetch("services") }

  # deploy/lib.sh reads this `name:` as the project label the deploy's image prune
  # filters on; without it the prune is skipped.
  it "names its project explicitly" do
    expect(compose["name"]).to eq("life-simulator")
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

  describe "the image prune" do
    let(:prunes) { script.lines.grep(/docker image prune/) }

    # The sibling stacks share the daemon; their dangling images are not ours.
    it "prunes only the images labelled with this compose project" do
      expect(prunes).to be_present.and all(include('--filter "label=com.docker.compose.project=$project"'))
    end

    it "keeps the tagged :previous images by never pruning with -a" do
      expect(prunes).to all(satisfy { |line| !line.match?(/\s(-a|--all)\b/) })
    end

    it "keeps no age window on superseded builds" do
      expect(prunes).to all(satisfy { |line| line.exclude?("until=") })
    end
  end
end
