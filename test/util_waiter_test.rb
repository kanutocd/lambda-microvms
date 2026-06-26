# frozen_string_literal: true

require 'test_helper'

class UtilWaiterTest < Minitest::Test
  GetterValue = Struct.new(:answer, keyword_init: true)
  NilGetterValue = Struct.new(:answer, keyword_init: true)

  def test_extracts_from_reader_before_index_lookup
    assert_equal 'reader', Lambda::MicroVMs::Util.extract(GetterValue.new(answer: 'reader'), :answer)
  end

  def test_extracts_from_index_lookup_when_reader_returns_nil
    value = NilGetterValue.new(answer: nil)
    def value.[](key) = key == :answer ? 'indexed' : nil

    assert_equal 'indexed', Lambda::MicroVMs::Util.extract(value, :answer)
  end

  def test_extract_ignores_index_lookup_errors
    value = Object.new
    def value.[](_key) = raise KeyError, 'missing'

    assert_nil Lambda::MicroVMs::Util.extract(value, :missing)
  end

  def test_extract_returns_nil_when_no_key_matches
    assert_nil Lambda::MicroVMs::Util.extract(Object.new, :missing)
  end

  def test_waiter_times_out_with_message
    waiter = Lambda::MicroVMs::Waiter.new(delay: 0.001, timeout: 0.001)

    error = assert_raises(Lambda::MicroVMs::WaitTimeoutError) do
      waiter.wait(message: 'thing') { false }
    end

    assert_equal 'timed out waiting for thing', error.message
  end
end
