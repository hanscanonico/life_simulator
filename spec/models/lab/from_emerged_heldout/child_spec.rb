# frozen_string_literal: true

require "rails_helper"

RSpec.describe Lab::FromEmergedHeldout::Child do
  subject(:reading) { described_class.read(samples, parent_epoch: parent_epoch, last_share: last_share) }

  let(:parent_epoch) { 20_000 }
  let(:last_share) { 0.9 }
  let(:window_end) { parent_epoch + Lab::FromEmergedHeldout::SETTLING_WINDOW }

  # `count` samples every 10 epochs from `from`, each merging `values.call(index)`.
  def series(from:, count:, &values)
    Array.new(count) { |index| [from + (10 * index), values.call(index)] }
  end

  describe "the settled relapse" do
    context "with three samples below the floor ending at the window's edge" do
      let(:samples) do
        series(from: window_end - 20, count: 3) { { "replicator_share" => 0.05 } } +
          series(from: window_end + 10, count: 50) { { "replicator_share" => 0.9 } }
      end

      it "reads none: the window's last epoch is the switch's transient" do
        expect(reading.settled_relapse_epoch).to be_nil
      end
    end

    context "with three samples below the floor starting just past the window" do
      let(:samples) do
        series(from: window_end - 10, count: 1) { { "replicator_share" => 0.05 } } +
          series(from: window_end + 1, count: 3) { { "replicator_share" => 0.05 } }
      end

      it "reads a relapse at the first of them" do
        expect(reading.settled_relapse_epoch).to eq(window_end + 1)
      end
    end

    context "with two samples below the floor, one at the floor, then one below" do
      let(:samples) do
        series(from: window_end + 10, count: 4) { |index| { "replicator_share" => index == 2 ? 0.1 : 0.05 } }
      end

      it "reads none: a share at the floor breaks the run" do
        expect(reading.settled_relapse_epoch).to be_nil
      end
    end
  end

  describe "extinction" do
    let(:samples) { [] }

    context "with a last-decile share at the bar" do
      let(:last_share) { 0.1 }

      it "is not extinct" do
        expect(reading.extinct).to be(false)
      end
    end

    context "with a last-decile share just below the bar" do
      let(:last_share) { 0.0999 }

      it "is extinct, and a survivor of nothing" do
        expect(reading).to have_attributes(extinct: true, survivor?: false)
      end
    end

    context "with no share sampled" do
      let(:last_share) { nil }

      it "is read by neither rule" do
        expect(reading).to have_attributes(read: false, extinct: false, survivor?: false)
      end
    end
  end

  describe "the latency ratio" do
    # `count` settled samples, the first decile reading `first` and the last `last`.
    def latencies(count, first:, last:)
      decile = (count + 9) / 10
      series(from: window_end + 10, count: count) do |index|
        { "replicator_share" => 0.9, "copy_latency" => index >= count - decile ? last : first }
      end
    end

    context "with ten samples in each decile" do
      let(:samples) { latencies(100, first: 4_000, last: 2_000) }

      it "reads last over first" do
        expect(reading).to have_attributes(first_latency: 4_000, last_latency: 2_000, latency_ratio: Rational(1, 2))
      end
    end

    context "with nine samples in each decile" do
      let(:samples) { latencies(90, first: 4_000, last: 2_000) }

      it "is unmeasured" do
        expect(reading).to have_attributes(latency_ratio: nil, latency_measured?: false)
      end
    end

    context "with the samples inside the window carrying latency" do
      let(:samples) do
        series(from: parent_epoch + 10, count: 100) { { "copy_latency" => 9_000 } } +
          latencies(100, first: 4_000, last: 2_000)
      end

      it "reads the deciles past the window only, its last epoch included in the window" do
        expect(reading.first_latency).to eq(4_000)
      end
    end

    context "with samples that do not carry latency as a number" do
      let(:samples) do
        latencies(100, first: 4_000, last: 2_000) +
          series(from: window_end + 5_000, count: 50) { { "replicator_share" => 0.9, "copy_latency" => nil } }
      end

      it "cuts the deciles over the samples that carry it" do
        expect(reading.last_latency).to eq(2_000)
      end
    end

    context "with a first-decile median of zero" do
      let(:samples) { latencies(100, first: 0, last: 2_000) }

      it "is unmeasured" do
        expect(reading.latency_ratio).to be_nil
      end
    end

    context "with an extinct child" do
      let(:samples) { latencies(100, first: 4_000, last: 2_000) }
      let(:last_share) { 0.05 }

      it "is unmeasured" do
        expect(reading.latency_ratio).to be_nil
      end
    end
  end
end
