# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Lab", type: :request do
  describe "GET /lab" do
    it "loads the status frame and polls it in place" do
      get lab_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(%(src="#{lab_status_path}"),
                                       %(data-controller="frame-poll"))
      expect(response.body).not_to include('loading="lazy"')
    end

    it "never reloads itself" do
      get lab_path

      expect(response.body).not_to include("http-equiv")
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

    it "offers a refresh control and says how fresh it is" do
      get lab_status_path

      expect(response.body).to include(%(href="#{lab_status_path}"), "Refresh",
                                       "updated just now")
    end

    context "with a pending run" do
      it "shows the priority of the oldest one" do
        create(:run, priority: 5)

        get lab_status_path

        expect(response.body).to include("priority 5")
      end
    end

    context "with an idle lab" do
      it "says so" do
        get lab_status_path

        expect(response.body).to include("No runner has heartbeated", "The queue is empty")
      end
    end
  end
end
