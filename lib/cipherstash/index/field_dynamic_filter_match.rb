module CipherStash
    class Index
      # Implementation for the 'field-dynamic-filter-match' index type
      #
      # @private
      class FieldDynamicFilterMatch < Index
        INDEX_OPS = {
          "match" => -> (idx, f, s) do
            idx.text_processor.perform(s).map { |t| { indexId: idx.binid, exact: { term: [idx.ore_encrypt("#{f}:#{t}").to_s] } } }
          end,
        }

        def analyze(uuid, record)
          blid = blob_from_uuid(uuid)

          raw_terms = collect_string_fields(record)

          if raw_terms == []
            nil
          else
            terms = raw_terms.map { |f, s| text_processor.perform(s).map { |b| "#{f}:#{b}" } }.flatten.uniq
            { indexId: binid, terms: terms.map { |t| { term: [ore_encrypt(t).to_s], link: blid } } }
          end
        end
      end
    end
  end
