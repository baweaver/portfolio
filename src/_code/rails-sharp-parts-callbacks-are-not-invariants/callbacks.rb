# frozen_string_literal: true

require_relative "setup"
require "rubocop"
require "flipper"

Flipper.configure { |c| c.adapter { Flipper::Adapters::Memory.new } }

# segment: backfill_example
def backfill_example
  Order.where(region: nil).find_each do |order|
    order.update!(region: "us-west-2")
  end
end
# end: backfill_example

# segment: backfill_update_all
def backfill_update_all
  Order.where(region: nil).update_all(region: "unknown")
end
# end: backfill_update_all

# segment: census_example
class Author < ActiveRecord::Base
  self.table_name = "events"
  has_many :posts, class_name: "Post", foreign_key: :event_id, dependent: :destroy
end

class Post < ActiveRecord::Base
  self.table_name = "seats"
  belongs_to :author, class_name: "Author", foreign_key: :event_id, touch: true, counter_cache: true
end
# end: census_example

# segment: census_example
def census_demo
  {
    post_save_filters: Post._save_callbacks.map { _1.filter.to_s },
    post_count: census(Post),
    author_count: census(Author)
  }
end

# => {
#   post_save_filters: ["autosave_associated_records_for_author"],
#   post_count: 5,
#   author_count: 6
# }
# end: census_example

# segment: update_attribute_demo
class ValidatedSeat < ActiveRecord::Base
  self.table_name = "seats"
  validates :reserved_by, exclusion: {in: ["invalid"]}
end

def update_attribute_demo
  seat = ValidatedSeat.create!(reserved_by: "fine", external_ref: "REF-#{SecureRandom.hex(4)}")
  seat.update_attribute(:reserved_by, "invalid")
  # => "invalid"
  ValidatedSeat.find(seat.id).reserved_by
end
# end: update_attribute_demo

# segment: counter_cache_drift
def counter_cache_drift
  event = Event.create!(name: "Drift#{SecureRandom.hex(4)}")

  Seat.create!(event: event, external_ref: "CD#{SecureRandom.hex(4)}")
  Seat.insert_all([{event_id: event.id, external_ref: "CD#{SecureRandom.hex(4)}"}] * 3)

  {
    counter: event.reload.seats_count,
    actual: event.seats.count
  }
end
# end: counter_cache_drift

# segment: touch_trace
def touch_trace
  # Prove: creating a Seat with touch: true on its event causes the event's
  # updated_at to change while the seat's transaction is still open.
  event = Event.create!(name: "Touch#{SecureRandom.hex(4)}")
  original_updated_at = event.updated_at

  sleep(0.01)

  effects = []
  seat_class = Class.new(Seat) do
    after_save { effects << [:seat_after_save, self.class.lease_connection.transaction_open?] }
    after_commit { effects << [:seat_after_commit, self.class.lease_connection.transaction_open?] }
  end

  seat_class.create!(event_id: event.id, external_ref: "TT#{SecureRandom.hex(4)}")

  # The event was touched (updated_at changed) inside the seat's save transaction
  event.reload
  effects << [:event_was_touched, event.updated_at > original_updated_at]
  effects
end
# end: touch_trace

# segment: reentry_demo
def reentry_demo
  depth = {current: 0, max: 0}

  klass = Class.new(ActiveRecord::Base) do
    self.table_name = "seats"

    after_save do
      depth[:current] += 1
      depth[:max] = [depth[:max], depth[:current]].max

      update!(reserved_by: "again") if depth[:current] < 3

      depth[:current] -= 1
    end
  end

  klass.create!(external_ref: "RE#{SecureRandom.hex(4)}")
  depth[:max]
end
# end: reentry_demo

# segment: after_find_demo
def after_find_demo(refs)
  count = 0
  klass = Class.new(ActiveRecord::Base) do
    self.table_name = "seats"
    after_find { count += 1 }
  end

  klass.where(external_ref: refs).to_a
  count
end
# end: after_find_demo

# segment: after_initialize_dirty
def after_initialize_dirty
  klass = Class.new(ActiveRecord::Base) do
    self.table_name = "seats"
    after_initialize { self.priority = true if priority == false }
  end

  record = klass.where.not(external_ref: nil).first
  record&.changed?
end
# end: after_initialize_dirty

# segment: mutation_past_validation
class MutatingSeat < ActiveRecord::Base
  self.table_name = "seats"
  validates :reserved_by, exclusion: {in: ["invalid"]}
  before_save { self.reserved_by = "invalid" }
