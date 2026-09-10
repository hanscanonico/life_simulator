# frozen_string_literal: true

require "rails_helper"

RSpec.describe CapybaraServerPort do
  describe ".choose" do
    it "picks free ports rather than the pinned one, with no override set" do
      ports = Array.new(3) { described_class.choose({}) }

      expect(ports).to all(be > 1024).and all(satisfy { |port| port != described_class::BASE_PORT })
    end

    it "picks a port that is actually bindable" do
      port = described_class.choose({})

      expect { TCPServer.new(described_class::PROBE_HOST, port).close }.not_to raise_error
    end

    it "lets CAPYBARA_SERVER_PORT win" do
      expect(described_class.choose({ "CAPYBARA_SERVER_PORT" => "4567", "TEST_ENV_NUMBER" => "2" })).to eq(4567)
    end

    it "ignores an empty CAPYBARA_SERVER_PORT" do
      expect(described_class.choose({ "CAPYBARA_SERVER_PORT" => "" })).not_to eq(0)
    end

    it "offsets the base port by TEST_ENV_NUMBER, that being the only override" do
      expect(described_class.choose({ "TEST_ENV_NUMBER" => "2" })).to eq(described_class::BASE_PORT + 2)
    end
  end
end
