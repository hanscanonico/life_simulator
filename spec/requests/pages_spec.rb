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
  end

  describe "GET /how-it-works" do
    let(:observables) do
      %w[compress_ratio distinct_tapes top_share op_density replicator_count entropy_bits copy_rate
         transition_epoch]
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

    it "lists the programme's five sweeps in declaration order and the control apart" do
      get how_it_works_path

      items = response.parsed_body.css("ol li strong").map { |item| item.text.squish }

      expect(items).to eq(Lab::SWEEPS.except("bff_control").values.pluck(:name))
      expect(response.body.squish).to include("BFF positive control", "written up in")
      expect(response.body).to include(findings_path)
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

        expect(links).not_to include("Neighbourhood radius")
        expect(response.body).to include("Neighbourhood radius")
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
end