end

def mutation_past_validation
  seat = MutatingSeat.new(reserved_by: "fine", external_ref: "MV#{SecureRandom.hex(4)}")
  # => true (validations passed!)

  seat.save!
  reloaded = MutatingSeat.find(seat.id)
  # => "invalid"

  reloaded.reserved_by
  # => false

  {
    value: reloaded.reserved_by,
    valid: reloaded.valid?
  }
end
# end: mutation_past_validation

# segment: validation_query_fanout
def validation_query_fanout(count: 50)
  event = Event.create!(name: "Fanout#{SecureRandom.hex(4)}", capacity: 100_000)

  validated = count_statements_for {
    count.times do |n|
      CapacitySeat.create!(event: event, external_ref: "VF#{SecureRandom.hex(6)}")
    end
  }

  plain = count_statements_for {
    count.times { |n| Seat.create!(external_ref: "PF#{SecureRandom.hex(6)}") }
  }

  {validated: validated, plain: plain}
end

def count_statements_for(&block)
  total = 0
  sub = ActiveSupport::Notifications.subscribe("sql.active_record") do |event|
    sql = event.payload[:sql].to_s
    next if event.payload[:name] == "SCHEMA"

    total += 1
  end

  block.call
  ActiveSupport::Notifications.unsubscribe(sub)
  total
end
# end: validation_query_fanout

# segment: after_save_rollback
def after_save_rollback
  emails = []
  klass = Class.new(ActiveRecord::Base) do
    self.table_name = "seats"
    after_save { emails << :sent }
  end

  rows_before = Seat.count
  klass.transaction do
    klass.create!(external_ref: "RB#{SecureRandom.hex(4)}")
    raise ActiveRecord::Rollback
  end

  {emails: emails.size, rows_written: Seat.count - rows_before}
end
# end: after_save_rollback

# segment: after_commit_timing
def after_commit_timing
  commits = []
  klass = Class.new(ActiveRecord::Base) do
    self.table_name = "seats"
    after_commit { commits << :fired }
  end

  inner_count = nil
  klass.transaction do
    klass.create!(external_ref: "NT1_#{SecureRandom.hex(4)}")
    klass.transaction(requires_new: true) {
      klass.create!(external_ref: "NT2_#{SecureRandom.hex(4)}")
    }

    inner_count = commits.size
  end

  {inside: inner_count, after: commits.size}
end
# end: after_commit_timing

# segment: commit_coalescing
def commit_coalescing
  fires = {create: 0, update: 0}
  klass = Class.new(ActiveRecord::Base) do
    self.table_name = "seats"
    after_create_commit { fires[:create] += 1 }
    after_update_commit { fires[:update] += 1 }
  end

  klass.transaction do
    record = klass.create!(external_ref: "CC#{SecureRandom.hex(4)}")
    record.update!(reserved_by: "x")
  end

  fires
end
# end: commit_coalescing

# segment: commit_ordering
def commit_ordering
  order = []
  klass = Class.new(ActiveRecord::Base) do
    self.table_name = "seats"
    after_commit { order << :first_defined }
    after_commit { order << :second_defined }
  end

  klass.create!(external_ref: "CO#{SecureRandom.hex(4)}")
  order
end
# end: commit_ordering

# segment: throw_abort
def throw_abort_demo
  klass = Class.new(ActiveRecord::Base) do
    self.table_name = "seats"
    before_save { throw(:abort) }
  end

  record = klass.new(external_ref: "BL#{SecureRandom.hex(4)}")
  {save_result: record.save, persisted: record.persisted?}
end
# end: throw_abort

# segment: destroy_ordering
class GuardedEvent < ActiveRecord::Base
  self.table_name = "events"
  has_many :seats, foreign_key: :event_id, dependent: :destroy
  before_destroy { throw :abort if seats.exists? }
end

def destroy_ordering_without_prepend
  event = GuardedEvent.create!(name: "G#{SecureRandom.hex(4)}")
  Seat.create!(event_id: event.id, external_ref: "DO#{SecureRandom.hex(4)}")

  event.destroy

  GuardedEvent.find_by(id: event.id).present?
end

def destroy_ordering_with_prepend
  event = PrependedEvent.create!(name: "P#{SecureRandom.hex(4)}")
  Seat.create!(event_id: event.id, external_ref: "DP#{SecureRandom.hex(4)}")

  event.destroy

  {
    survived: PrependedEvent.find_by(id: event.id).present?,
    seats: Seat.where(event_id: event.id).count
  }
