# frozen_string_literal: true

module PagesHelper
  # The strongest link a programme item has: its write-up if one cites the sweep, else the
  # sweep page if the lab has queued it, else its name as plain text.
  def sweep_link(sweep)
    return tag.strong(link_to(sweep.name, finding_path(sweep.finding))) if sweep.finding?
    return tag.strong(link_to(sweep.name, experiment_path(sweep.experiment))) if sweep.experiment?

    tag.strong(sweep.name)
  end
end
