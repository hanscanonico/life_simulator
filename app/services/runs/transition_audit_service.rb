# frozen_string_literal: true

module Runs
  # Which stored transitions the alphabet guard would no longer accept. The engine's
  # detector now disqualifies a sample whose alphabet has collapsed (DESIGN.md §1.2), and
  # samples recorded before that reads no `alphabet_size` — `op_density` above the guard
  # is the half of it every stored sample can be read for. A run is listed when a sample
  # at its transition epoch or later is that dense: run 183's shape, compressible because
  # its byte alphabet drifted down to two instructions.
  #
  # It reads stored rows and changes nothing: a `transition_epoch` is a measurement the
  # run made, and rewriting one is a decision for whoever reads this list.
  class TransitionAuditService
    include Callable

    COLUMNS = %w[run_id experiment transition_epoch dense_epoch op_density compress_ratio alphabet_size
                 guarded_epoch].freeze
    MAX_OP_DENSITY = Lab::Schema.transition.fetch("max_op_density")

    Row = Data.define(:run_id, :experiment, :transition_epoch, :dense_epoch, :values, :guarded_epoch) do
      def cells
        [run_id, experiment, transition_epoch, dense_epoch, values["op_density"], values["compress_ratio"],
         values["alphabet_size"], guarded_epoch]
      end
    end

    Report = Data.define(:rows, :transitioned) do
      def to_text
        [table, "\n", summary].join
      end

      private

      def summary
        "#{rows.size} of #{transitioned} stored transitions would no longer qualify " \
          "(op_density > #{MAX_OP_DENSITY} at the transition sample or later)\n" \
          "no stored transition_epoch was changed\n"
      end

      def table
        lines = [COLUMNS, *rows.map { |row| row.cells.map { |cell| cell.nil? ? "—" : cell.to_s } }]
        widths = lines.transpose.map { |column| column.map(&:length).max }

        lines.map { |line| "#{line.each_with_index.map { |cell, index| cell.rjust(widths[index]) }.join('  ')}\n" }
             .join
      end
    end

    def initialize(experiment: nil)
      @experiment = experiment
    end

    def call = Report.new(rows: rows, transitioned: transitioned.size)

    private

    def rows
      transitioned.filter_map { |run| row(run) if dense_epochs.key?(run.id) }
    end

    def row(run)
      epoch = dense_epochs.fetch(run.id)

      Row.new(run_id: run.id, experiment: run.experiment&.slug, transition_epoch: run.transition_epoch,
              dense_epoch: epoch, values: sample_values(run, epoch),
              guarded_epoch: TransitionEpochService.call(run: run))
    end

    def sample_values(run, epoch) = Sample.where(run: run, epoch: epoch).pick(:values) || {}

    def transitioned
      @transitioned ||= scope.where.not(transition_epoch: nil).includes(:experiment).order(:id).to_a
    end

    def scope = @experiment ? Run.where(experiment: @experiment) : Run.all

    # The first sample of each run, at or after its transition, that the guard reads as a
    # collapsed alphabet.
    def dense_epochs
      @dense_epochs ||= Sample.joins(:run).where(run: transitioned)
                              .where("samples.epoch >= runs.transition_epoch")
                              .where("(samples.values ->> 'op_density')::float > ?", MAX_OP_DENSITY)
                              .group(:run_id).minimum(:epoch)
    end
  end
end
