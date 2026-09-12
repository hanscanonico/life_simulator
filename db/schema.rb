# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_09_11_180000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "experiments", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.integer "epochs", null: false
    t.string "name", null: false
    t.jsonb "param_grid", default: {}, null: false
    t.integer "priority", default: 0, null: false
    t.integer "runs_count", default: 0, null: false
    t.jsonb "seeds", default: [], null: false
    t.string "slug", null: false
    t.string "status", default: "draft", null: false
    t.string "substrate", default: "soup", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_experiments_on_name", unique: true
    t.index ["slug"], name: "index_experiments_on_slug", unique: true
  end

  create_table "rescores", force: :cascade do |t|
    t.float "compress_ratio"
    t.datetime "created_at", null: false
    t.bigint "distinct_tapes"
    t.float "entropy_bits"
    t.integer "epoch", null: false
    t.datetime "measured_at"
    t.bigint "replicator_count"
    t.bigint "run_id", null: false
    t.integer "top_k", null: false
    t.float "top_share"
    t.datetime "updated_at", null: false
    t.index ["run_id", "epoch", "top_k"], name: "index_rescores_on_run_id_and_epoch_and_top_k", unique: true
    t.index ["run_id"], name: "index_rescores_on_run_id"
  end

  create_table "runs", force: :cascade do |t|
    t.datetime "claimed_at"
    t.float "compute_seconds", default: 0.0, null: false
    t.datetime "created_at", null: false
    t.integer "epochs", null: false
    t.integer "epochs_done", default: 0, null: false
    t.datetime "epochs_done_at"
    t.text "error"
    t.bigint "experiment_id", null: false
    t.datetime "finished_at"
    t.datetime "heartbeat_at"
    t.jsonb "params", default: {}, null: false
    t.jsonb "persistence", default: {}, null: false
    t.integer "priority", default: 0, null: false
    t.string "runner_id"
    t.bigint "seed", null: false
    t.datetime "started_at"
    t.string "status", default: "pending", null: false
    t.jsonb "summary", default: {}, null: false
    t.integer "transition_epoch"
    t.datetime "updated_at", null: false
    t.index ["experiment_id"], name: "index_runs_on_experiment_id"
    t.index ["finished_at"], name: "index_runs_on_finished_at_terminal", where: "((status)::text = ANY (ARRAY[('finished'::character varying)::text, ('failed'::character varying)::text]))"
    t.index ["heartbeat_at"], name: "index_runs_on_heartbeat_at"
    t.index ["status", "id"], name: "index_runs_on_status_and_id"
    t.index ["status", "priority", "id"], name: "index_runs_on_status_and_priority_and_id", order: { priority: :desc }
  end

  create_table "samples", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "epoch", null: false
    t.bigint "run_id", null: false
    t.datetime "updated_at", null: false
    t.jsonb "values", default: {}, null: false
    t.index ["created_at"], name: "index_samples_on_created_at"
    t.index ["run_id", "epoch"], name: "index_samples_on_run_id_and_epoch", unique: true
    t.index ["run_id"], name: "index_samples_on_run_id_replicated", where: "((\"values\" -> 'replicator_count'::text) > '0'::jsonb)"
  end

  create_table "snapshots", force: :cascade do |t|
    t.binary "blob"
    t.datetime "created_at", null: false
    t.integer "epoch", null: false
    t.binary "png"
    t.string "reason", default: "cadence", null: false
    t.bigint "run_id", null: false
    t.datetime "updated_at", null: false
    t.index ["run_id", "epoch"], name: "index_snapshots_on_run_id_and_epoch", unique: true
  end

  add_foreign_key "rescores", "runs"
  add_foreign_key "runs", "experiments"
  add_foreign_key "samples", "runs"
  add_foreign_key "snapshots", "runs"
end