end
# end: destroy_ordering

# segment: skip_callback_global
def skip_callback_global
  pings = []
  klass = Class.new(ActiveRecord::Base) do
    self.table_name = "seats"
    after_save(:do_ping)
    define_method(:do_ping) { pings << :ping }
  end

  klass.create!(external_ref: "SK1_#{SecureRandom.hex(4)}")
  klass.skip_callback(:save, :after, :do_ping)

  klass.create!(external_ref: "SK2_#{SecureRandom.hex(4)}")
  klass.set_callback(:save, :after, :do_ping)

  pings.size
end
# end: skip_callback_global

# segment: normalizes_example
class NormalizedUser < ActiveRecord::Base
  self.table_name = "orders"
  normalizes :region, with: -> (val) { val&.strip&.downcase }
end

# NormalizedUser.new(region: "  US-WEST  ").region
# => "us-west"
# end: normalizes_example

# segment: notification_subscriber_snippet
def notification_subscriber_snippet
  ActiveSupport::Notifications.subscribe(/\.seats\z/) do |event|
    AppLogger.info("[WRITE] #{event.name} #{event.payload} #{event.duration.round}ms")
  end
end
# end: notification_subscriber_snippet

# segment: notification_subscriber
def notification_subscriber_demo
  events = []
  sub = ActiveSupport::Notifications.subscribe(/\.seats\z/) do |event|
    events << "[WRITE] #{event.name} #{event.payload} #{event.duration.round}ms"
  end

  seat = Seat.create!(external_ref: "NS#{SecureRandom.hex(4)}")

  Seats::ReserveSeat.call(seat_id: seat.id, by: "test")
  ActiveSupport::Notifications.unsubscribe(sub)

  events
end
# => ["[WRITE] reserve_seat.seats {seat_id: 1, by: \"test\"} 7ms"]
# end: notification_subscriber

# segment: write_outside_command_cop
module ArticleCops
  # Only flags mutation calls on constants (Model.create!) or instance
  # variables/self (@order.save!, save!). Skips local variables like
  # set.delete or hash.update which aren't ActiveRecord.
  class WriteOutsideCommand < RuboCop::Cop::Base
    def on_send(node)
      return unless mutation?(node)
      return unless model_receiver?(node)
      return if processed_source.file_path.include?("app/public")

      add_offense(node, message: "Mutate ActiveRecord models through a command in app/public.")
    end

    private

    def mutation?(node)
      %i[
        save
        save!
        update
        update!
        update_column
        update_columns
        update_all
        destroy
        destroy!
        delete
        delete_all
        insert_all
        upsert_all
        create
        create!
      ]
        .include?(node.method_name)
    end

    def model_receiver?(node)
      receiver = node.receiver

      # bare save! (implicit self)
      return true if receiver.nil?

      # User.create!
      return true if receiver.const_type?

      # @order.save!
      return true if receiver.ivar_type?

      # self.update!
      return true if receiver.self_type?

      false
    end
  end
end

# The below is only necessary to prove the cop works inline in tests.
# In a real project you'd drop the class into .rubocop/ and run normally.
def write_outside_command_cop_check(source, file_path: "app/services/foo.rb")
  registry = RuboCop::Cop::Registry.new([ArticleCops::WriteOutsideCommand])
  config = RuboCop::Config.new({"ArticleCops/WriteOutsideCommand" => {"Enabled" => true}}, "")
  team = RuboCop::Cop::Team.mobilize(registry, config)

  source_obj = RuboCop::ProcessedSource.new(source, RUBY_VERSION.to_f, file_path)
  result = team.investigate(source_obj)

  result.offenses
end
# write_outside_command_cop_check("Order.create!(name: 'x')", file_path: "app/services/foo.rb")
# => [#<RuboCop::Cop::Offense: Mutate ActiveRecord models through a command in app/public.>]
#
# write_outside_command_cop_check("Order.create!(name: 'x')", file_path: "app/public/orders/capture.rb")
# => []
# end: write_outside_command_cop

