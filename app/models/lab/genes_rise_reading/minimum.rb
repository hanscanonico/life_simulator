# frozen_string_literal: true

require "csv"

module Lab
  module GenesRiseReading
    # McShea's minimum for one child, read offline (MINIMUM_PERCENTILE of classes per computing
    # cell on its fifth-decile and its last stored worlds) and handed in. Its late rise is the
    # rise step and the magnitude from the fifth-decile world to the last: two worlds carry no
    # persistence run, so §5.1 clause 4's maxima are not read on it.
    Minimum = Data.define(:fifth, :last) do
      def self.none = new(fifth: nil, last: nil)

      # The offline readings, by run id, from CSV text with MINIMA_COLUMNS as its header. A
      # blank value reads as unread.
      def self.parse(text)
        CSV.parse(text, headers: true).to_h do |row|
          fifth, last = MINIMA_COLUMNS.drop(1).map { |column| row[column].presence&.then { |value| Integer(value) } }
          [Integer(row.fetch("run_id")), new(fifth: fifth, last: last)]
        end
      end

      def measured? = !fifth.nil? && !last.nil?

      def late_rise? = measured? && last >= fifth + RISE_STEP && last >= fifth * MAGNITUDE
    end
  end
end
