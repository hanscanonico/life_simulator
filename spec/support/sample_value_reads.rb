# frozen_string_literal: true

# The rows every statement that reads sample values brought back: the one number that says
# how much of a sweep a report held at once.
module SampleValueReads
  def value_reads_during(&)
    reads = []
    collect = lambda do |*, payload|
      reads << payload[:row_count] if payload[:name] != "SCHEMA" && payload[:sql].include?("values")
    end

    ActiveSupport::Notifications.subscribed(collect, "sql.active_record", &)

    reads
  end
end

RSpec.configure { |config| config.include SampleValueReads }
