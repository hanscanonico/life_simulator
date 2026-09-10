# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Lab", type: :request do
  describe "GET /lab" do
    it "lazily loads the status frame and refreshes itself" do
      get lab_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(%(src="#{lab_status_path}"), 'loading="lazy"',
                                       %(http-equiv="refresh"))
    end
  end

  describe "GET /lab/status" do
    it "reports the queue, the live runners and the throughput" do
      run = create(:run, :claimed, runner_id: "runner-a", epochs_done: 400)
      create(:sample, run: run, epoch: 100)
      create(:sample, run: run, epoch: 400)

      get lab_status_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("runner-a", "300 epochs in the last hour")
    end

    context "with an idle lab" do
      it "says so" do
        get lab_status_path

        expect(response.body).to include("No runner has heartbeated", "The queue is empty")
      end
    end
  end
end
