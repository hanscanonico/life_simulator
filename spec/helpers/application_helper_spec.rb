# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApplicationHelper, type: :helper do
  describe "#describe_page" do
    it "collapses a description a record spells across several lines" do
      helper.describe_page("Radius 1,\n  then radius 2.\n")

      expect(helper.page_description).to eq("Radius 1, then radius 2.")
    end

    it "cuts a description at what a search result shows of it" do
      helper.describe_page("Mutation. #{'word ' * 100}")

      expect(helper.page_description.length).to eq(155)
      expect(helper.page_description).to end_with("...")
    end

    it "escapes a description spelled with markup characters exactly once" do
      helper.describe_page(%(Radius 1 & "well-mixed" <arms>))

      expect(helper.page_description).to eq(%(Radius 1 &amp; &quot;well-mixed&quot; &lt;arms&gt;))
    end

    it "replaces a description an earlier call already stated" do
      helper.describe_page("The first description.")
      helper.describe_page("The second description.")

      expect(helper.page_description).to eq("The second description.")
    end

    context "with nothing to describe" do
      it "falls back to the site's own description" do
        helper.describe_page(nil)

        expect(helper.page_description).to eq(described_class::DEFAULT_DESCRIPTION)
      end
    end
  end

  describe "#status_badge_class" do
    it "reads a finished run as success" do
      expect(helper.status_badge_class("finished")).to eq("badge-success")
    end

    it "reads a failed run as an error" do
      expect(helper.status_badge_class("failed")).to eq("badge-error")
    end

    it "reads a running run as information" do
      expect(helper.status_badge_class("running")).to eq("badge-info")
    end

    it "reads a claimed run as information" do
      expect(helper.status_badge_class("claimed")).to eq("badge-info")
    end

    it "leaves a pending run neutral" do
      expect(helper.status_badge_class("pending")).to eq("")
    end

    it "leaves a queued experiment neutral" do
      expect(helper.status_badge_class("queued")).to eq("")
    end

    context "with an unknown status" do
      it "is neutral" do
        expect(helper.status_badge_class("abandoned")).to eq("")
      end
    end

    context "with no status" do
      it "is neutral" do
        expect(helper.status_badge_class(nil)).to eq("")
      end
    end
  end

  describe "#canonical_url" do
    it "is the request's own address" do
      helper.request.env["PATH_INFO"] = "/experiments"

      expect(helper.canonical_url).to eq("http://test.host/experiments")
    end

    context "with a query string" do
      it "drops it" do
        helper.request.env["QUERY_STRING"] = "page=2"
        helper.request.env["PATH_INFO"] = "/experiments"

        expect(helper.canonical_url).to eq("http://test.host/experiments")
      end
    end
  end

  describe "#og_image_url" do
    it "addresses the site icon absolutely" do
      expect(helper.og_image_url).to eq("http://test.host/icon.png")
    end

    it "names a file the site actually serves" do
      expect(Rails.public_path.join("icon.png")).to exist
    end
  end

  describe "#percent_value" do
    it "reads a fraction as a whole percent" do
      expect(helper.percent_value(0.5)).to eq("50%")
    end

    it "rounds to the nearest percent" do
      expect(helper.percent_value(0.126)).to eq("13%")
    end

    context "with no fraction" do
      it "is a dash" do
        expect(helper.percent_value(nil)).to eq("—")
      end
    end
  end

  describe "#epoch_value" do
    it "delimits one epoch" do
      expect(helper.epoch_value(20_000)).to eq("20,000")
    end

    it "collapses a pair of equal epochs" do
      expect(helper.epoch_value(400, 400)).to eq("400")
    end

    it "joins a quartile pair with a dash" do
      expect(helper.epoch_value(200.0, 550.0)).to eq("200–550")
    end

    context "with a missing end" do
      it "is a dash" do
        expect(helper.epoch_value(400, nil)).to eq("—")
      end
    end
  end
end
