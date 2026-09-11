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

    it "names the run each slot is on and its hourly rate" do
      run = create(:run, :claimed, runner_id: "bench-3", epochs_done: 400)
      create(:sample, run: run, epoch: 100)
      create(:sample, run: run, epoch: 400)

      get lab_status_path

      expect(response.body).to include("Current run", "Epochs/h", %(href="#{run_path(run)}"))
    end

    context "with the runner parallelism in the environment" do
      it "says how many slots are idle" do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with("RUNNER_PARALLELISM").and_return("12")
        create(:run, :claimed, runner_id: "bench-0")

        get lab_status_path

        expect(response.body.squish).to include("12 slots expected, 1 seen, 11 idle")
      end
    end

    context "with a live run that has stopped sampling" do
      it "puts it in the section worth a look" do
        run = create(:run, :claimed, status: "running", runner_id: "bench-4",
                                     started_at: 40.minutes.ago)

        get lab_status_path

        expect(response.body).to include("Worth a look", "Silent for", "Run ##{run.id}")
      end
    end

    context "with an idle lab" do
      it "says so" do
        get lab_status_path

        expect(response.body).to include("No runner has heartbeated", "The queue is empty",
                                         "None.")
      end
    end
  end
end
