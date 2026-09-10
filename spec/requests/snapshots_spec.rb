# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Snapshots", type: :request do
  let(:snapshot) { create(:snapshot, png: "\x89PNG\r\n") }

  describe "GET /snapshots/:id/png" do
    it "serves the PNG the engine rendered" do
      get png_snapshot_path(snapshot)

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("image/png")
      expect(response.body).to eq(snapshot.png)
    end

    it "lets a browser cache it" do
      get png_snapshot_path(snapshot)

      expect(response.headers["ETag"]).to be_present
      expect(response.headers["Cache-Control"]).to include("public")
    end

    it "answers a fresh conditional request with a 304" do
      get png_snapshot_path(snapshot)

      get png_snapshot_path(snapshot), headers: { "If-None-Match" => response.headers["ETag"] }

      expect(response).to have_http_status(:not_modified)
    end

    context "with no PNG rendered" do
      it "is a 404" do
        get png_snapshot_path(create(:snapshot, png: nil))

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
