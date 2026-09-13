# frozen_string_literal: true

require "rails_helper"

PageMetadata = Data.define(:title, :description)

RSpec.describe "Page metadata", type: :request do
  let(:experiment) { create(:experiment, name: "Mutation rate", description: "Does mutation buy emergence?") }
  let(:run) { create(:run, experiment: experiment, seed: 7, status: "finished", epochs_done: 1_000) }
  let(:finding) { Findings::Registry.all.first }

  def metadata_of(path)
    get path
    document = response.parsed_body

    PageMetadata.new(title: document.css("title").text,
                     description: document.css("meta[name=description]").attribute("content").value)
  end

  describe "the public pages" do
    it "gives each of them a title and a description no other page uses" do
      pages = [root_path, how_it_works_path, experiments_path, experiment_path(experiment),
               findings_path, finding_path(finding), run_path(run), lab_path]

      metadata = pages.map { |path| metadata_of(path) }

      expect(metadata.map(&:title).uniq.size).to eq(pages.size)
      expect(metadata.map(&:description).uniq.size).to eq(pages.size)
      expect(metadata.flat_map { |page| [page.title, page.description] }).to all(be_present)
    end

    it "states the hand-written ones in full" do
      pages = [root_path, how_it_works_path, experiments_path, findings_path, lab_path]

      descriptions = pages.map { |path| metadata_of(path).description }

      expect(descriptions).to all(end_with("."))
      expect(descriptions).not_to include(a_string_ending_with("..."))
    end
  end

  describe "GET /" do
    it "names the site and its subject" do
      metadata = metadata_of(root_path)

      expect(metadata.title).to eq("Watching self-replicators emerge on their own — Life Simulator")
      expect(metadata.description).to include("soup of programs")
    end
  end

  describe "GET /experiments" do
    it "describes the index of sweeps" do
      metadata = metadata_of(experiments_path)

      expect(metadata.title).to eq("Experiments — Life Simulator")
      expect(metadata.description).to include("sweep")
    end
  end

  describe "GET /experiments/:id" do
    it "describes the sweep from its own record" do
      metadata = metadata_of(experiment_path(experiment))

      expect(metadata.title).to eq("Mutation rate — Life Simulator")
      expect(metadata.description).to eq("Does mutation buy emergence?")
    end

    it "truncates a description longer than a search result shows" do
      experiment.update!(description: "Mutation. #{'word ' * 100}")

      metadata = metadata_of(experiment_path(experiment))

      expect(metadata.description.length).to be <= 155
      expect(metadata.description).to start_with("Mutation.")
      expect(metadata.description).to end_with("...")
    end

    it "escapes a description the record spells with markup characters" do
      experiment.update!(description: %(Radius 1 & "well-mixed" <arms>))

      get experiment_path(experiment)

      expect(response.body).to include(%(content="Radius 1 &amp; &quot;well-mixed&quot; &lt;arms&gt;"))
      expect(response.parsed_body.css("meta[name=description]").attribute("content").value)
        .to eq(%(Radius 1 & "well-mixed" <arms>))
    end
  end

  describe "GET /findings" do
    it "describes the index of write-ups" do
      metadata = metadata_of(findings_path)

      expect(metadata.title).to eq("Findings — Life Simulator")
      expect(metadata.description).to include("write-up")
    end
  end

  describe "GET /findings/:id" do
    it "describes the finding from its own summary" do
      metadata = metadata_of(finding_path(finding))

      expect(metadata.title).to eq("#{finding.title} — Life Simulator")
      expect(metadata.description).to eq(finding.summary.squish.truncate(155))
    end
  end

  describe "GET /runs/:id" do
    it "describes the run from its own record" do
      metadata = metadata_of(run_path(run))

      expect(metadata.title).to eq("Run ##{run.id} — Life Simulator")
      expect(metadata.description).to include("Mutation rate sweep", "seed 7", "finished")
    end
  end

  describe "GET /lab" do
    it "describes the runners' page" do
      metadata = metadata_of(lab_path)

      expect(metadata.title).to eq("Lab — Life Simulator")
      expect(metadata.description).to include("runner")
    end
  end

  describe "the head of every page" do
    it "states the locale and the image a card should use" do
      get root_path

      expect(response.body).to include(%(<meta property="og:locale" content="en_GB">),
                                       %(<meta name="twitter:image" content="#{URI.join(root_url, 'icon.png')}">))
    end
  end
end