# segment: command_single_entrant_cop
module ArticleCops
  class CommandSingleEntrant < RuboCop::Cop::Base
    def on_class(class_node)
      return unless class_node.parent_class&.source == "ApplicationCommand"

      visibility = :public
      body = class_node.body

      nodes = if body.nil?
        []
      elsif body.begin_type?
        body.children
      else
        [body]
      end

      nodes.each do |node|
        if node.send_type? && %i[public private protected].include?(node.method_name)
          visibility = node.method_name
        end

        next unless node.def_type?
        next if node.method_name == :initialize

        if node.method_name == :call || visibility == :public
          add_offense(
            node,
            message: "Commands keep one door: define a private execute, never define call or another public method."
          )
        end
      end
    end
  end
end

# Same harness as above — only needed for inline verification.
def command_single_entrant_cop_check(source)
  registry = RuboCop::Cop::Registry.new([ArticleCops::CommandSingleEntrant])
  config = RuboCop::Config.new({"ArticleCops/CommandSingleEntrant" => {"Enabled" => true}}, "")
  team = RuboCop::Cop::Team.mobilize(registry, config)

  source_obj = RuboCop::ProcessedSource.new(source, RUBY_VERSION.to_f, "test.rb")
  result = team.investigate(source_obj)

  result.offenses
end
# command_single_entrant_cop_check("class Bad < ApplicationCommand\n  def extra\n  end\nend")
# => [#<RuboCop::Cop::Offense: Commands keep one door...>]
# end: command_single_entrant_cop

# segment: flipper_cutover
class FlipperOrder < ActiveRecord::Base
  self.table_name = "orders"
  include Flipper::Identifier

  after_commit :sync_to_crm, unless: -> { Flipper.enabled?(:orders_capture_via_command, self) }

  def sync_to_crm
    Crm::SyncOrder.call(order: self)
  end
end

module Orders
  class CaptureOrder < ApplicationCommand
    def initialize(order:) = @order = order

    private

    def payload = {order_id: @order.id}

    def execute
      @order.update!(region: "captured")
      announce(@order)
      @order
    end

    def announce(order)
      if Flipper.enabled?(:orders_capture_via_command, order)
        Crm::SyncOrder.call(order: order)
      end
    end
  end
end
# end: flipper_cutover

def flipper_cutover_demo
  Flipper.disable(:orders_capture_via_command)
  SideEffects.clear!

  legacy = FlipperOrder.create!
  command_order = FlipperOrder.create!
  SideEffects::WEBHOOKS.clear

  Flipper.enable_actor(:orders_capture_via_command, command_order)

  Orders::CaptureOrder.call(order: legacy)
  Orders::CaptureOrder.call(order: command_order)

  result = SideEffects::WEBHOOKS.dup
  Flipper.disable(:orders_capture_via_command)
  result
end

# segment: after_all_transactions_commit
def after_all_transactions_demo
  ran = []
  Seat.transaction do
    ActiveRecord.after_all_transactions_commit { ran << :done }
    raise "should be empty" unless ran.empty?
  end

  ran
end
# end: after_all_transactions_commit

# segment: touch_trace_classes
class TouchEvent < ActiveRecord::Base
  self.table_name = "events"
  after_touch { SideEffects::LOGS << [:event_after_touch, self.class.lease_connection.transaction_open?] }
end

class TouchSeat < ActiveRecord::Base
  self.table_name = "seats"
  belongs_to :touch_event, foreign_key: :event_id, touch: true
end
# end: touch_trace_classes

# segment: transaction_boundary_demo
def transaction_boundary_demo
  results = []
  klass = Class.new(ActiveRecord::Base) do
    self.table_name = "seats"
    after_save { results << [:after_save, self.class.lease_connection.transaction_open?] }
    after_commit { results << [:after_commit, self.class.lease_connection.transaction_open?] }
  end

  klass.create!(external_ref: "TB#{SecureRandom.hex(4)}")
  results
end
# end: transaction_boundary_demo

# segment: order_god_model
class GodOrder < ActiveRecord::Base
  self.table_name = "orders"
  before_validation :normalize_email
  before_save :compute_totals
  after_save :update_search_index
  after_commit :sync_to_crm
  after_commit :notify_fulfillment

  private

  def normalize_email = self.email = email&.downcase
  def compute_totals = nil
  def update_search_index = SearchIndex::IndexSeats.call(seats: [self])
  def sync_to_crm = Crm::SyncOrder.call(order: self)
  def notify_fulfillment = ReservationMailer.confirmed(self).deliver_later
end
# end: order_god_model

# segment: private_constructor_demo
def private_constructor_demo
  Seats::ReserveSeat.new(seat_id: 1, by: "x")
  # => raises NoMethodError: private method 'new' called
rescue NoMethodError => e
  e.message
end
# end: private_constructor_demo

