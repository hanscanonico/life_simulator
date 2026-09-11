# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Pages", type: :request do
  describe "GET /" do
    it "titles itself with the bare site name and falls back to the site description" do
      get root_path

      expect(response.body).to include(
        "<title>Life Simulator</title>",
        %(<meta name="description" content="A research instrument for the spontaneous emergence of ) +
        %(self-replicators in a spatial program soup.">)
      )
    end

    it "strips the programme's standing above the copy" do
      create(:experiment)
      create(:run, status: "finished", epochs_done: 1_234, transition_epoch: 5_030)

      get root_path

      strip = response.parsed_body.css(".facts").first

      expect(strip.css("dt").map(&:text)).to eq(["Sweeps", "Runs finished", "Epochs simulated",
                                                 "Seeds that transitioned", "Largest replicator census"])
      expect(strip.css("dd").map(&:text)).to eq(%w[2 1 1,234 1 —])
    end

    it "digests the newest findings without stating a figure of its own" do
      newest = Findings::Registry.all.first

      get root_path

      expect(response.body.squish).to include("What the sweeps have found", newest.title,
                                              newest.status_label)
      expect(response.body).to include(finding_path(newest), findings_path)
    end

    context "with the newest finding's sweep in the lab" do
      it "links the sweep beside it" do
        experiment = create(:experiment, slug: Findings::Registry.all.first.experiment_slug)

        get root_path

        expect(response.body).to include(experiment_path(experiment))
      end
    end
  end

  describe "GET /how-it-works" do
    let(:observables) do
      %w[compress_ratio distinct_tapes top_share op_density replicator_count entropy_bits alphabet_size
         copy_rate transition_epoch]
    end

    it "defines the substrate and links to the sweeps" do
      get how_it_works_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("torus", "tape_len", "Computational Life", experiments_path)
    end

    it "names every observable the engine records" do
      get how_it_works_path

      expect(response.body).to include(*observables)
    end

    it "sets the page title and a meta description" do
      get how_it_works_path

      expect(response.body).to include(
        "<title>How it works — Life Simulator</title>",
        %(<meta name="description" content="The substrate, the ten-instruction language)
      )
    end

    it "sits second in the site nav" do
      get root_path

      nav = response.parsed_body.css(".site-nav a").map { |link| [link.text, link["href"]] }

      expect(nav[1]).to eq(["How it works", how_it_works_path])
    end

    it "lists the programme's five sweeps in declaration order, the control and the re-runs apart" do
      get how_it_works_path

      items = response.parsed_body.css("ol li strong").map { |item| item.text.squish }

      expect(items).to eq(Lab::SWEEPS.except("bff_control", "mutation_rate_long").values.pluck(:name))
      expect(response.body.squish).to include("BFF positive control", "written up in")
      expect(response.body).to include(findings_path)
    end

    it "names the longer re-run under the list rather than in it" do
      get how_it_works_path

      expect(response.body.squish).to include("re-run at a longer budget", "Mutation rate, long runs")
      expect(response.body).to include(finding_path("mutation-rate-long-horizon"))
    end

    context "with a sweep the lab has queued and a finding citing it" do
      it "links the sweep's name to its write-up" do
        create(:experiment, name: "Mutation rate", slug: "mutation-rate")

        get how_it_works_path

        expect(response.body).to include(finding_path("mutation-rate-window"))
      end
    end

    context "with a sweep no finding cites and no experiment for it" do
      it "leaves its name as plain text" do
        get how_it_works_path

        links = response.parsed_body.css("ol li strong a").map(&:text)

        expect(links).not_to include("Instruction set ablations")
        expect(response.body).to include("Instruction set ablations")
      end
    end

    it "keeps the transition as a signal instead of calling it emergence" do
      get how_it_works_path

      expect(response.body.squish)
        .to include("primary dependent variable of every sweep",
                    "the signal we sweep on, not a proof of self-replication",
                    "the replicator census can still read zero")
      expect(response.body).not_to match(/self-replicator emerged/)
    end

    it "defines the words the site uses precisely" do
      get how_it_works_path

      terms = response.parsed_body.css("#glossary ~ dl dt").map(&:text)

      expect(response.body).to include(%(id="glossary"))
      expect(terms).to include("transition", "flagged", "replicator", "census", "emergence", "arm")
    end

    it "lists the ten instructions" do
      get how_it_works_path

      cells = %w[&lt; &gt; { } + - . , [ ]].map { |op| %(<td class="mono">#{op}</td>) }

      expect(response.body).to include(*cells)
    end
  end

  describe "the document head" do
    it "declares its encoding first" do
      get root_path

      expect(response.parsed_body.at_css("head").elements.first.to_s).to eq(%(<meta charset="utf-8">))
    end

    it "names the site and shows its icon once to a sharer" do
      get root_path

      head = response.parsed_body.css("head")

      expect(head.css(%(meta[property="og:site_name"])).pluck("content"))
        .to eq(["Life Simulator"])
      expect(head.css(%(meta[property="og:image"])).pluck("content"))
        .to eq(["http://www.example.com/icon.png"])
      expect(head.css(%(meta[name="twitter:card"])).pluck("content")).to eq(["summary"])
    end

    it "points a page at itself" do
      get how_it_works_path

      expect(canonical_of(response)).to eq(["http://www.example.com/how-it-works"])
      expect(og_url_of(response)).to eq(["http://www.example.com/how-it-works"])
    end

    context "on a paginated list" do
      it "points back at the query-free address" do
        get experiments_path, params: { page: 2 }

        expect(canonical_of(response)).to eq(["http://www.example.com/experiments"])
        expect(og_url_of(response)).to eq(["http://www.example.com/experiments"])
      end
    end

    def canonical_of(response)
      response.parsed_body.css(%(head link[rel="canonical"])).pluck("href")
    end

    def og_url_of(response)
      response.parsed_body.css(%(head meta[property="og:url"])).pluck("content")
    end
  end
end
