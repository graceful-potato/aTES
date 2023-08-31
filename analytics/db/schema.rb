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

ActiveRecord::Schema[7.0].define(version: 2023_08_30_205159) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "accounts", force: :cascade do |t|
    t.string "email"
    t.string "full_name"
    t.uuid "public_id"
    t.string "role"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "balance", default: 0, null: false
    t.index ["public_id"], name: "index_accounts_on_public_id", unique: true
  end

  create_table "audit_logs", force: :cascade do |t|
    t.uuid "public_id"
    t.uuid "account_id"
    t.uuid "task_id"
    t.integer "amount"
    t.string "event_type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_audit_logs_on_account_id"
    t.index ["public_id"], name: "index_audit_logs_on_public_id", unique: true
    t.index ["task_id"], name: "index_audit_logs_on_task_id"
  end

  create_table "billing_cycles", force: :cascade do |t|
    t.uuid "public_id"
    t.uuid "account_id", null: false
    t.datetime "starts_at"
    t.datetime "ends_at"
    t.integer "status", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_billing_cycles_on_account_id"
    t.index ["public_id"], name: "index_billing_cycles_on_public_id", unique: true
  end

  create_table "failed_events", force: :cascade do |t|
    t.string "topic"
    t.uuid "event_id"
    t.integer "event_version"
    t.datetime "event_time"
    t.string "producer"
    t.string "event_name"
    t.text "error_message"
    t.jsonb "raw"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "tasks", force: :cascade do |t|
    t.uuid "public_id"
    t.string "title"
    t.string "jira_id"
    t.text "description"
    t.datetime "completed_at"
    t.uuid "assignee_id"
    t.integer "fee"
    t.integer "reward"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["assignee_id"], name: "index_tasks_on_assignee_id"
    t.index ["public_id"], name: "index_tasks_on_public_id", unique: true
  end

  create_table "transactions", force: :cascade do |t|
    t.uuid "public_id"
    t.uuid "billing_cycle_id", null: false
    t.uuid "account_id", null: false
    t.uuid "task_id"
    t.text "description"
    t.integer "credit", default: 0
    t.integer "debit", default: 0
    t.integer "direction", null: false
    t.integer "kind", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_transactions_on_account_id"
    t.index ["billing_cycle_id"], name: "index_transactions_on_billing_cycle_id"
    t.index ["public_id"], name: "index_transactions_on_public_id", unique: true
    t.index ["task_id"], name: "index_transactions_on_task_id"
  end

  add_foreign_key "audit_logs", "accounts", primary_key: "public_id"
  add_foreign_key "audit_logs", "tasks", primary_key: "public_id"
  add_foreign_key "billing_cycles", "accounts", primary_key: "public_id"
  add_foreign_key "tasks", "accounts", column: "assignee_id", primary_key: "public_id"
  add_foreign_key "transactions", "accounts", primary_key: "public_id"
  add_foreign_key "transactions", "billing_cycles", primary_key: "public_id"
  add_foreign_key "transactions", "tasks", primary_key: "public_id"
end
