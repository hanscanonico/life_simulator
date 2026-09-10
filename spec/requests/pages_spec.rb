# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Pages", type: :request do
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

    it "lists the ten instructions" do
      get how_it_works_path

      cells = %w[&lt; &gt; { } + - . , [ ]].map { |op| %(<td class="mono">#{op}</td>) }

      expect(response.body).to include(*cells)
    end
  end
end
