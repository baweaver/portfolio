# frozen_string_literal: true

require_relative "indexes"

RSpec.describe "Rails: The Sharp Parts — An Index Is Not a Plan" do
  before(:all) { ensure_seeded! }
  before(:each) { drop_secondary_indexes }
  after(:all) { drop_secondary_indexes }

  let(:fx) { fixtures }

  describe "#opening_migration" do
    it "adds the customer_id index" do
      opening_migration
      names = ActiveRecord::Base.connection.indexes(:bookings).map(&:name)
      expect(names).to include("idx_customer")
    end
  end

  describe "#add_status_index" do
    it "adds the status index" do
      add_status_index
      names = ActiveRecord::Base.connection.indexes(:bookings).map(&:name)
      expect(names).to include("idx_status")
    end
  end

  describe "#add_composite_esc_index" do
    it "adds the composite index" do
      add_composite_esc_index
      names = ActiveRecord::Base.connection.indexes(:bookings).map(&:name)
      expect(names).to include("idx_esc")
    end
  end

  describe "#add_created_at_index" do
    it "adds the created_at index" do
      add_created_at_index
      names = ActiveRecord::Base.connection.indexes(:bookings).map(&:name)
      expect(names).to include("idx_created")
    end
  end

  describe "#date_function_query" do
    it "returns a relation" do
      expect(date_function_query).to be_a(ActiveRecord::Relation)
    end

    it "cannot use an index on created_at" do
      add_created_at_index
      expect(date_function_query.explain.inspect).to include("ALL")
    end
  end

  describe "#half_open_range_query" do
    it "returns a relation" do
      expect(half_open_range_query).to be_a(ActiveRecord::Relation)
    end

    it "uses the created_at index" do
      add_created_at_index
      expect(half_open_range_query.explain.inspect).to include("idx_created")
    end
  end

  describe "#add_email_index" do
    it "adds the email index" do
      add_email_index
      names = ActiveRecord::Base.connection.indexes(:bookings).map(&:name)
      expect(names).to include("idx_email")
    end
  end

  describe "#lower_email_query" do
    it "returns a relation" do
      expect(lower_email_query(fx[:email])).to be_a(ActiveRecord::Relation)
    end

    it "cannot use a plain email index" do
      add_email_index
      expect(lower_email_query(fx[:email]).explain.inspect).to include("ALL")
    end
  end

  describe "#add_functional_email_index" do
    it "creates the functional index" do
      add_functional_email_index
      result = ActiveRecord::Base.connection.execute("SHOW INDEX FROM bookings WHERE Key_name = 'idx_lower_email'")
      expect(result.count).to be > 0
    end

    it "makes lower_email_query use the index" do
      add_functional_email_index
      expect(lower_email_query(fx[:email]).explain.inspect).to include("idx_lower_email")
    end
  end

  describe "#add_confirmation_index" do
    it "adds the confirmation index" do
      add_confirmation_index
      names = ActiveRecord::Base.connection.indexes(:bookings).map(&:name)
      expect(names).to include("idx_conf")
    end
  end

  describe "#like_trailing" do
    it "returns a relation" do
      expect(like_trailing("QIKF")).to be_a(ActiveRecord::Relation)
    end

    it "uses the index" do
      add_confirmation_index
      expect(like_trailing(fx[:confirmation][0, 4]).explain.inspect).to include("idx_conf")
    end
  end

  describe "#like_leading" do
    it "returns a relation" do
      expect(like_leading("GDNS")).to be_a(ActiveRecord::Relation)
    end

    it "cannot use the index" do
      add_confirmation_index
      expect(like_leading(fx[:confirmation][-4, 4]).explain.inspect).to include("ALL")
    end
  end

  describe "#add_phone_index" do
    it "adds the phone index" do
      add_phone_index
      names = ActiveRecord::Base.connection.indexes(:bookings).map(&:name)
      expect(names).to include("idx_phone")
    end
  end

  describe "#phone_string_query" do
    it "uses the index" do
      add_phone_index
      expect(phone_string_query(fx[:phone]).explain.inspect).to include("idx_phone")
    end
  end

  describe "#phone_numeric_query" do
    it "drops the index due to type mismatch" do
      add_phone_index
      result = phone_numeric_query(fx[:phone])
      plan = result.to_a.first["type"]
      expect(plan).to eq("ALL")
    end
  end

  describe "#add_covering_index" do
    it "adds the covering index" do
      add_covering_index
      names = ActiveRecord::Base.connection.indexes(:bookings).map(&:name)
      expect(names).to include("idx_cu_cr")
    end
  end

  describe "#three_star_query" do
    it "returns a relation" do
      expect(three_star_query(fx[:customer_id])).to be_a(ActiveRecord::Relation)
    end

    it "earns all three stars with the right index" do
      add_three_star_index
      plan = three_star_query(fx[:customer_id]).explain.inspect
      expect(plan).to include("idx_three_star")
      expect(plan).not_to include("filesort")
      expect(plan).to include("Using index")
    end
  end

  describe "#add_three_star_index" do
    it "adds the index" do
      add_three_star_index
      names = ActiveRecord::Base.connection.indexes(:bookings).map(&:name)
      expect(names).to include("idx_three_star")
    end
  end

  describe "#add_redundant_indexes" do
    it "adds both indexes" do
      add_redundant_indexes
      names = ActiveRecord::Base.connection.indexes(:bookings).map(&:name)
      expect(names).to include("idx_cust", "idx_cust_created")
    end
  end

  describe "#redundant_index_check" do
    it "detects the redundant index" do
      add_redundant_indexes
      result = redundant_index_check
      names = result.map { |r| r[0] }
      expect(names).to include("idx_cust")
    end
  end

  describe "#explain_query" do
    it "returns an explain string" do
      result = explain_query(fx[:customer_id])
      expect(result).to be_a(String)
      expect(result).to include("bookings")
    end
  end

  describe "#explain_analyze_query" do
    it "returns an explain analyze string" do
      result = explain_analyze_query(fx[:customer_id])
      expect(result).to be_a(String)
      expect(result).to include("actual time")
    end
  end

  describe "#query_log_tags_config" do
    it "sets query_log_tags on the config object" do
      config = Struct.new(:active_record).new(Struct.new(:query_log_tags_enabled, :query_log_tags).new)
      query_log_tags_config(config)
      expect(config.active_record.query_log_tags_enabled).to be true
      expect(config.active_record.query_log_tags).to eq([:application, :controller, :action, :source_location])
    end
  end

  describe "#make_index_invisible / #make_index_visible" do
    it "toggles index visibility" do
      add_covering_index
      make_index_invisible("idx_cu_cr")
      plan = Booking.where(customer_id: fx[:customer_id]).explain.inspect
      expect(plan).to include("ALL")

      make_index_visible("idx_cu_cr")
      plan = Booking.where(customer_id: fx[:customer_id]).explain.inspect
      expect(plan).to include("idx_cu_cr")
    end
  end

  describe "#drop_secondary_indexes" do
    it "removes all secondary indexes" do
      add_status_index
      add_phone_index
      drop_secondary_indexes
      expect(ActiveRecord::Base.connection.indexes(:bookings)).to be_empty
    end
  end

  describe "#with_indexes" do
    it "adds indexes for the block and removes after" do
      with_indexes([:idx_test, :customer_id]) do
        names = ActiveRecord::Base.connection.indexes(:bookings).map(&:name)
        expect(names).to include("idx_test")
      end
      names = ActiveRecord::Base.connection.indexes(:bookings).map(&:name)
      expect(names).not_to include("idx_test")
    end
  end

  describe "#fixtures" do
    it "returns a hash with expected keys" do
      expect(fx).to include(:customer_id, :event_id, :confirmation, :email, :phone)
    end

    it "returns real values from the database" do
      expect(Booking.where(customer_id: fx[:customer_id]).count).to be > 0
      expect(Booking.where(event_id: fx[:event_id]).count).to be > 0
    end
  end

  describe "#ensure_seeded!" do
    it "does not re-seed when already at 500k" do
      expect(Booking.count).to eq(500_000)
      expect { ensure_seeded! }.not_to change { Booking.count }
    end
  end
end
