# frozen_string_literal: true

class SnapshotsController < ApplicationController
  def png
    snapshot = Snapshot.find(params.expect(:id))
    return head :not_found if snapshot.png.blank?

    expires_in 1.hour, public: true
    return unless stale?(snapshot, public: true)

    send_data snapshot.png, type: "image/png", disposition: "inline"
  end
end