# segment: forgetful_demo
def forgetful_demo
  Seats::Forgetful.call
  # => raises NotImplementedError: Seats::Forgetful must define #execute
rescue NotImplementedError => e
  e.message
end
# end: forgetful_demo

# segment: census_strangler
def census_strangler
  census_results = ActiveRecord::Base.descendants.filter_map do |model|
    next if model.abstract_class?

    count = %i[validation save create update destroy commit touch].sum do |kind|
      model.send(:"_#{kind}_callbacks").to_a.size
    end

    [model.name, count] if count.positive?
  end

  census_results.sort_by(&:last).reverse.first(20)
end
# end: census_strangler

# segment: flipper_enable_percentage
def flipper_enable_percentage_demo
  Flipper.enable_percentage_of_actors(:orders_capture_via_command, 5)

  value = Flipper[:orders_capture_via_command].percentage_of_actors_value

  Flipper.disable(:orders_capture_via_command)
  # => 5
  value
end
# end: flipper_enable_percentage

# segment: validation_models
class CapacitySeat < ActiveRecord::Base
  self.table_name = "seats"
  belongs_to :event, optional: true
  validates :external_ref, uniqueness: true
  validate :event_has_capacity

  def event_has_capacity
    return unless event
    errors.add(:event, "full") if event.seats.count >= event.capacity
  end
end
# end: validation_models

# === Display segments for article rendering ===

# segment: update_attribute_demo
class ValidatedSeat < ActiveRecord::Base
  validates :reserved_by, exclusion: {in: ["invalid"]}
end
# end: update_attribute_demo

# segment: counter_cache_example
def counter_cache_example
  event = Event.create!(name: "RubyConf")
  # chain runs, counter goes to 1
  Seat.create!(event: event)
  # chain skipped
  Seat.insert_all([{event_id: event.id}] * 3)

  event.reload.seats_count
  # => 1
  event.seats.count
  # => 4
end
# end: counter_cache_example

# segment: touch_models_display
class TouchEvent < ActiveRecord::Base
  self.table_name = "events"
  after_touch { audit(:touched) }

  def audit(action) = AppLogger.info("[AUDIT] #{self.class.name}##{id} #{action}")
end

class TouchSeat < ActiveRecord::Base
  self.table_name = "seats"
  belongs_to :event, class_name: "TouchEvent", foreign_key: :event_id, touch: true, optional: true
end
# end: touch_models_display

# segment: after_save_email_demo
class EmailSeat < ActiveRecord::Base
  self.table_name = "seats"
  after_save   :send_reservation_email
  after_commit :confirm_reservation

  def send_reservation_email
    ReservationMailer.confirmed(self).deliver_later
  end

  def confirm_reservation
    ReservationMailer.final_confirmation(self).deliver_later
  end
end
# end: after_save_email_demo

def after_save_email_rollback
  SideEffects.clear!
  rows_before = Seat.count

  EmailSeat.transaction do
    EmailSeat.create!(reserved: true, reserved_by: "ghost", external_ref: "EM#{SecureRandom.hex(4)}")
    raise ActiveRecord::Rollback
  end

  SideEffects::EMAILS.size
  # => 1 (after_save fired, after_commit did not)
  Seat.count - rows_before
  # => 0 (no rows written)

  {emails_sent: SideEffects::EMAILS.size, rows_written: Seat.count - rows_before}
end

# segment: nested_transaction_demo
def nested_transaction_demo
  commits = []
  klass = Class.new(Seat) do
    after_commit { commits << :fired }
  end

  klass.transaction do
    klass.create!(external_ref: "NX1_#{SecureRandom.hex(4)}")
    klass.transaction(requires_new: true) do
      klass.create!(external_ref: "NX2_#{SecureRandom.hex(4)}")
    end
    # after_commits fired so far: 0
    commits.size
  end

  # after_commits fired: commits.size
  commits.size
end
# end: nested_transaction_demo

# segment: lifecycle_coalescing_demo
def lifecycle_coalescing_demo
  fires = []
  klass = Class.new(Seat) do
    after_create_commit { fires << :created }
    after_update_commit { fires << :updated }
  end

  klass.transaction do
    seat = klass.create!(external_ref: "LC#{SecureRandom.hex(4)}")
    seat.update!(reserved_by: "x")
  end
  # => [:created]  (the update's observers never hear about it)
  fires
end
# end: lifecycle_coalescing_demo

