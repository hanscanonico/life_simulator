# frozen_string_literal: true

require "socket"

# Chooses the port the Capybara test server binds to.
#
# The default is a free port the OS hands out at boot, so several checkouts of this repo
# can run the `js: true` system specs at the same time without fighting over one port —
# or, worse, silently driving another checkout's server. Two overrides, in order:
#
#   CAPYBARA_SERVER_PORT=3001  pins the port explicitly
#   TEST_ENV_NUMBER=2          pins BASE_PORT + n, for parallel workers
module CapybaraServerPort
  BASE_PORT = 3001
  PROBE_HOST = "127.0.0.1"

  module_function

  def choose(env = ENV)
    pinned = presence(env["CAPYBARA_SERVER_PORT"])
    return pinned.to_i if pinned

    worker = presence(env["TEST_ENV_NUMBER"])
    return BASE_PORT + worker.to_i if worker

    free
  end

  # Binds port 0, reads back the port the OS picked, and releases it. The window between
  # the close and Puma's bind is small enough in practice, and far smaller than the risk
  # of a pinned port.
  def free
    server = TCPServer.new(PROBE_HOST, 0)
    server.addr[1]
  ensure
    server&.close
  end

  def presence(value)
    value unless value.nil? || value.strip.empty?
  end
end
