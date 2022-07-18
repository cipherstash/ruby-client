require_relative "../../spec_helper"

require "cipherstash/index/bloom_filter"

describe CipherStash::Index::BloomFilter do
  self::VALID_M_VALUES = [32, 64, 128, 256, 512, 1024, 2048, 4096, 8192, 16384, 32768, 65536]
  self::VALID_K_VALUES = [3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]

  # Generated by SecureRandom.hex(32)
  # The same key is used for each test run so that these tests are deterministic.
  let(:key) { "b6d6dba3be33ffaabb83af611ec043b9270dacdc7b3015ce2c36ba17cf2d3b2c" }

  describe ".new" do
    it "returns a bloom filter with empty bits" do
      filter = described_class.new(key)
      expect(filter.bits).to eq(Set.new())
    end

    it "provides a default for m" do
      filter = described_class.new(key)
      expect(filter.m).to eq(256)
    end

    self::VALID_M_VALUES.each do |m|
      it "allows #{m} as a value for m" do
        filter = described_class.new(key, {"filterSize" => m})
        expect(filter.m).to eq(m)
      end
    end

    [0, 2, 16, 31, 513, 131072, "256", "ohai", nil, { foo: "bar" }, Object.new].each do |m|
      it "raises given invalid m of #{m.inspect}" do
        expect {
          described_class.new(key, {"filterSize" => m})
        }.to raise_error(::CipherStash::Client::Error::InvalidSchemaError, "filterSize must be a power of 2 between 32 and 65536 (got #{m.inspect})")
      end
    end

    it "provides a default for k" do
      filter = described_class.new(key)
      expect(filter.k).to eq(3)
    end

    self::VALID_K_VALUES.each do |k|
      it "allows #{k} as a value for k" do
        filter = described_class.new(key, {"filterTermBits" => k})
        expect(filter.k).to eq(k)
      end
    end

    it "raises when k is < 3" do
      expect {
        described_class.new(key, {"filterTermBits" => 2})
      }.to raise_error(::CipherStash::Client::Error::InvalidSchemaError, "filterTermBits must be an integer between 3 and 16 (got 2)")
    end

    it "raises when k is > 16" do
      expect {
        described_class.new(key, {"filterTermBits" => 17})
      }.to raise_error(::CipherStash::Client::Error::InvalidSchemaError, "filterTermBits must be an integer between 3 and 16 (got 17)")
    end

    [3.5, "4", "ohai", nil, { foo: "bar" }, Object.new].each do |k|
      it "raises given invalid value of k #{k}" do
        expect {
          described_class.new(key, {"filterTermBits" => k})
        }.to raise_error(::CipherStash::Client::Error::InvalidSchemaError, "filterTermBits must be an integer between 3 and 16 (got #{k.inspect})")
      end
    end

    it "raises when the key is too short" do
      key = SecureRandom.hex(16)

      expect {
        described_class.new(key)
      }.to raise_error(::CipherStash::Client::Error::InternalError, "expected bloom filter key to have length=32, got length=16")
    end

    it "raises when the key is empty" do
      key = ""

      expect {
        described_class.new(key)
      }.to raise_error(::CipherStash::Client::Error::InternalError, "expected bloom filter key to have length=32, got length=0")
    end

    it "raises when the key is not a hex string" do
      key = "ZZZ"

      expect {
        described_class.new(key)
      }.to raise_error(::CipherStash::Client::Error::InternalError, 'expected bloom filter key to be a hex-encoded string (got "ZZZ")')
    end

    [3.5, 4, nil, { foo: "bar" }, Object.new].each do |key|
      it "raises given invalid key #{key.inspect}" do
        expect {
          described_class.new(key)
        }.to raise_error(::CipherStash::Client::Error::InternalError, "expected bloom filter key to be a hex-encoded string (got #{key.inspect})")
      end
    end
  end

  describe "#add" do
    it "accepts a single term or a list of terms" do
      filter_a = described_class.new(key)
      filter_b = described_class.new(key)

      filter_a.add("abc")
      filter_b.add(["abc"])

      expect(filter_a.bits).not_to be_empty
      expect(filter_a.bits).to eq(filter_b.bits)
    end

    # In practice there will be 1 to k entries. Less than k entries will be in the set
    # in the case that any of the first k slices of the HMAC have the same value.
    it "adds k entries to bits for a single term when there are no hash collisions" do
      filter = described_class.new(key)

      # A term that's known to not have collisions in the first k slices for the test key
      filter.add("yes")

      expect(filter.bits.length).to eq(filter.k)
    end

    self::VALID_K_VALUES.each do |k|
      it "adds at most #{k} entries to bits for a single term when k=#{k}" do
        filter = described_class.new(key, {"filterTermBits" => k})
        random_term = SecureRandom.base64(3)

        filter.add(random_term)

        expect(filter.k).to eq(k)
        expect(filter.bits.length).to be > 0
        expect(filter.bits.length).to be <= filter.k
      end
    end

    self::VALID_M_VALUES.each do |m|
      it "adds bit positions with a max value of #{m} when m=#{m}" do
        filter = described_class.new(key, {"filterSize" => m})
        random_term = SecureRandom.base64(3)

        filter.add(random_term)

        expect(filter.m).to eq(m)
        expect(filter.bits.length).to be > 0
        expect(filter.bits.all? { |b| b <= m }).to be(true), "expected all bit positions to be <= #{m}, got bits=#{filter.bits.inspect}"
      end
    end

    it "returns the bloom filter instance" do
      filter = described_class.new(key)

      result = filter.add("yes")

      expect(result).to be(filter)
    end
  end

  describe "#subset?" do
    it "returns true when the other filter is a subset" do
      filter_a = described_class.new(key)
      filter_b = described_class.new(key)

      filter_a.add("yes")
      filter_b.add("yes")

      expect(filter_a).to be_subset(filter_b)
    end

    it "returns false when the other filter is not a subset" do
      filter_a = described_class.new(key)
      filter_b = described_class.new(key)

      filter_a.add("yes")
      filter_b.add("ner")

      expect(filter_a).not_to be_subset(filter_b)
    end

    self::VALID_M_VALUES
      .product(self::VALID_K_VALUES)
      .each do |m, k|
        it "works for m=#{m} and k=#{k}" do
          filter_a = described_class.new(key, {"filterSize" => m, "filterTermBits" => k})
          filter_b = described_class.new(key, {"filterSize" => m, "filterTermBits" => k})
          filter_c = described_class.new(key, {"filterSize" => m, "filterTermBits" => k})
          filter_d = described_class.new(key, {"filterSize" => m, "filterTermBits" => k})

          filter_a.add(%w(a b c))

          # subset of filter_a
          filter_b.add(%w(a b))

          # zero subset intersection with filter_a
          filter_c.add(%w(d e))

          # partial subset intersection with filter_a
          filter_d.add(%w(c d))

          expect(filter_b).to be_subset(filter_a)
          expect(filter_c).not_to be_subset(filter_a)
          expect(filter_d).not_to be_subset(filter_a)
        end
      end
  end

  describe "#to_a" do
    it "returns bits as an array" do
      filter = described_class.new(key).add("a")

      expect(filter.to_a).to be_instance_of(Array)
      expect(Set.new(filter.to_a)).to eq(filter.bits)
    end

    it "works when bits is empty" do
      filter = described_class.new(key)

      expect(filter.to_a).to eq([])
    end
  end
end
