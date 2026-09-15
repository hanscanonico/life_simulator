# frozen_string_literal: true

require "rails_helper"

RSpec.describe Charts::PhaseDiagram do
  def group(value, emergence_epochs: [], flagged_only_epochs: [], censored: 0)
    described_class::Group.new(value: value, label: value.to_s, emergence_epochs: emergence_epochs,
                               flagged_only_epochs: flagged_only_epochs, censored: censored)
  end

  def build(groups, **options)
    described_class.new(groups: groups, title: "Transition epoch vs radius", x_label: "Radius",
                        epochs: 20_000, **options)
  end

  describe "Group#median" do
    it "averages the two middle values of an even sample" do
      expect(group(1, emergence_epochs: [100, 300, 200, 400]).median).to eq(250.0)
    end

    it "takes the middle value of an odd sample" do
      expect(group(1, emergence_epochs: [300, 100, 200]).median).to eq(200)
    end

    context "with no emergence" do
      it "has no median" do
        expect(group(1, censored: 3).median).to be_nil
      end
    end

    context "with crossings nothing confirmed" do
      it "leaves them out of the median" do
        expect(group(1, emergence_epochs: [100], flagged_only_epochs: [900]).median).to eq(100)
      end
    end
  end

  describe "#x_tick_anchor" do
    subject(:diagram) { build([group(1, emergence_epochs: [100])]) }

    it "hugs the edges and centres everything between them" do
      anchors = [diagram.plot_left, (diagram.plot_left + diagram.plot_right) / 2, diagram.plot_right]
                .map { |position| diagram.x_tick_anchor(position) }

      expect(anchors).to eq(%w[start middle end])
    end
  end

  describe "#x_tick_label_x" do
    subject(:diagram) { build([group(1, emergence_epochs: [100])]) }

    it "insets the outermost labels and leaves the rest on their tick" do
      middle = (diagram.plot_left + diagram.plot_right) / 2
      positions = [diagram.plot_left, middle, diagram.plot_right].map { |x| diagram.x_tick_label_x(x) }

      expect(positions).to eq([diagram.plot_left + Charts::Plot::EDGE_INSET, middle,
                               diagram.plot_right - Charts::Plot::EDGE_INSET])
    end
  end

  describe "#dots" do
    it "plots one dot per run that emerged" do
      diagram = build([group(1, emergence_epochs: [100, 200]), group(2, emergence_epochs: [300])])

      expect(diagram.dots.size).to eq(3)
      expect(diagram.dots.first[:label]).to eq("1: emerged at epoch 100")
    end

    context "with a crossing no replicator confirmed" do
      subject(:diagram) { build([group(1, emergence_epochs: [100], flagged_only_epochs: [900])]) }

      it "plots it apart from the confirmed ones" do
        expect(diagram.dots.sole[:y]).not_to eq(diagram.flagged_dots.sole[:y])
        expect(diagram.flagged_dots.sole[:label]).to eq("1: flagged at epoch 900, unconfirmed")
      end

      it "keeps it on its arm's column" do
        expect(diagram.flagged_dots.sole[:x]).to eq(diagram.dots.sole[:x])
      end
    end

    # Y grows upwards, so a late emergence sits near the top — right below the runs
    # that never emerged at all.
    it "puts a later transition higher on the chart" do
      diagram = build([group(1, emergence_epochs: [100, 900])])
      early, late = diagram.dots

      expect(late[:y]).to be < early[:y]
    end
  end

  describe "#x_pixel" do
    # A dot is 4 units wide and a censored marker 5, so a column on the axis line itself
    # has half a marker outside the plot box. The columns take the label inset (14 units at
    # plot_left 120, plot_right 788) and keep their spacing: the middle value stays centred.
    it "insets the outermost columns and keeps the rest evenly spaced" do
      diagram = build([group(1, emergence_epochs: [100]), group(2, emergence_epochs: [100]),
                       group(3, emergence_epochs: [100])])

      expect(diagram.dots.pluck(:x)).to eq([134.0, 454.0, 774.0])
      expect(diagram.dots.last[:x]).to be < diagram.plot_right
    end
  end

  describe "#censored_marks" do
    it "lines the runs that never emerged up along the top" do
      diagram = build([group(1, emergence_epochs: [100]), group(2, censored: 4)])
      mark = diagram.censored_marks.sole

      expect(mark[:count]).to eq(4)
      expect(mark[:y]).to eq(diagram.plot_top + described_class::CENSORED_ROW)
      expect(mark[:label]).to include("no emergence in 20000 epochs")
    end
  end

  describe "#median_path" do
    it "joins the medians of the values that emerged" do
      diagram = build([group(1, emergence_epochs: [100]), group(2, censored: 1),
                       group(4, emergence_epochs: [300])])

      expect(diagram.median_path.scan(/[ML]/)).to eq(%w[M L])
    end
  end

  describe "#empty?" do
    context "with no finished run" do
      it "reports the diagram as empty" do
        expect(build([group(1), group(2)])).to be_empty
      end
    end

    context "with runs that never emerged" do
      it "still draws the diagram" do
        expect(build([group(1, censored: 2)])).not_to be_empty
      end
    end

    context "with a flagged crossing alone" do
      it "still draws the diagram" do
        expect(build([group(1, flagged_only_epochs: [900])])).not_to be_empty
      end
    end
  end

  describe "#x_ticks" do
    it "labels every value of the grid" do
      diagram = build([group(4, emergence_epochs: [100]), group(1, emergence_epochs: [200])])

      expect(diagram.x_ticks.map(&:label)).to eq(%w[1 4])
    end

    context "with a grid too long to label" do
      it "names every other value, starting from the first" do
        diagram = build((1..8).map { |value| group(value, emergence_epochs: [100]) })

        expect(diagram.x_ticks.map(&:label)).to eq(%w[1 3 5 7])
      end
    end
  end
end
