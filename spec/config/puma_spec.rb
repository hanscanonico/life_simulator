# frozen_string_literal: true

require "rails_helper"

# Records the Puma DSL calls config/puma.rb makes under a given environment, so the shape
# of the deployed web process can be asserted without booting a server.
class PumaDslProbe
  attr_reader :threads_range, :workers_count, :plugins, :fork_hooks

  def initialize
    @plugins = []
    @fork_hooks = []
    @preloaded = false
  end

  def load(env)
    with_env(env) { instance_eval(Rails.root.join("config/puma.rb").read) }
    self
  end

  def preloaded? = @preloaded

  def threads(min, max) = @threads_range = [min.to_i, max.to_i]
  def workers(count) = @workers_count = count
  def preload_app! = @preloaded = true
  def before_fork(&block) = @fork_hooks << block
  def plugin(name) = @plugins << name
  def port(_port) = nil
  def pidfile(_path) = nil

  private

  def with_env(env)
    previous = ENV.to_h.slice(*env.keys)
    env.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
    yield
  ensure
    env.each_key { |key| ENV.delete(key) }
    previous.each { |key, value| ENV[key] = value }
  end
end

# Only a booting Puma evaluates config/puma.rb, so a web process that forks without
# preloading — or that stopped forking at all — would surface on the mini-pc and nowhere
# else. These examples pin the shape the memory budget in deploy/docker-compose.yml assumes.
RSpec.describe "config/puma.rb" do
  subject(:config) { PumaDslProbe.new.load(env) }

  let(:env) { {} }

  context "with WEB_CONCURRENCY unset" do
    it "runs a single process" do
      expect(config.workers_count).to eq(0)
    end

    it "does not preload the app" do
      expect(config).not_to be_preloaded
    end
  end

  context "with WEB_CONCURRENCY set" do
    let(:env) { { "WEB_CONCURRENCY" => "2" } }

    it "forks that many workers" do
      expect(config.workers_count).to eq(2)
    end

    it "preloads the app" do
      expect(config).to be_preloaded
    end

    it "releases the master's database connections before forking" do
      expect(ActiveRecord::Base.connection_handler).to receive(:clear_all_connections!)

      config.fork_hooks.each(&:call)
    end
  end

  it "sizes the thread pool from RAILS_MAX_THREADS" do
    expect(PumaDslProbe.new.load("RAILS_MAX_THREADS" => "3").threads_range).to eq([3, 3])
  end

  context "with SOLID_QUEUE_IN_PUMA set" do
    let(:env) { { "SOLID_QUEUE_IN_PUMA" => "1" } }

    it "runs the Solid Queue supervisor inside Puma" do
      expect(config.plugins).to include(:solid_queue)
    end
  end

  it "matches the process shape the deployed stack passes it" do
    compose = YAML.load_file(Rails.root.join("deploy/docker-compose.yml"), aliases: true)
    deployed = compose.dig("services", "app", "environment")

    expect(deployed).to include(
      "WEB_CONCURRENCY" => "2", "RAILS_MAX_THREADS" => "3", "JOB_CONCURRENCY" => "1"
    )
  end
end
