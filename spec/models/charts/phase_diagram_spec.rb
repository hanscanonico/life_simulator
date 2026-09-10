# frozen_string_literal: true

require "rails_helper"

RSpec.describe Charts::PhaseDiagram do
  def group(value, transition_epochs: [], censored: 0)
    described_class::Group.new(value: value, label: value.to_s, transition_epochs: transition_epochs,
                               censored: censored)
  end

  def build(groups, **options)
    described_class.new(groups: groups, title: "Transition epoch vs radius", x_label: "Radius",
                        epochs: 20_000, **options)
  end

  describe "Group#median" do
    it "averages the two middle values of an even sample" do
      expect(group(1, transition_epochs: [100, 300, 200, 400]).median).to eq(250.0)
    end

    it "takes the middle value of an odd sample" do
      expect(group(1, transition_epochs: [300, 100, 200]).median).to eq(200)
    end

    context "with no transition" do
      it "has no median" do
        expect(group(1, censored: 3).median).to be_nil
      end
    end
  end

  describe "#x_tick_anchor" do
    subject(:diagram) { build([group(1, transition_epochs: [100])]) }

    it "hugs the edges and centres everything between them" do
      anchors = [diagram.plot_left, (diagram.plot_left + diagram.plot_right) / 2, diagram.plot_right]
                .map { |position| diagram.x_tick_anchor(position) }

      expect(anchors).to eq(%w[start middle end])
    end
  end

  describe "#dots" do
    it "plots one dot per transitioned run" do
      diagram = build([group(1, transition_epochs: [100, 200]), group(2, transition_epochs: [300])])

      expect(diagram.dots.size).to eq(3)
    end

    # Y grows upwards, so a late transition sits near the top — right below the runs
    # that never transitioned at all.
    it "puts a later transition higher on the chart" do
      diagram = build([group(1, transition_epochs: [100, 900])])
      early, late = diagram.dots

      expect(late[:y]).to be < early[:y]
    end
  end

  describe "#censored_marks" do
    it "lines the runs that never transitioned up along the top" do
      diagram = build([group(1, transition_epochs: [100]), group(2, censored: 4)])
      mark = diagram.censored_marks.sole

      expect(mark[:count]).to eq(4)
      expect(mark[:y]).to eq(diagram.plot_top + described_class::CENSORED_ROW)
      expect(mark[:label]).to include("no emergence in 20000 epochs")
    end
  end

  describe "#median_path" do
    it "joins the medians of the values that transitioned" do
      diagram = build([group(1, transition_epochs: [100]), group(2, censored: 1),
                       group(4, transition_epochs: [300])])

      expect(diagram.median_path.scan(/[ML]/)).to eq(%w[M L])
    end
  end

  describe "#empty?" do
    context "with no finished run" do
      it "reports the diagram as empty" do
        expect(build([group(1), group(2)])).to be_empty
      end
    end

    context "with runs that never transitioned" do
      it "still draws the diagram" do
        expect(build([group(1, censored: 2)])).not_to be_empty
      end
    end
  end

  describe "#x_ticks" do
    it "labels every value of the grid" do
      diagram = build([group(4, transition_epochs: [100]), group(1, transition_epochs: [200])])

      expect(diagram.x_ticks.map(&:label)).to eq(%w[1 4])
    end
  end
end