# segment: two_copies_demo
def two_copies_demo
  instance_log = []
  klass = Class.new(Seat) do
    after_commit { instance_log << object_id }
  end

  seat = klass.create!(external_ref: "TC#{SecureRandom.hex(4)}")

  first_copy = klass.find(seat.id)
  second_copy = klass.find(seat.id)

  klass.transaction do
    first_copy.update!(reserved_by: "a")
    second_copy.update!(priority: true)
  end

  {
    ran_on_count: instance_log.size,
    first_id: first_copy.object_id,
    ids: instance_log
  }
end
# end: two_copies_demo

# segment: composite_order_model
class CompositeOrder < ActiveRecord::Base
  self.table_name = "orders"

  before_validation :normalize_email
  before_save :compute_totals, if: :line_items_changed?
  before_save :apply_loyalty_tier, unless: :imported?
  after_save :update_search_index
  after_save :recalculate_inventory, if: :saved_change_to_status?
  after_commit :sync_to_crm
  after_commit :notify_fulfillment, if: -> { saved_change_to_status?(to: "paid") }
  # plus :touch on the customer, plus a counter cache,
  # plus two more in concerns/syncable.rb that you'll find next month

  private

  def normalize_email
    self.email = email&.strip&.downcase
  end

  def compute_totals = nil
  def apply_loyalty_tier = nil
  def update_search_index = nil
  def recalculate_inventory = nil
  def sync_to_crm = nil
  def notify_fulfillment = nil
  def line_items_changed? = false
  def imported? = false
  def saved_change_to_status?(**) = false
end
# end: composite_order_model

# segment: destroy_guard_display
class DestroyGuardEvent < ActiveRecord::Base
  self.table_name = "events"
  has_many :seats, foreign_key: :event_id, dependent: :destroy
  # declared second, runs second
  before_destroy :refuse_if_seated

  def refuse_if_seated
    throw(:abort) if seats.exists?
  end
end

# event = DestroyGuardEvent.create!(name: "guarded")
# Seat.create!(event_id: event.id)
# event.destroy  # => destroyed! seats deleted before the guard ran
# end: destroy_guard_display

# segment: blocked_save_display
class BlockedSeat < ActiveRecord::Base
  self.table_name = "seats"
  before_save { throw :abort }
end

def blocked_save_demo
  blocked = BlockedSeat.new(external_ref: "BK#{SecureRandom.hex(4)}")
  # => false
  save_result = blocked.save
  # => ActiveRecord::RecordNotSaved
  save_bang = (blocked.save! rescue $!.class)
  {save: save_result, save_bang: save_bang}
end
# end: blocked_save_display

# segment: instrumentation_output
def instrumentation_output
  seat = Seat.create!(external_ref: "IO#{SecureRandom.hex(4)}")
  events = []
  sub = ActiveSupport::Notifications.subscribe(/\.seats\z/) do |event|
    events << {name: event.name, payload: event.payload.except(:exception_object), ms: event.duration.round(1)}
  end

  Seats::ReserveSeat.call(seat_id: seat.id, by: "brandon")
  begin
    Seats::ReserveSeat.call(seat_id: seat.id, by: "someone-else")
  rescue Seats::ReserveSeat::AlreadyReserved
  end

  ActiveSupport::Notifications.unsubscribe(sub)
  events
end
# => [
#   { name: "reserve_seat.seats", payload: { seat_id: 1, by: "brandon" }, ms: 7.4 },
#   { name: "reserve_seat.seats", payload: { seat_id: 1, by: "someone-else",
#       exception: ["Seats::ReserveSeat::AlreadyReserved", "seat 1 is already reserved"] }, ms: 0.5 }
# ]
# end: instrumentation_output

# segment: flipper_rollout_line
def flipper_rollout_line
  Flipper.enable_percentage_of_actors(:orders_capture_via_command, 5)
  # => 5
  Flipper[:orders_capture_via_command].percentage_of_actors_value
end
# end: flipper_rollout_line

# segment: transaction_open_demo
class TransactionCheckSeat < ActiveRecord::Base
  self.table_name = "seats"
  after_save   { AppLogger.info([:after_save, self.class.lease_connection.transaction_open?]) }   # => true
  after_commit { AppLogger.info([:after_commit, self.class.lease_connection.transaction_open?]) }  # => false
end
# end: transaction_open_demo

def transaction_open_demo
  TransactionCheckSeat.create!(external_ref: "TX#{SecureRandom.hex(4)}")
  SideEffects::LOGS.dup
end
