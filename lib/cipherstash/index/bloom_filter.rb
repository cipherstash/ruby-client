require "openssl"
require_relative "../client/error"

module CipherStash
  class Index
    # A bloom filter implementation designed to be used with the *FilterMatch index classes.
    #
    # @private
    class BloomFilter
      K_MIN = 3
      K_MAX = 16
      K_DEFAULT = 3
      M_MIN = 32
      M_MAX = 65536
      M_DEFAULT = 256

      # The "set" bits of the bloom filter
      attr_reader :bits

      # The size of the bloom filter in bits. Same as "filterSize" in the schema mapping and public docs.
      #
      # Since we only keep track of the set bits, the filter size determines the maximum value of the positions stored in the bits attr.
      # Bit positions are zero-indexed and will have values >= 0 and <= m-1.
      #
      # Valid values are powers of 2 from 32 to 65536.
      #
      # @return [Integer]
      attr_reader :m

      # The number of hash functions applied to each term. Same as "filterTermBits" in the schema mapping and public docs.
      #
      # Implemented as k slices of a single hash.
      #
      # Valid values are integers from 3 to 16.
      #
      # @return [Integer]
      attr_reader :k

      # Creates a new bloom filter with the given key and filter match index settings.
      #
      # @param key [String] the key to use for hashing terms. Should be provided as a hex-encoded string.
      #
      # @param opts [Hash] the index settings.
      #   "filterSize" and "filterTermBits" are used to set the m and k attrs respectively.
      #
      # @raise [CipherStash::Client::Error::InvalidSchemaError] if an invalid "filterSize" or "filterTermBits" is given.
      def initialize(key, opts = {})
        unless hex_string?(key)
          raise ::CipherStash::Client::Error::InternalError, "expected bloom filter key to be a hex-encoded string (got #{key.inspect})"
        end

        @key = [key].pack("H*")

        unless @key.length == 32
          raise ::CipherStash::Client::Error::InternalError, "expected bloom filter key to have length=32, got length=#{@key.length}"
        end

        @bits = Set.new()

        @m = opts.fetch("filterSize", M_DEFAULT)

        unless valid_m?(@m)
          raise ::CipherStash::Client::Error::InvalidSchemaError, "filterSize must be a power of 2 between 32 and 65536 (got #{@m.inspect})"
        end

        @k = opts.fetch("filterTermBits", K_DEFAULT)

        unless (K_MIN..K_MAX).to_a.include?(@k)
          raise ::CipherStash::Client::Error::InvalidSchemaError, "filterTermBits must be an integer between 3 and 16 (got #{@k.inspect})"
        end
      end

      # Adds the given terms to the bloom filter and returns the filter instance.
      #
      # @param terms [Array<String> | String] either a list of terms or a single term to add.
      #
      # @return [CipherStash::Index::BloomFilter]
      def add(terms)
        Array(terms).each { |term| add_single_term(term) }
        self
      end

      # Returns true if the bloom filter is a subset of the other bloom filter and returns false otherwise.
      #
      # @param other [CipherStash::Index::BloomFilter] the other bloom filter to check against.
      #
      # @return [Boolean]
      def subset?(other)
        @bits.subset?(other.bits)
      end

      # Returns the "set" bits of the bloom filter as an array.
      #
      # @return [CipherStash::Index::BloomFilter]
      def to_a
        @bits.to_a
      end

      private

      def add_single_term(term)
        hash = OpenSSL::HMAC.digest("SHA256", @key, term)

        (0..@k-1).map do |slice_index|
          byte_slice = two_byte_slice(hash, slice_index)
          bit_position = little_endian_uint16_from_byte_slice(byte_slice) % @m
          @bits.add(bit_position)
        end
      end

      def two_byte_slice(bytes, index)
        bytes[2*index..2*index+1]
      end

      def little_endian_uint16_from_byte_slice(byte_slice)
        byte_slice.unpack("S<").first
      end

      def hex_string?(val)
        val.instance_of?(String) and /\A\h*\z/.match?(val)
      end

      def power_of_2?(m)
        Math.log2(m).floor == Math.log2(m)
      end

      def valid_m?(m)
        m.instance_of?(Integer) && M_MIN <= m && m <= M_MAX && power_of_2?(m)
      end
    end
  end
end
